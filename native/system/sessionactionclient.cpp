#include "sessionactionclient.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>

namespace
{
constexpr auto serviceName = "org.meo.SessionAction1";
constexpr auto objectPath = "/org/meo/SessionAction1";
constexpr auto interfaceName = "org.meo.SessionAction1";
}

SessionActionClient::SessionActionClient(QObject *parent)
    : QObject(parent)
{
    m_refreshTimer.setInterval(1000);
    connect(&m_refreshTimer, &QTimer::timeout, this, &SessionActionClient::refresh);
    QDBusConnection::sessionBus().connect(QString::fromLatin1(serviceName), QString::fromLatin1(objectPath),
                                           QString::fromLatin1(interfaceName), QStringLiteral("stateChanged"),
                                           this, SLOT(onStateChanged(QVariantMap)));
    refresh();
}

bool SessionActionClient::available() const { return m_available; }
bool SessionActionClient::scheduled() const { return m_scheduled; }
int SessionActionClient::remainingSeconds() const { return m_remainingSeconds; }
QString SessionActionClient::error() const { return m_error; }

void SessionActionClient::refresh()
{
    QDBusInterface service(QString::fromLatin1(serviceName), QString::fromLatin1(objectPath),
                           QString::fromLatin1(interfaceName), QDBusConnection::sessionBus());
    const QDBusReply<QVariantMap> reply = service.call(QStringLiteral("state"));
    if (!reply.isValid()) {
        setState({{QStringLiteral("available"), false}, {QStringLiteral("scheduled"), false},
                  {QStringLiteral("remainingSeconds"), 0}, {QStringLiteral("error"), reply.error().message()}});
        return;
    }
    setState(reply.value());
}

void SessionActionClient::scheduleLogout(int seconds) { invoke(QStringLiteral("scheduleLogout"), {seconds}); }
void SessionActionClient::cancel() { invoke(QStringLiteral("cancel")); }
void SessionActionClient::executeNow() { invoke(QStringLiteral("executeNow")); }

bool SessionActionClient::invoke(const QString &method, const QList<QVariant> &arguments)
{
    QDBusInterface service(QString::fromLatin1(serviceName), QString::fromLatin1(objectPath),
                           QString::fromLatin1(interfaceName), QDBusConnection::sessionBus());
    const auto reply = service.callWithArgumentList(QDBus::Block, method, arguments);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        setState({{QStringLiteral("available"), false}, {QStringLiteral("scheduled"), m_scheduled},
                  {QStringLiteral("remainingSeconds"), m_remainingSeconds}, {QStringLiteral("error"), reply.errorMessage()}});
        return false;
    }
    refresh();
    return reply.arguments().value(0, true).toBool();
}

void SessionActionClient::setState(const QVariantMap &state)
{
    const bool available = state.value(QStringLiteral("available")).toBool();
    const bool scheduled = state.value(QStringLiteral("scheduled")).toBool();
    const int remaining = state.value(QStringLiteral("remainingSeconds")).toInt();
    const QString error = state.value(QStringLiteral("error")).toString();
    if (m_available == available && m_scheduled == scheduled && m_remainingSeconds == remaining && m_error == error)
        return;
    m_available = available;
    m_scheduled = scheduled;
    m_remainingSeconds = remaining;
    m_error = error;
    if (m_scheduled && !m_refreshTimer.isActive())
        m_refreshTimer.start();
    else if (!m_scheduled)
        m_refreshTimer.stop();
    Q_EMIT changed();
}

void SessionActionClient::onStateChanged(const QVariantMap &state)
{
    setState(state);
}
