#pragma once

#include <QObject>
#include <QDateTime>
#include <QTimer>
#include <QVariantMap>

// Session-local, D-Bus activated scheduler. It has no system privileges and
// only executes the explicit user-session logout operation.
class SessionActionService final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.meo.SessionAction1")

public:
    explicit SessionActionService(QObject *parent = nullptr);

public Q_SLOTS:
    QVariantMap state() const;
    bool scheduleLogout(int seconds);
    bool cancel();
    bool executeNow();

Q_SIGNALS:
    void stateChanged(const QVariantMap &state);

private:
    Q_SLOT void handleNotificationAction(uint id, const QString &action);
    void publishState();
    void publishNotification();
    void closeNotification();
    void executeLogout();
    int remainingSeconds() const;

    QTimer m_tick;
    QDateTime m_deadline;
    uint m_notificationId = 0;
    int m_totalSeconds = 0;
    int m_lastPublishedSecond = -1;
    QString m_error;
};
