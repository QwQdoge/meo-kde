#pragma once

#include <PolkitQt1/Agent/Listener>
#include <PolkitQt1/Agent/Session>
#include <PolkitQt1/Details>
#include <PolkitQt1/Identity>

#include <QHash>
#include <QPointer>
#include <QStringList>
#include <QTimer>
#include <QtGlobal>

class QWindow;

class AuthenticationController final : public PolkitQt1::Agent::Listener
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.Polkit1AuthAgent")

    Q_PROPERTY(bool inProgress READ inProgress NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool echoResponse READ echoResponse NOTIFY stateChanged)
    Q_PROPERTY(QString actionId READ actionId NOTIFY requestChanged)
    Q_PROPERTY(QString message READ message NOTIFY requestChanged)
    Q_PROPERTY(QString requesterLabel READ requesterLabel NOTIFY requestChanged)
    Q_PROPERTY(QString prompt READ prompt NOTIFY stateChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY stateChanged)
    Q_PROPERTY(QString infoText READ infoText NOTIFY stateChanged)
    Q_PROPERTY(QStringList identities READ identities NOTIFY identitiesChanged)
    Q_PROPERTY(int selectedIdentityIndex READ selectedIdentityIndex NOTIFY identitiesChanged)
    Q_PROPERTY(int attemptsRemaining READ attemptsRemaining NOTIFY stateChanged)

public:
    explicit AuthenticationController(QObject *parent = nullptr);
    ~AuthenticationController() override;

    bool inProgress() const { return m_inProgress; }
    bool busy() const { return m_busy; }
    bool echoResponse() const { return m_echoResponse; }
    QString actionId() const { return m_actionId; }
    QString message() const { return m_message; }
    QString requesterLabel() const { return m_requesterLabel; }
    QString prompt() const { return m_prompt; }
    QString errorText() const { return m_errorText; }
    QString infoText() const { return m_infoText; }
    QStringList identities() const { return m_identityNames; }
    int selectedIdentityIndex() const { return m_selectedIdentityIndex; }
    int attemptsRemaining() const { return qMax(0, MaximumAttempts - m_attempts); }

    bool registerForCurrentSession();

    Q_INVOKABLE void submitResponse(QString response);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void selectIdentity(int index);
    Q_INVOKABLE void setDialogWindow(QObject *windowObject);

public Q_SLOTS:
    void initiateAuthentication(const QString &actionId,
                                const QString &message,
                                const QString &iconName,
                                const PolkitQt1::Details &details,
                                const QString &cookie,
                                const PolkitQt1::Identity::List &identities,
                                PolkitQt1::Agent::AsyncResult *result) override;
    bool initiateAuthenticationFinish() override;
    void cancelAuthentication() override;

    Q_SCRIPTABLE void setWIdForAction(const QString &action, qulonglong windowId);
    Q_SCRIPTABLE void setWindowHandleForAction(const QString &action, const QString &handle);
    Q_SCRIPTABLE void setActivationTokenForAction(const QString &action, const QString &token);

Q_SIGNALS:
    void stateChanged();
    void requestChanged();
    void identitiesChanged();
    void clearResponseRequested();
    void focusResponseRequested();

private:
    static constexpr int MaximumAttempts = 3;
    static constexpr int RequestTimeoutMs = 5 * 60 * 1000;

    void beginSession();
    void cancelActiveSession();
    void finish(const QString &error = {});
    void resetPublicState();
    void applyWindowContext();
    QString displayNameForIdentity(const PolkitQt1::Identity &identity) const;
    QString labelForAction(const QString &action) const;

    bool m_inProgress = false;
    bool m_dbusObjectRegistered = false;
    bool m_busy = false;
    bool m_echoResponse = false;
    bool m_cancelled = false;
    int m_attempts = 0;
    int m_selectedIdentityIndex = -1;

    QString m_actionId;
    QString m_message;
    QString m_requesterLabel;
    QString m_prompt;
    QString m_errorText;
    QString m_infoText;
    QString m_cookie;
    QStringList m_identityNames;
    PolkitQt1::Identity::List m_identities;
    QPointer<PolkitQt1::Agent::Session> m_session;
    PolkitQt1::Agent::AsyncResult *m_result = nullptr;
    QPointer<QWindow> m_dialogWindow;
    QTimer m_deadline;
    QHash<QString, QString> m_windowHandles;
    QHash<QString, QString> m_activationTokens;
};
