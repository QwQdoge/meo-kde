#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantMap>

class SessionActionClient final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "SessionActions")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool scheduled READ scheduled NOTIFY changed)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit SessionActionClient(QObject *parent = nullptr);

    bool available() const;
    bool scheduled() const;
    int remainingSeconds() const;
    QString error() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void scheduleLogout(int seconds = 30);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void executeNow();

Q_SIGNALS:
    void changed();

private:
    Q_SLOT void onStateChanged(const QVariantMap &state);
    bool invoke(const QString &method, const QList<QVariant> &arguments = {});
    void setState(const QVariantMap &state);

    QTimer m_refreshTimer;
    bool m_available = false;
    bool m_scheduled = false;
    int m_remainingSeconds = 0;
    QString m_error;
};
