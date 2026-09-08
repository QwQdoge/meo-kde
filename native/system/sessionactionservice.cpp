#include "sessionactionservice.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QtGlobal>

namespace
{
constexpr auto notificationService = "org.freedesktop.Notifications";
constexpr auto notificationPath = "/org/freedesktop/Notifications";
constexpr auto notificationInterface = "org.freedesktop.Notifications";
constexpr auto shutdownService = "org.kde.Shutdown";
constexpr auto shutdownPath = "/Shutdown";
constexpr auto shutdownInterface = "org.kde.Shutdown";
}

SessionActionService::SessionActionService(QObject *parent)
    : QObject(parent)
{
    m_tick.setInterval(250);
    connect(&m_tick, &QTimer::timeout, this, [this] {
        if (!m_deadline.isValid())
            return;
        if (remainingSeconds() <= 0) {
            executeLogout();
            return;
        }
        publishState();
        if (remainingSeconds() != m_lastPublishedSecond)
            publishNotification();
    });

    auto bus = QDBusConnection::sessionBus();
    bus.connect(QString::fromLatin1(notificationService), QString::fromLatin1(notificationPath),
                QString::fromLatin1(notificationInterface), QStringLiteral("ActionInvoked"),
                this, SLOT(handleNotificationAction(uint,QString)));
}

void SessionActionService::handleNotificationAction(uint id, const QString &action)
{
    if (id != m_notificationId)
        return;
    if (action == QStringLiteral("cancel"))
        cancel();
    else if (action == QStringLiteral("execute"))
        executeNow();
}

QVariantMap SessionActionService::state() const
{
    return {
        {QStringLiteral("available"), true},
        {QStringLiteral("scheduled"), m_deadline.isValid()},
        {QStringLiteral("remainingSeconds"), remainingSeconds()},
        {QStringLiteral("error"), m_error},
    };
}

bool SessionActionService::scheduleLogout(int seconds)
{
    if (seconds < 1 || seconds > 600) {
        m_error = tr("Choose a logout delay between 1 and 600 seconds.");
        publishState();
        return false;
    }
    m_error.clear();
    m_deadline = QDateTime::currentDateTimeUtc().addSecs(seconds);
    m_totalSeconds = seconds;
    m_lastPublishedSecond = -1;
    m_tick.start();
    publishState();
    publishNotification();
    return true;
}

bool SessionActionService::cancel()
{
    const bool wasScheduled = m_deadline.isValid();
    m_tick.stop();
    m_deadline = {};
    m_totalSeconds = 0;
    m_lastPublishedSecond = -1;
    closeNotification();
    publishState();
    return wasScheduled;
}

bool SessionActionService::executeNow()
{
    if (!m_deadline.isValid()) {
        m_error = tr("No sign-out is scheduled.");
        publishState();
        return false;
    }
    executeLogout();
    return m_error.isEmpty();
}

void SessionActionService::publishState()
{
    Q_EMIT stateChanged(state());
}

void SessionActionService::publishNotification()
{
    const int remaining = remainingSeconds();
    if (!m_deadline.isValid() || remaining <= 0)
        return;

    QVariantMap hints;
    // Plasma reads this conventional progress hint; other servers safely show
    // the accurate remaining-time body without pretending to support progress.
    hints.insert(QStringLiteral("x-kde-progress"), 100 - (remaining * 100 / qMax(1, m_totalSeconds)));
    hints.insert(QStringLiteral("transient"), false);
    auto notification = QDBusMessage::createMethodCall(QString::fromLatin1(notificationService),
                                                        QString::fromLatin1(notificationPath),
                                                        QString::fromLatin1(notificationInterface),
                                                        QStringLiteral("Notify"));
    notification.setArguments({QStringLiteral("Meo Settings"), m_notificationId,
                               QStringLiteral("system-log-out"), tr("Signing out in %1 seconds").arg(remaining),
                               tr("Your apps may still ask to save work."),
                               QStringList{QStringLiteral("cancel"), tr("Cancel"),
                                           QStringLiteral("execute"), tr("Sign out now")}, hints, 0});
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(notification), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        const QDBusPendingReply<uint> reply = *watcher;
        if (reply.isValid())
            m_notificationId = reply.value();
        watcher->deleteLater();
    });
    m_lastPublishedSecond = remaining;
}

void SessionActionService::closeNotification()
{
    if (!m_notificationId)
        return;
    auto close = QDBusMessage::createMethodCall(QString::fromLatin1(notificationService),
                                                QString::fromLatin1(notificationPath),
                                                QString::fromLatin1(notificationInterface),
                                                QStringLiteral("CloseNotification"));
    close.setArguments({m_notificationId});
    QDBusConnection::sessionBus().asyncCall(close);
    m_notificationId = 0;
}

void SessionActionService::executeLogout()
{
    QDBusInterface shutdown(QString::fromLatin1(shutdownService), QString::fromLatin1(shutdownPath),
                            QString::fromLatin1(shutdownInterface), QDBusConnection::sessionBus());
    if (!shutdown.isValid()) {
        m_error = tr("The Plasma session service is unavailable. Sign-out was not started.");
        cancel();
        return;
    }
    const auto reply = shutdown.call(QStringLiteral("logout"));
    if (reply.type() == QDBusMessage::ErrorMessage) {
        m_error = tr("Plasma could not start sign-out: %1").arg(reply.errorMessage());
        cancel();
        return;
    }
    m_error.clear();
    m_tick.stop();
    m_deadline = {};
    m_totalSeconds = 0;
    closeNotification();
    publishState();
}

int SessionActionService::remainingSeconds() const
{
    if (!m_deadline.isValid())
        return 0;
    return qMax(0, QDateTime::currentDateTimeUtc().secsTo(m_deadline));
}
