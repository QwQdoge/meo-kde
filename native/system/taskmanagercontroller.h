#pragma once

#include <KConfigWatcher>

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QThreadPool>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

namespace MeoTaskSampling {

struct CpuSnapshot {
    quint64 idle = 0;
    quint64 total = 0;
};

struct DesktopAppInfo {
    QString name;
    QString icon;
    QString desktopId;
};

struct ProcessStaticInfo {
    quint64 startTicks = 0;
    QString name;
    QString appName;
    QString appIcon;
    QString desktopId;
    QString command;
    QString executable;
    QString user;
    QString category;
    qint64 uid = -1;
    bool canControl = false;
};

// Everything a /proc sample needs from the previous state.  Implicitly shared
// containers make the copy handed to the worker cheap; the worker detaches
// only what it modifies, so the GUI thread's members are never touched.
struct SampleInput {
    double elapsedSeconds = 0;
    CpuSnapshot lastCpu;
    QHash<qint64, quint64> lastTicks;
    QHash<qint64, quint64> lastReadBytes;
    QHash<qint64, quint64> lastWriteBytes;
    QHash<qint64, ProcessStaticInfo> staticInfo;
    QHash<QString, DesktopAppInfo> desktopAppsByExecutable;
    QHash<qint64, int> efficiencyOriginalNice;
    quint32 currentUid = 0;
    qint64 pageSize = 4096;
    qint64 selfPid = 0;
};

struct SampleResult {
    CpuSnapshot cpu;
    quint64 cpuTotalDelta = 0;
    QHash<qint64, quint64> ticks;
    QHash<qint64, quint64> readBytes;
    QHash<qint64, quint64> writeBytes;
    QHash<qint64, ProcessStaticInfo> staticInfo;
    QSet<qint64> livePids;
    QVariantList processes;
    QVariantList processTree;
    QVariantList processGroups;
    QVariantList userSummaries;
    double elapsedSeconds = 0;
    qint64 sampleMicroseconds = 0;
};

// Reads /proc and derives the process lists.  Touches no controller state, so
// it is safe to run on a worker thread.
SampleResult sampleProcessSnapshot(const SampleInput &input);

} // namespace MeoTaskSampling

// Flat list model keyed by a stable integer field ("pid").  sync() diffs the
// incoming rows against the current ones and emits remove/move/insert/
// dataChanged per row, so views keep their delegates instead of resetting.
class ProcessRowModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit ProcessRowModel(QObject *parent = nullptr);

    int count() const;
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE void sync(const QVariantList &rows);

Q_SIGNALS:
    void countChanged();

private:
    QList<QVariantMap> m_rows;
    QList<QString> m_keys;
};

class TaskManagerController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Tasks")
    Q_CLASSINFO("QML.Singleton", "true")

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool monitoring READ monitoring NOTIFY monitoringChanged)
    Q_PROPERTY(QStringList activeModules READ activeModules NOTIFY monitoringChanged)
    Q_PROPERTY(int refreshInterval READ refreshInterval WRITE setRefreshInterval NOTIFY refreshIntervalChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)

    Q_PROPERTY(QVariantList processes READ processes NOTIFY dataChanged)
    Q_PROPERTY(QVariantList processTree READ processTree NOTIFY dataChanged)
    Q_PROPERTY(QVariantList processGroups READ processGroups NOTIFY dataChanged)
    Q_PROPERTY(QVariantList userSummaries READ userSummaries NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap selectedProcessDetails READ selectedProcessDetails NOTIFY selectedProcessDetailsChanged)
    Q_PROPERTY(qint64 selectedPid READ selectedPid NOTIFY selectedProcessDetailsChanged)
    Q_PROPERTY(bool processNetworkThroughputAvailable READ processNetworkThroughputAvailable CONSTANT)
    Q_PROPERTY(bool selectedProcessGpuAvailable READ selectedProcessGpuAvailable NOTIFY selectedProcessDetailsChanged)

    Q_PROPERTY(QVariantList startupApps READ startupApps NOTIFY startupAppsChanged)
    Q_PROPERTY(QVariantList services READ services NOTIFY servicesChanged)
    Q_PROPERTY(bool servicesAvailable READ servicesAvailable NOTIFY servicesChanged)
    Q_PROPERTY(bool serviceQuerying READ serviceQuerying NOTIFY servicesChanged)
    Q_PROPERTY(QVariantMap selectedServiceDetails READ selectedServiceDetails NOTIFY serviceDetailsChanged)
    Q_PROPERTY(bool serviceDetailsQuerying READ serviceDetailsQuerying NOTIFY serviceDetailsChanged)

    Q_PROPERTY(QString actionError READ actionError NOTIFY actionErrorChanged)

public:
    explicit TaskManagerController(QObject *parent = nullptr);
    ~TaskManagerController() override;

    bool available() const;
    bool monitoring() const;
    QStringList activeModules() const;
    int refreshInterval() const;
    void setRefreshInterval(int interval);
    bool paused() const;
    void setPaused(bool paused);

    QVariantList processes() const;
    QVariantList processTree() const;
    QVariantList processGroups() const;
    QVariantList userSummaries() const;
    QVariantMap selectedProcessDetails() const;
    qint64 selectedPid() const;
    bool processNetworkThroughputAvailable() const;
    bool selectedProcessGpuAvailable() const;

    QVariantList startupApps() const;
    QVariantList services() const;
    bool servicesAvailable() const;
    bool serviceQuerying() const;
    QVariantMap selectedServiceDetails() const;
    bool serviceDetailsQuerying() const;

    QString actionError() const;

    Q_INVOKABLE void subscribe(const QString &clientId, const QStringList &modules);
    Q_INVOKABLE void unsubscribe(const QString &clientId);
    Q_INVOKABLE void refreshNow();
    Q_INVOKABLE void selectProcess(qint64 pid);

    Q_INVOKABLE bool terminateProcess(qint64 pid, bool force = false);
    Q_INVOKABLE bool terminateProcesses(const QVariantList &pids, bool force = false);
    Q_INVOKABLE bool terminateProcessTree(qint64 pid, bool force = false);
    Q_INVOKABLE bool setProcessSuspended(qint64 pid, bool suspended);
    Q_INVOKABLE bool setProcessPriority(qint64 pid, int niceValue);
    Q_INVOKABLE bool setProcessEfficiency(qint64 pid, bool enabled);
    Q_INVOKABLE bool setProcessCpuAffinity(qint64 pid, const QVariantList &cpuIndices);
    Q_INVOKABLE bool setProcessCpuAffinityAll(qint64 pid);
    Q_INVOKABLE bool openProcessLocation(qint64 pid);
    Q_INVOKABLE bool openProcessWorkingDirectory(qint64 pid);
    Q_INVOKABLE bool copyProcessCommand(qint64 pid);
    Q_INVOKABLE bool copyProcessExecutablePath(qint64 pid);
    Q_INVOKABLE bool copyProcessWorkingDirectory(qint64 pid);

    Q_INVOKABLE void refreshStartupApps();
    Q_INVOKABLE bool setStartupEnabled(const QString &desktopId, bool enabled);

    Q_INVOKABLE void refreshServices();
    Q_INVOKABLE void selectService(const QString &unit, const QString &scope);
    Q_INVOKABLE void serviceAction(const QString &unit, const QString &action);

    Q_INVOKABLE void clearActionError();

Q_SIGNALS:
    void monitoringChanged();
    void refreshIntervalChanged();
    void pausedChanged();
    void dataChanged();
    void selectedProcessDetailsChanged();
    void startupAppsChanged();
    void servicesChanged();
    void serviceDetailsChanged();
    void actionErrorChanged();
    void processActionCompleted(qint64 pid, const QString &action);
    void startupActionCompleted(const QString &desktopId, bool enabled);
    void serviceActionCompleted(const QString &unit, const QString &action);

private:
    using CpuSnapshot = MeoTaskSampling::CpuSnapshot;
    using DesktopAppInfo = MeoTaskSampling::DesktopAppInfo;
    using ProcessStaticInfo = MeoTaskSampling::ProcessStaticInfo;

    void rebuildActiveModules();
    bool wantsModule(const QString &module) const;
    bool wantsProcessSampling() const;
    void updateTimer();
    // Starts an off-thread /proc sample.  A tick (coalesce == false) is
    // dropped while one is in flight; an explicit request is remembered and
    // re-run once the in-flight sample has been applied.
    void requestSample(bool coalesce);
    void applySample(MeoTaskSampling::SampleResult result, quint64 generation);
    void invalidateSampling();
    void rebuildDesktopAppIndex();
    void updateSelectedProcessDetails(double elapsedSeconds);
    void setActionError(const QString &message);

    bool m_available = false;
    int m_refreshInterval = 2000;
    KConfigWatcher::Ptr m_configWatcher;
    void applyRefreshInterval(int interval, bool persist);
    bool m_paused = false;
    QTimer m_refreshTimer;
    QElapsedTimer m_rateClock;
    QHash<QString, QStringList> m_clients;
    QSet<QString> m_activeModules;

    QVariantList m_processes;
    QVariantList m_processTree;
    QVariantList m_processGroups;
    QVariantList m_userSummaries;
    QVariantMap m_selectedProcessDetails;
    qint64 m_selectedPid = -1;
    bool m_selectedProcessGpuAvailable = false;

    QThreadPool m_samplePool;
    bool m_sampleInFlight = false;
    bool m_samplePending = false;
    quint64 m_sampleGeneration = 0;
    bool m_logTiming = false;

    CpuSnapshot m_lastCpu;
    quint64 m_lastCpuTotalDelta = 0;
    QHash<qint64, quint64> m_lastProcessTicks;
    QHash<qint64, quint64> m_lastProcessReadBytes;
    QHash<qint64, quint64> m_lastProcessWriteBytes;
    qint64 m_lastSelectedGpuPid = -1;
    quint64 m_lastSelectedGpuEngineNs = 0;
    QHash<qint64, int> m_efficiencyOriginalNice;
    QHash<QString, DesktopAppInfo> m_desktopAppsByExecutable;
    QHash<qint64, ProcessStaticInfo> m_processStaticInfo;

    QVariantList m_startupApps;
    QHash<QString, QVariantMap> m_startupById;

    QVariantList m_services;
    bool m_servicesAvailable = false;
    bool m_serviceQuerying = false;
    QVariantMap m_selectedServiceDetails;
    bool m_serviceDetailsQuerying = false;
    QString m_selectedServiceUnit;
    QString m_selectedServiceScope;

    QString m_actionError;
};
