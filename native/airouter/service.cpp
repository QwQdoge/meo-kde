#include "service.h"

#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <PulseAudioQt/Context>
#include <PulseAudioQt/Server>
#include <PulseAudioQt/Sink>

#include <QDBusMessage>
#include <QDBusInterface>
#include <QDBusReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <QUuid>

RouterService::RouterService(QObject *parent) : QObject(parent)
{
    connect(&m_router, &Router::requestChanged, this, &RouterService::RequestStateChanged);
    connect(&m_router, &Router::confirmationRequired, this, &RouterService::ActionRequiresConfirmation);
    QDBusConnection::sessionBus().connect(QStringLiteral("org.meo.Accounts1"),
        QStringLiteral("/org/meo/Accounts1"), QStringLiteral("org.meo.Accounts1"),
        QStringLiteral("requestChanged"), &m_accountSignals,
        SLOT(onChanged(QString,QString,QVariantMap)));
    connect(&m_accountSignals, &AccountSignalReceiver::changed, this,
            &RouterService::handleAccountResult);
    auto *expiryTimer = new QTimer(this);
    expiryTimer->setInterval(1000);
    connect(expiryTimer, &QTimer::timeout, &m_router, [this] { m_router.expirePending(); });
    connect(expiryTimer, &QTimer::timeout, this, [this] {
        const auto now = QDateTime::currentDateTimeUtc();
        for (auto it = m_intents.begin(); it != m_intents.end();) {
            if (it->created.addSecs(900) < now) {
                m_intentByAccountRequest.remove(it->accountRequestId);
                it = m_intents.erase(it);
            } else {
                ++it;
            }
        }
    });
    expiryTimer->start();

    Router::Capability launch;
    launch.id = QStringLiteral("org.meo.application.launch");
    launch.title = QStringLiteral("Open application");
    launch.effect = Router::Effect::Session;
    launch.arguments = {{QStringLiteral("desktopId"), QMetaType::QString}};
    launch.dispatch = [this](const QString &requestId, const QVariantMap &arguments) {
        launchDesktop(requestId, arguments.value(QStringLiteral("desktopId")).toString());
    };
    m_router.addCapability(std::move(launch));

    Router::Capability settings;
    settings.id = QStringLiteral("org.meo.settings.openPage");
    settings.title = QStringLiteral("Open settings page");
    settings.effect = Router::Effect::Session;
    settings.arguments = {{QStringLiteral("page"), QMetaType::QString}};
    settings.dispatch = [this](const QString &requestId, const QVariantMap &arguments) {
        static const QSet<QString> pages{QStringLiteral("bluetooth"), QStringLiteral("wifi"),
            QStringLiteral("sound"), QStringLiteral("notifications"), QStringLiteral("display"),
            QStringLiteral("power")};
        const QString page = arguments.value(QStringLiteral("page")).toString();
        if (!pages.contains(page)) {
            m_router.complete(requestId, false, QStringLiteral("Unknown settings page"));
            return;
        }
        launchDesktop(requestId, QStringLiteral("org.meo.settings.%1.desktop").arg(page));
    };
    m_router.addCapability(std::move(settings));

    Router::Capability volume;
    volume.id = QStringLiteral("org.meo.desktop.audio.setVolume");
    volume.title = QStringLiteral("Set volume");
    volume.effect = Router::Effect::Session;
    volume.arguments = {{QStringLiteral("percent"), QMetaType::Int}};
    volume.dispatch = [this](const QString &requestId, const QVariantMap &arguments) {
        const int percent = arguments.value(QStringLiteral("percent")).toInt();
        if (percent < 0 || percent > 100) {
            m_router.complete(requestId, false, QStringLiteral("Volume must be between 0 and 100"));
            return;
        }
        auto *sink = PulseAudioQt::Context::instance()->server()->defaultSink();
        if (!sink) {
            m_router.complete(requestId, false, QStringLiteral("Audio output is unavailable"));
            return;
        }
        sink->setVolume(qRound64(PulseAudioQt::normalVolume() * percent / 100.0));
        QPointer<PulseAudioQt::Sink> observed(sink);
        QTimer::singleShot(3000, this, [this, requestId, percent, observed] {
            if (!observed) {
                m_router.complete(requestId, false, QStringLiteral("Audio output disappeared"));
                return;
            }
            const int actual = qRound(100.0 * observed->volume() / PulseAudioQt::normalVolume());
            m_router.complete(requestId, qAbs(actual - percent) <= 1,
                qAbs(actual - percent) <= 1 ? QStringLiteral("Volume is %1%").arg(actual)
                    : QStringLiteral("Volume change could not be verified"));
        });
    };
    m_router.addCapability(std::move(volume));

    Router::Capability volumeStatus;
    volumeStatus.id = QStringLiteral("org.meo.desktop.audio.getVolume");
    volumeStatus.title = QStringLiteral("Read volume");
    volumeStatus.effect = Router::Effect::Read;
    volumeStatus.dispatch = [this](const QString &requestId, const QVariantMap &) {
        auto *sink = PulseAudioQt::Context::instance()->server()->defaultSink();
        if (!sink) {
            m_router.complete(requestId, false, QStringLiteral("Audio output is unavailable"));
            return;
        }
        const int percent = qRound(100.0 * sink->volume() / PulseAudioQt::normalVolume());
        m_router.complete(requestId, true, QStringLiteral("Volume is %1%").arg(percent));
    };
    m_router.addCapability(std::move(volumeStatus));
}

void RouterService::launchDesktop(const QString &requestId, const QString &desktopId)
{
    static const QRegularExpression validId(QStringLiteral("^[A-Za-z0-9_.-]+\\.desktop$"));
    if (!validId.match(desktopId).hasMatch()) {
        m_router.complete(requestId, false, QStringLiteral("Invalid desktop ID"));
        return;
    }
    const KService::Ptr service = KService::serviceByStorageId(desktopId);
    if (!service || !service->isApplication()) {
        m_router.complete(requestId, false, QStringLiteral("Application is unavailable"));
        return;
    }
    auto *job = new KIO::ApplicationLauncherJob(service, this);
    connect(job, &KJob::result, this, [this, requestId](KJob *finished) {
        m_router.complete(requestId, finished->error() == 0, finished->errorText());
    });
    job->start();
    QTimer::singleShot(30000, this, [this, requestId] {
        m_router.complete(requestId, false, QStringLiteral("Application activation timed out"));
    });
}

QVariantMap RouterService::intentView(const IntentRequest &request) const
{
    return {{QStringLiteral("requestId"), request.id},
            {QStringLiteral("state"), request.state},
            {QStringLiteral("message"), request.message},
            {QStringLiteral("actionRequestId"), request.actionRequestId}};
}

QVariantMap RouterService::SubmitText(const QString &text)
{
    if (text.trimmed().isEmpty() || text.size() > 4000)
        return {{QStringLiteral("state"), QStringLiteral("rejected")},
                {QStringLiteral("message"), QStringLiteral("Invalid request text")}};

    static const QRegularExpression volumePattern(
        QStringLiteral("^(?:音量\\s*调到\\s*|set\\s+volume\\s+to\\s+)(\\d{1,3})\\s*%?$"),
        QRegularExpression::CaseInsensitiveOption);
    const auto volumeMatch = volumePattern.match(text.trimmed());
    if (volumeMatch.hasMatch())
        return m_router.submit(QStringLiteral("org.meo.desktop.audio.setVolume"),
            {{QStringLiteral("percent"), volumeMatch.captured(1).toInt()}},
            calledFromDBus() ? message().service() : QString());
    if (QStringList{QStringLiteral("当前音量"), QStringLiteral("音量是多少"),
                    QStringLiteral("what is the volume")}.contains(text.trimmed().toLower()))
        return m_router.submit(QStringLiteral("org.meo.desktop.audio.getVolume"), {},
            calledFromDBus() ? message().service() : QString());
    static const QHash<QString, QString> localSettings{
        {QStringLiteral("打开蓝牙设置"), QStringLiteral("bluetooth")},
        {QStringLiteral("打开无线网络设置"), QStringLiteral("wifi")},
        {QStringLiteral("打开声音设置"), QStringLiteral("sound")},
        {QStringLiteral("打开通知设置"), QStringLiteral("notifications")},
        {QStringLiteral("打开显示设置"), QStringLiteral("display")},
        {QStringLiteral("打开电源设置"), QStringLiteral("power")},
    };
    const QString localPage = localSettings.value(text.trimmed());
    if (!localPage.isEmpty())
        return m_router.submit(QStringLiteral("org.meo.settings.openPage"),
            {{QStringLiteral("page"), localPage}},
            calledFromDBus() ? message().service() : QString());

    // Exact installed-app matches are resolved locally, including offline.
    // An ambiguous label is sent to the Account broker instead of guessing.
    static const QRegularExpression openPattern(QStringLiteral("^(?:打开\\s*|open\\s+)(.+)$"),
                                                QRegularExpression::CaseInsensitiveOption);
    const auto openMatch = openPattern.match(text.trimmed());
    if (openMatch.hasMatch()) {
        const QString label = openMatch.captured(1).trimmed();
        QString desktopId;
        for (const KService::Ptr &application : KService::allServices()) {
            if (!application || !application->isApplication() || application->noDisplay())
                continue;
            const bool matches = application->name().compare(label, Qt::CaseInsensitive) == 0
                || application->desktopEntryName().compare(label, Qt::CaseInsensitive) == 0;
            if (!matches)
                continue;
            if (!desktopId.isEmpty() && desktopId != application->storageId()) {
                desktopId.clear();
                break;
            }
            desktopId = application->storageId();
        }
        if (!desktopId.isEmpty())
            return m_router.submit(QStringLiteral("org.meo.application.launch"),
                {{QStringLiteral("desktopId"), desktopId}},
                calledFromDBus() ? message().service() : QString());
    }

    QDBusInterface account(QStringLiteral("org.meo.Accounts1"), QStringLiteral("/org/meo/Accounts1"),
                           QStringLiteral("org.meo.Accounts1"), QDBusConnection::sessionBus());
    const QDBusReply<QVariantList> connections = account.call(
        QStringLiteral("ListAvailableLocalAiConnections"), QStringLiteral("org.meo.AIRouter"));
    if (!connections.isValid())
        return {{QStringLiteral("state"), QStringLiteral("failed")},
                {QStringLiteral("message"), QStringLiteral("Meo Account AI broker is unavailable")}};
    QVariantMap selected;
    for (const QVariant &candidate : connections.value()) {
        const QVariantMap connection = candidate.toMap();
        if (!connection.value(QStringLiteral("automaticInference")).toMap()
                 .value(QStringLiteral("enabled")).toBool()
            || connection.value(QStringLiteral("defaultModel")).toString().isEmpty())
            continue;
        if (selected.isEmpty() || connection.value(QStringLiteral("provider")).toString() == QLatin1String("ollama"))
            selected = connection;
        if (selected.value(QStringLiteral("provider")).toString() == QLatin1String("ollama"))
            break;
    }
    if (selected.isEmpty())
        return {{QStringLiteral("state"), QStringLiteral("handoff")},
                {QStringLiteral("message"), QStringLiteral("Enable prompt-free system AI for a connection in Meo Settings")}};

    const QVariantMap arguments{
        {QStringLiteral("connectionId"), selected.value(QStringLiteral("id"))},
        {QStringLiteral("model"), selected.value(QStringLiteral("defaultModel"))},
        {QStringLiteral("purpose"), QStringLiteral("system_ai_routing")},
        {QStringLiteral("dataCategories"), QStringList{QStringLiteral("user_prompt")}},
        {QStringLiteral("systemPrompt"), QStringLiteral("Choose one registered action. Return only JSON with capabilityId and arguments. Allowed: org.meo.application.launch with desktopId string; org.meo.settings.openPage with page one of bluetooth,wifi,sound,notifications,display,power; org.meo.desktop.audio.setVolume with percent integer 0..100; org.meo.desktop.audio.getVolume with empty arguments. If none fits, return {}. Never invent a capability or command.")},
        {QStringLiteral("userPrompt"), text},
        {QStringLiteral("temperature"), 0.0},
        {QStringLiteral("maxOutputTokens"), 256},
    };
    const QDBusReply<QString> started = account.call(QStringLiteral("StartLocalAiOperation"),
        QStringLiteral("org.meo.AIRouter"), QStringLiteral("invoke"), arguments);
    if (!started.isValid() || started.value().isEmpty())
        return {{QStringLiteral("state"), QStringLiteral("failed")},
                {QStringLiteral("message"), QStringLiteral("Meo Account rejected the AI request")}};

    IntentRequest request;
    request.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    request.caller = calledFromDBus() ? message().service() : QString();
    request.accountRequestId = started.value();
    request.state = QStringLiteral("resolving");
    request.created = QDateTime::currentDateTimeUtc();
    m_intents.insert(request.id, request);
    m_intentByAccountRequest.insert(request.accountRequestId, request.id);
    emit RequestStateChanged(intentView(request));
    const QDBusReply<QVariantMap> current = account.call(QStringLiteral("GetRequest"), started.value());
    if (current.isValid())
        handleAccountResult(started.value(), current.value());
    return intentView(m_intents.value(request.id));
}

void RouterService::handleAccountResult(const QString &accountRequestId, const QVariantMap &result)
{
    const QString intentId = m_intentByAccountRequest.value(accountRequestId);
    auto it = m_intents.find(intentId);
    if (it == m_intents.end() || it->state != QLatin1String("resolving"))
        return;
    const QString state = result.value(QStringLiteral("state")).toString();
    if (state != QLatin1String("completed") && state != QLatin1String("failed")
        && state != QLatin1String("denied") && state != QLatin1String("expired"))
        return;
    if (state != QLatin1String("completed")) {
        it->state = QStringLiteral("failed");
        it->message = result.value(QStringLiteral("error")).toString();
    } else {
        QDBusInterface account(QStringLiteral("org.meo.Accounts1"),
                               QStringLiteral("/org/meo/Accounts1"),
                               QStringLiteral("org.meo.Accounts1"), QDBusConnection::sessionBus());
        const QDBusReply<QVariantMap> privateResult = account.call(
            QStringLiteral("GetRequest"), accountRequestId);
        if (!privateResult.isValid()
            || privateResult.value().value(QStringLiteral("state")).toString()
                   != QLatin1String("completed")) {
            it->state = QStringLiteral("failed");
            it->message = QStringLiteral("Meo Account AI result is unavailable");
            m_intentByAccountRequest.remove(accountRequestId);
            emit RequestStateChanged(intentView(*it));
            return;
        }
        const QByteArray response = privateResult.value()
                                        .value(QStringLiteral("text")).toString().toUtf8();
        QJsonParseError error;
        const QJsonObject intent = QJsonDocument::fromJson(response, &error).object();
        if (error.error != QJsonParseError::NoError || intent.size() != 2
            || !intent.value(QStringLiteral("capabilityId")).isString()
            || !intent.value(QStringLiteral("arguments")).isObject()) {
            it->state = QStringLiteral("rejected");
            it->message = QStringLiteral("AI returned no valid registered action");
        } else {
            const QString capabilityId = intent.value(QStringLiteral("capabilityId")).toString();
            QVariantMap typedArguments = intent.value(QStringLiteral("arguments")).toObject().toVariantMap();
            if (capabilityId == QLatin1String("org.meo.desktop.audio.setVolume")) {
                const QJsonValue percent = intent.value(QStringLiteral("arguments"))
                                               .toObject().value(QStringLiteral("percent"));
                if (percent.isDouble() && percent.toDouble() == percent.toInt())
                    typedArguments.insert(QStringLiteral("percent"), percent.toInt());
            }
            const QVariantMap action = m_router.submit(capabilityId, typedArguments, it->caller);
            const QString actionState = action.value(QStringLiteral("state")).toString();
            it->state = actionState == QLatin1String("rejected") || actionState == QLatin1String("failed")
                ? actionState : QStringLiteral("action_started");
            it->message = action.value(QStringLiteral("message")).toString();
            it->actionRequestId = action.value(QStringLiteral("requestId")).toString();
        }
    }
    m_intentByAccountRequest.remove(accountRequestId);
    emit RequestStateChanged(intentView(it.value()));
}

QVariantMap RouterService::SubmitRequest(const QString &capabilityId, const QVariantMap &arguments)
{
    return m_router.submit(capabilityId, arguments, calledFromDBus() ? message().service() : QString());
}

QVariantMap RouterService::DecideRequest(const QString &requestId, const QString &fingerprint, bool approve)
{
    return m_router.decide(requestId, fingerprint, approve, calledFromDBus() ? message().service() : QString());
}

QVariantMap RouterService::GetRequest(const QString &requestId)
{
    const QString caller = calledFromDBus() ? message().service() : QString();
    const auto intent = m_intents.constFind(requestId);
    if (intent != m_intents.cend())
        return intent->caller == caller ? intentView(intent.value())
            : QVariantMap{{QStringLiteral("state"), QStringLiteral("rejected")}};
    return m_router.get(requestId, caller);
}

QVariantList RouterService::ListCapabilities() const
{
    return m_router.capabilities();
}
