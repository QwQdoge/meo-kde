#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QVariantMap>
#include <functional>

class Router final : public QObject
{
    Q_OBJECT
public:
    enum class Effect { Read, Session, Persistent, Irreversible };
    struct Capability {
        QString id;
        QString title;
        QString impact;
        Effect effect;
        QHash<QString, QMetaType::Type> arguments;
        std::function<QString(const QVariantMap &)> describeTarget;
        std::function<void(const QString &, const QVariantMap &)> dispatch;
    };

    explicit Router(bool irreversibleEnabled = false, QObject *parent = nullptr);
    bool addCapability(Capability capability);
    QVariantMap submit(const QString &id, const QVariantMap &arguments, const QString &caller);
    QVariantMap decide(const QString &requestId, const QString &fingerprint, bool approve, const QString &caller);
    QVariantMap get(const QString &requestId, const QString &caller);
    QVariantList capabilities() const;
    void complete(const QString &requestId, bool success, const QString &message);
    void expirePending(const QDateTime &now = QDateTime::currentDateTimeUtc());

Q_SIGNALS:
    void requestChanged(const QVariantMap &request);
    void confirmationRequired(const QVariantMap &request);

private:
    struct Request {
        QString id;
        QString capabilityId;
        QString caller;
        QString fingerprint;
        QVariantMap arguments;
        QString title;
        QString target;
        QString impact;
        QString state;
        QString message;
        QDateTime created;
        QDateTime expires;
    };
    QVariantMap view(const Request &request) const;
    static QString fingerprint(const QString &id, const QVariantMap &arguments);
    QHash<QString, Capability> m_capabilities;
    QHash<QString, Request> m_requests;
    bool m_irreversibleEnabled;
};
