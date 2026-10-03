#pragma once

#include "router.h"

#include <QDBusContext>
#include <QObject>

class AccountSignalReceiver final : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    void onChanged(const QString &requestId, const QString &state, const QVariantMap &result)
    {
        Q_UNUSED(state)
        emit changed(requestId, result);
    }
Q_SIGNALS:
    void changed(const QString &requestId, const QVariantMap &result);
};

class RouterService final : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.meo.AIRouter1")
public:
    explicit RouterService(QObject *parent = nullptr);

public Q_SLOTS:
    QVariantMap SubmitRequest(const QString &capabilityId, const QVariantMap &arguments);
    QVariantMap SubmitText(const QString &text);
    QVariantMap DecideRequest(const QString &requestId, const QString &fingerprint, bool approve);
    QVariantMap GetRequest(const QString &requestId);
    QVariantList ListCapabilities() const;

Q_SIGNALS:
    void RequestStateChanged(const QVariantMap &request);
    void ActionRequiresConfirmation(const QVariantMap &request);

private:
    void handleAccountResult(const QString &accountRequestId, const QVariantMap &result);
    void launchDesktop(const QString &requestId, const QString &desktopId);
    struct IntentRequest {
        QString id;
        QString caller;
        QString accountRequestId;
        QString state;
        QString message;
        QString actionRequestId;
        QDateTime created;
    };
    QVariantMap intentView(const IntentRequest &request) const;
    Router m_router;
    AccountSignalReceiver m_accountSignals;
    QHash<QString, IntentRequest> m_intents;
    QHash<QString, QString> m_intentByAccountRequest;
};
