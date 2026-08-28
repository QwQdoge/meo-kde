#include "authenticationcontroller.h"

#include <PolkitQt1/Subject>

#include <KWindowSystem>

#include <QDBusConnection>
#include <QWindow>

#include <unistd.h>

AuthenticationController::AuthenticationController(QObject *parent)
    : PolkitQt1::Agent::Listener(parent)
{
    m_deadline.setSingleShot(true);
    m_deadline.setInterval(RequestTimeoutMs);
    connect(&m_deadline, &QTimer::timeout, this, [this] {
        if (m_inProgress) {
            cancelActiveSession();
            finish(tr("The authorization request expired. Try the action again."));
        }
    });

    m_dbusObjectRegistered = QDBusConnection::sessionBus().registerObject(
        QStringLiteral("/org/kde/Polkit1AuthAgent"), this,
        QDBusConnection::ExportScriptableSlots);
}

AuthenticationController::~AuthenticationController()
{
    if (m_session)
        m_session->cancel();
}

bool AuthenticationController::registerForCurrentSession()
{
    const PolkitQt1::UnixSessionSubject session(getpid());
    return m_dbusObjectRegistered
        && registerListener(session, QStringLiteral("/org/meo/PolicyKit1/AuthenticationAgent"));
}

void AuthenticationController::initiateAuthentication(
    const QString &actionId,
    const QString &message,
    const QString &iconName,
    const PolkitQt1::Details &details,
    const QString &cookie,
    const PolkitQt1::Identity::List &identities,
    PolkitQt1::Agent::AsyncResult *result)
{
    Q_UNUSED(iconName)
    Q_UNUSED(details)

    if (m_inProgress) {
        result->setError(tr("Another authorization request is already active."));
        result->setCompleted();
        return;
    }
    if (identities.isEmpty()) {
        result->setError(tr("No eligible administrator account is available."));
        result->setCompleted();
        return;
    }

    m_actionId = actionId.left(512);
    m_message = message.left(2048);
    m_requesterLabel = labelForAction(m_actionId);
    m_cookie = cookie;
    m_result = result;
    m_identities = identities;
    m_identityNames.clear();
    m_identityNames.reserve(identities.size());
    for (const auto &identity : identities)
        m_identityNames.append(displayNameForIdentity(identity));

    m_selectedIdentityIndex = 0;
    m_attempts = 0;
    m_cancelled = false;
    m_inProgress = true;
    m_busy = true;
    m_prompt.clear();
    m_errorText.clear();
    m_infoText = tr("Confirm your identity to continue.");

    emit requestChanged();
    emit identitiesChanged();
    emit stateChanged();
    applyWindowContext();
    m_deadline.start();
    beginSession();
}

bool AuthenticationController::initiateAuthenticationFinish()
{
    return true;
}

void AuthenticationController::cancelAuthentication()
{
    cancel();
}

void AuthenticationController::beginSession()
{
    if (!m_inProgress || m_selectedIdentityIndex < 0
        || m_selectedIdentityIndex >= m_identities.size()) {
        return;
    }

    if (m_session) {
        disconnect(m_session, nullptr, this, nullptr);
        m_session->deleteLater();
    }

    m_busy = true;
    m_prompt.clear();
    emit stateChanged();

    m_session = new PolkitQt1::Agent::Session(
        m_identities.at(m_selectedIdentityIndex), m_cookie, m_result, this);

    connect(m_session, &PolkitQt1::Agent::Session::request, this,
            [this](const QString &request, bool echo) {
                m_prompt = request.left(512);
                m_echoResponse = echo;
                m_busy = false;
                m_infoText.clear();
                emit clearResponseRequested();
                emit stateChanged();
                emit focusResponseRequested();
            });
    connect(m_session, &PolkitQt1::Agent::Session::showError, this,
            [this](const QString &text) {
                m_errorText = text.left(1024);
                emit stateChanged();
            });
    connect(m_session, &PolkitQt1::Agent::Session::showInfo, this,
            [this](const QString &text) {
                m_infoText = text.left(1024);
                emit stateChanged();
            });
    connect(m_session, &PolkitQt1::Agent::Session::completed, this,
            [this](bool authorized) {
                if (!m_inProgress)
                    return;
                if (authorized) {
                    finish();
                    return;
                }
                if (m_cancelled) {
                    finish();
                    return;
                }

                ++m_attempts;
                emit clearResponseRequested();
                if (m_attempts >= MaximumAttempts) {
                    finish();
                    return;
                }

                m_errorText = tr("Authentication failed. Check the password and try again.");
                m_infoText.clear();
                emit stateChanged();
                beginSession();
            });
    m_session->initiate();
}

void AuthenticationController::submitResponse(QString response)
{
    if (!m_inProgress || m_busy || !m_session)
        return;

    m_busy = true;
    m_errorText.clear();
    m_infoText = tr("Checking…");
    emit clearResponseRequested();
    emit stateChanged();

    m_session->setResponse(response);
    response.fill(QChar(u'\0'));
    response.clear();
}

void AuthenticationController::cancel()
{
    if (!m_inProgress)
        return;
    m_cancelled = true;
    cancelActiveSession();
    finish();
}

void AuthenticationController::selectIdentity(int index)
{
    if (!m_inProgress || index < 0 || index >= m_identities.size()
        || index == m_selectedIdentityIndex) {
        return;
    }

    if (m_session) {
        disconnect(m_session, nullptr, this, nullptr);
        m_session->cancel();
        m_session->deleteLater();
        m_session.clear();
    }
    m_selectedIdentityIndex = index;
    m_attempts = 0;
    m_errorText.clear();
    emit identitiesChanged();
    emit clearResponseRequested();
    beginSession();
}

void AuthenticationController::finish(const QString &error)
{
    if (!m_inProgress)
        return;

    m_deadline.stop();
    if (!error.isEmpty() && m_result)
        m_result->setError(error);
    if (m_result)
        m_result->setCompleted();

    if (m_session) {
        m_session->deleteLater();
        m_session.clear();
    }

    emit clearResponseRequested();
    resetPublicState();
}

void AuthenticationController::cancelActiveSession()
{
    if (!m_session)
        return;
    disconnect(m_session, nullptr, this, nullptr);
    m_session->cancel();
}

void AuthenticationController::resetPublicState()
{
    m_cookie.fill(QChar(u'\0'));
    m_cookie.clear();
    m_result = nullptr;
    m_identities.clear();
    m_identityNames.clear();
    m_selectedIdentityIndex = -1;
    m_attempts = 0;
    m_cancelled = false;
    m_busy = false;
    m_echoResponse = false;
    m_prompt.clear();
    m_errorText.clear();
    m_infoText.clear();
    m_actionId.clear();
    m_message.clear();
    m_requesterLabel.clear();
    m_inProgress = false;
    emit identitiesChanged();
    emit requestChanged();
    emit stateChanged();
}

void AuthenticationController::setDialogWindow(QObject *windowObject)
{
    m_dialogWindow = qobject_cast<QWindow *>(windowObject);
    applyWindowContext();
}

void AuthenticationController::setWIdForAction(const QString &action, qulonglong windowId)
{
    setWindowHandleForAction(action, QString::number(windowId));
}

void AuthenticationController::setWindowHandleForAction(const QString &action, const QString &handle)
{
    if (action.size() > 512 || handle.size() > 2048)
        return;
    if (m_windowHandles.size() >= 32 && !m_windowHandles.contains(action))
        m_windowHandles.clear();
    m_windowHandles.insert(action, handle);
    applyWindowContext();
}

void AuthenticationController::setActivationTokenForAction(const QString &action, const QString &token)
{
    if (action.size() > 512 || token.size() > 4096)
        return;
    if (m_activationTokens.size() >= 32 && !m_activationTokens.contains(action))
        m_activationTokens.clear();
    m_activationTokens.insert(action, token);
    applyWindowContext();
}

void AuthenticationController::applyWindowContext()
{
    if (!m_dialogWindow || m_actionId.isEmpty())
        return;

    const QString handle = m_windowHandles.take(m_actionId);
    if (!handle.isEmpty())
        KWindowSystem::setMainWindow(m_dialogWindow, handle);

    const QString token = m_activationTokens.take(m_actionId);
    if (!token.isEmpty()) {
        qputenv("XDG_ACTIVATION_TOKEN", token.toUtf8());
        m_dialogWindow->requestActivate();
        qunsetenv("XDG_ACTIVATION_TOKEN");
    }
}

QString AuthenticationController::displayNameForIdentity(const PolkitQt1::Identity &identity) const
{
    QString value = identity.toString().left(256);
    if (value.startsWith(QStringLiteral("unix-user:")))
        value.remove(0, 10);
    return value.isEmpty() ? tr("Administrator") : value;
}

QString AuthenticationController::labelForAction(const QString &action) const
{
    if (action.startsWith(QStringLiteral("org.freedesktop.packagekit")))
        return tr("Software management");
    if (action.startsWith(QStringLiteral("org.freedesktop.udisks")))
        return tr("Storage service");
    if (action.startsWith(QStringLiteral("org.freedesktop.NetworkManager")))
        return tr("Network service");
    if (action.startsWith(QStringLiteral("org.kde")))
        return tr("KDE system service");
    return tr("System service");
}
