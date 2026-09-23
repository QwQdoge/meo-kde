#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class TaskManagerController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Tasks")
    Q_CLASSINFO("QML.Singleton", "true")

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool monitoring READ monitoring NOTIFY monitoringChanged)
    Q_PROPERTY(QStringList activeModules READ activeModules NOTIFY monitoringChanged)
    Q_PROPERTY(int refreshInterval READ refreshInterval WRITE setRefreshInterval NOTIFY refreshIntervalChanged)

    Q_PROPERTY(QVariantList processes READ processes NOTIFY dataChanged)
    Q_PROPERTY(QVariantList processTree READ processTree NOTIFY dataChanged)
    Q_PROPERTY(QVariantList userSummaries READ userSummaries NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap selectedProcessDetails READ selectedProcessDetails NOTIFY selectedProcessDetailsChanged)
    Q_PROPERTY(qint64 selectedPid READ selectedPid NOTIFY selectedProcessDetailsChanged)
    Q_PROPERTY(bool processNetworkThroughputAvailable READ processNetworkThroughputAvailable CONSTANT)
    Q_PROPERTY(bool selectedProcessGpuAvailable READ selectedProcessGpuAvailable NOTIFY selectedProcessDetailsChanged)

    Q_PROPERTY(QVariantList startupApps READ startupApps NOTIFY startupAppsChanged)
    Q_PROPERTY(QVariantList services READ services NOTIFY servicesChanged)
    Q_PROPERTY(bool servicesAvailable READ servicesAvailable NOTIFY servicesChanged)
    Q_PROPERTY(bool serviceQuerying READ serviceQuerying NOTIFY servicesChanged)

    Q_PROPERTY(QString actionError READ actionError NOTIFY actionErrorChanged)

public:
    explicit TaskManagerController(QObject *parent = nullptr);

    bool available() const;
    bool monitoring() const;
    QStringList activeModules() const;
    int refreshInterval() const;
    void setRefreshInterval(int interval);

    QVariantList processes() const;
    QVariantList processTree() const;
    QVariantList userSummaries() const;
    QVariantMap selectedProcessDetails() const;
    qint64 selectedPid() const;
    bool processNetworkThroughputAvailable() const;
    bool selectedProcessGpuAvailable() const;

    QVariantList startupApps() const;
    QVariantList services() const;
    bool servicesAvailable() const;
    bool serviceQuerying() const;

    QString actionError() const;

    Q_INVOKABLE void subscribe(const QString &clientId, const QStringList &modules);
    Q_INVOKABLE void unsubscribe(const QString &clientId);
    Q_INVOKABLE void refreshNow();
    Q_INVOKABLE void selectProcess(qint64 pid);

    Q_INVOKABLE bool terminateProcess(qint64 pid, bool force = false);
    Q_INVOKABLE bool setProcessPriority(qint64 pid, int niceValue);
    Q_INVOKABLE bool setProcessEfficiency(qint64 pid, bool enabled);

    Q_INVOKABLE void refreshStartupApps();
    Q_INVOKABLE bool setStartupEnabled(const QString &desktopId, bool enabled);

    Q_INVOKABLE void refreshServices();
    Q_INVOKABLE void serviceAction(const QString &unit, const QString &action);

    Q_INVOKABLE void clearActionError();

Q_SIGNALS:
    void monitoringChanged();
    void refreshIntervalChanged();
    void dataChanged();
    void selectedProcessDetailsChanged();
    void startupAppsChanged();
    void servicesChanged();
    void actionErrorChanged();
    void processActionCompleted(qint64 pid, const QString &action);
    void startupActionCompleted(const QString &desktopId, bool enabled);
    void serviceActionCompleted(const QString &unit, const QString &action);

private:
    struct CpuSnapshot {
        quint64 idle = 0;
        quint64 total = 0;
    };

    struct DesktopAppInfo {
        QString name;
        QString icon;
        QString desktopId;
    };

    void rebuildActiveModules();
    bool wantsModule(const QString &module) const;
    bool wantsProcessSampling() const;
    void updateTimer();
    void sampleProcesses(double elapsedSeconds);
    void rebuildDesktopAppIndex();
    void updateSelectedProcessDetails(double elapsedSeconds);
    void setActionError(const QString &message);

    bool m_available = false;
    int m_refreshInterval = 2000;
    QTimer m_refreshTimer;
    QElapsedTimer m_rateClock;
    QHash<QString, QStringList> m_clients;
    QSet<QString> m_activeModules;

    QVariantList m_processes;
    QVariantList m_processTree;
    QVariantList m_userSummaries;
    QVariantMap m_selectedProcessDetails;
    qint64 m_selectedPid = -1;
    bool m_selectedProcessGpuAvailable = false;

    CpuSnapshot m_lastCpu;
    quint64 m_lastCpuTotalDelta = 0;
    QHash<qint64, quint64> m_lastProcessTicks;
    QHash<qint64, quint64> m_lastProcessReadBytes;
    QHash<qint64, quint64> m_lastProcessWriteBytes;
    qint64 m_lastSelectedGpuPid = -1;
    quint64 m_lastSelectedGpuEngineNs = 0;
    QHash<qint64, int> m_efficiencyOriginalNice;
    QHash<QString, DesktopAppInfo> m_desktopAppsByExecutable;

    QVariantList m_startupApps;
    QHash<QString, QVariantMap> m_startupById;

    QVariantList m_services;
    bool m_servicesAvailable = false;
    bool m_serviceQuerying = false;

    QString m_actionError;
};
