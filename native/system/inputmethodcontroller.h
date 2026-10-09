#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

class QDBusPendingCallWatcher;
class QDBusServiceWatcher;

class InputMethodController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "InputMethods")
    Q_CLASSINFO("QML.Singleton", "true")

    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QStringList groups READ groups NOTIFY inventoryChanged)
    Q_PROPERTY(QString currentGroup READ currentGroup NOTIFY inventoryChanged)
    Q_PROPERTY(QString currentGroupLayout READ currentGroupLayout NOTIFY inventoryChanged)
    Q_PROPERTY(QString currentInputMethod READ currentInputMethod NOTIFY inventoryChanged)
    Q_PROPERTY(QString currentUi READ currentUi NOTIFY stateChanged)
    Q_PROPERTY(bool canRestart READ canRestart NOTIFY stateChanged)
    Q_PROPERTY(QVariantList activeInputMethods READ activeInputMethods NOTIFY inventoryChanged)
    Q_PROPERTY(QVariantList availableInputMethods READ availableInputMethods NOTIFY inventoryChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit InputMethodController(QObject *parent = nullptr);

    bool available() const;
    bool active() const;
    bool busy() const;
    QStringList groups() const;
    QString currentGroup() const;
    QString currentGroupLayout() const { return m_currentGroupLayout; }
    Q_INVOKABLE bool configureMethods(const QStringList &ids);
    QString currentInputMethod() const;
    QString currentUi() const;
    bool canRestart() const;
    QVariantList activeInputMethods() const;
    QVariantList availableInputMethods() const;
    QString lastError() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setCurrentInputMethod(const QString &inputMethodId);
    Q_INVOKABLE bool switchGroup(const QString &groupName);
    Q_INVOKABLE bool applyCurrentGroup(const QStringList &inputMethodIds,
                                       const QStringList &layouts,
                                       const QString &defaultLayout);
    Q_INVOKABLE bool reload();
    Q_INVOKABLE bool restart();
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void stateChanged();
    void inventoryChanged();
    void busyChanged();
    void errorChanged();

private:
    using ReplyHandler = void (InputMethodController::*)(const QList<QVariant> &arguments);

    void setError(const QString &error);
    void clearRuntimeState();
    void setBusy(bool busy);
    void finishRefreshPart(quint64 generation);
    void startRefreshCall(const QString &method,
                          const QList<QVariant> &arguments,
                          quint64 generation,
                          ReplyHandler handler);
    bool startMutationCall(const QString &method,
                           const QList<QVariant> &arguments,
                           const QString &operationName);
    void refreshCurrentGroupInfo(quint64 generation);

    void acceptGroups(const QList<QVariant> &arguments);
    void acceptCurrentGroup(const QList<QVariant> &arguments);
    void acceptCurrentInputMethod(const QList<QVariant> &arguments);
    void acceptCurrentUi(const QList<QVariant> &arguments);
    void acceptState(const QList<QVariant> &arguments);
    void acceptCanRestart(const QList<QVariant> &arguments);
    void acceptActiveInputMethods(const QList<QVariant> &arguments);
    void acceptAvailableInputMethods(const QList<QVariant> &arguments);

    bool hasAvailableInputMethod(const QString &inputMethodId) const;
    bool hasActiveInputMethod(const QString &inputMethodId) const;
    static bool safeIdentifier(const QString &value, int maximumLength = 256);
    static bool safeLayout(const QString &value);

    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    QString m_serviceOwner;
    quint64 m_operationGeneration = 0;
    bool m_mutationInFlight = false;
    bool m_refreshDeferred = false;
    quint64 m_refreshGeneration = 0;
    int m_pendingRefreshCalls = 0;
    bool m_groupInfoReady = false;
    bool m_available = false;
    bool m_active = false;
    bool m_busy = false;
    bool m_canRestart = false;
    QStringList m_groups;
    QString m_currentGroup;
    QString m_currentGroupLayout;
    QString m_currentInputMethod;
    QString m_currentUi;
    QVariantList m_activeInputMethods;
    QVariantList m_availableInputMethods;
    QString m_lastError;
};
