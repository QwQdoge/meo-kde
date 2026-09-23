#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

class PerformanceController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Performance")
    Q_CLASSINFO("QML.Singleton", "true")

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool monitoring READ monitoring NOTIFY monitoringChanged)
    Q_PROPERTY(QStringList activeModules READ activeModules NOTIFY monitoringChanged)
    Q_PROPERTY(int refreshInterval READ refreshInterval WRITE setRefreshInterval NOTIFY refreshIntervalChanged)

    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY metricsChanged)
    Q_PROPERTY(double cpuFrequencyMHz READ cpuFrequencyMHz NOTIFY metricsChanged)
    Q_PROPERTY(double cpuTemperature READ cpuTemperature NOTIFY metricsChanged)
    Q_PROPERTY(QString cpuModel READ cpuModel NOTIFY metricsChanged)
    Q_PROPERTY(int logicalCores READ logicalCores NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList cpuCores READ cpuCores NOTIFY metricsChanged)

    Q_PROPERTY(double memoryUsage READ memoryUsage NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memoryUsedBytes READ memoryUsedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memoryTotalBytes READ memoryTotalBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memoryAvailableBytes READ memoryAvailableBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memoryCachedBytes READ memoryCachedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memoryBuffersBytes READ memoryBuffersBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 memorySharedBytes READ memorySharedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 swapUsedBytes READ swapUsedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 swapTotalBytes READ swapTotalBytes NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList memoryHistory READ memoryHistory NOTIFY metricsChanged)

    Q_PROPERTY(double networkRxBytesPerSecond READ networkRxBytesPerSecond NOTIFY metricsChanged)
    Q_PROPERTY(double networkTxBytesPerSecond READ networkTxBytesPerSecond NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList networkRxHistory READ networkRxHistory NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList networkTxHistory READ networkTxHistory NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList networkInterfaces READ networkInterfaces NOTIFY metricsChanged)

    Q_PROPERTY(double diskReadBytesPerSecond READ diskReadBytesPerSecond NOTIFY metricsChanged)
    Q_PROPERTY(double diskWriteBytesPerSecond READ diskWriteBytesPerSecond NOTIFY metricsChanged)
    Q_PROPERTY(qint64 storageUsedBytes READ storageUsedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 storageTotalBytes READ storageTotalBytes NOTIFY metricsChanged)
    Q_PROPERTY(double storageUsage READ storageUsage NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList diskReadHistory READ diskReadHistory NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList diskWriteHistory READ diskWriteHistory NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY metricsChanged)

    Q_PROPERTY(QString gpuName READ gpuName NOTIFY metricsChanged)
    Q_PROPERTY(double gpuUsage READ gpuUsage NOTIFY metricsChanged)
    Q_PROPERTY(double gpuTemperature READ gpuTemperature NOTIFY metricsChanged)
    Q_PROPERTY(qint64 gpuMemoryUsedBytes READ gpuMemoryUsedBytes NOTIFY metricsChanged)
    Q_PROPERTY(qint64 gpuMemoryTotalBytes READ gpuMemoryTotalBytes NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList gpus READ gpus NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList gpuHistory READ gpuHistory NOTIFY metricsChanged)

    Q_PROPERTY(qint64 uptimeSeconds READ uptimeSeconds NOTIFY metricsChanged)
    Q_PROPERTY(double loadAverage1 READ loadAverage1 NOTIFY metricsChanged)
    Q_PROPERTY(double loadAverage5 READ loadAverage5 NOTIFY metricsChanged)
    Q_PROPERTY(double loadAverage15 READ loadAverage15 NOTIFY metricsChanged)
    Q_PROPERTY(int processCount READ processCount NOTIFY metricsChanged)
    Q_PROPERTY(QString systemSummary READ systemSummary NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList topCpuProcesses READ topCpuProcesses NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList topMemoryProcesses READ topMemoryProcesses NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList processes READ processes NOTIFY metricsChanged)
    Q_PROPERTY(QString processActionError READ processActionError NOTIFY processActionErrorChanged)

public:
    explicit PerformanceController(QObject *parent = nullptr);

    bool available() const;
    bool monitoring() const;
    QStringList activeModules() const;
    int refreshInterval() const;
    void setRefreshInterval(int interval);

    double cpuUsage() const;
    double cpuFrequencyMHz() const;
    double cpuTemperature() const;
    QString cpuModel() const;
    int logicalCores() const;
    QVariantList cpuHistory() const;
    QVariantList cpuCores() const;

    double memoryUsage() const;
    qint64 memoryUsedBytes() const;
    qint64 memoryTotalBytes() const;
    qint64 memoryAvailableBytes() const;
    qint64 memoryCachedBytes() const;
    qint64 memoryBuffersBytes() const;
    qint64 memorySharedBytes() const;
    qint64 swapUsedBytes() const;
    qint64 swapTotalBytes() const;
    QVariantList memoryHistory() const;

    double networkRxBytesPerSecond() const;
    double networkTxBytesPerSecond() const;
    QVariantList networkRxHistory() const;
    QVariantList networkTxHistory() const;
    QVariantList networkInterfaces() const;

    double diskReadBytesPerSecond() const;
    double diskWriteBytesPerSecond() const;
    qint64 storageUsedBytes() const;
    qint64 storageTotalBytes() const;
    double storageUsage() const;
    QVariantList diskReadHistory() const;
    QVariantList diskWriteHistory() const;
    QVariantList disks() const;

    QString gpuName() const;
    double gpuUsage() const;
    double gpuTemperature() const;
    qint64 gpuMemoryUsedBytes() const;
    qint64 gpuMemoryTotalBytes() const;
    QVariantList gpus() const;
    QVariantList gpuHistory() const;

    qint64 uptimeSeconds() const;
    double loadAverage1() const;
    double loadAverage5() const;
    double loadAverage15() const;
    int processCount() const;
    QString systemSummary() const;
    QVariantList topCpuProcesses() const;
    QVariantList topMemoryProcesses() const;
    QVariantList processes() const;
    QString processActionError() const;

    Q_INVOKABLE void subscribe(const QString &clientId, const QStringList &modules);
    Q_INVOKABLE void unsubscribe(const QString &clientId);
    Q_INVOKABLE void refreshNow();
    Q_INVOKABLE bool terminateProcess(qint64 pid, bool force = false);
    Q_INVOKABLE bool setProcessPriority(qint64 pid, int niceValue);
    Q_INVOKABLE void clearProcessActionError();

Q_SIGNALS:
    void monitoringChanged();
    void refreshIntervalChanged();
    void metricsChanged();
    void processActionErrorChanged();
    void processActionCompleted(qint64 pid, const QString &action);

private:
    struct CpuSnapshot {
        quint64 idle = 0;
        quint64 total = 0;
    };

    void rebuildActiveModules();
    bool wantsModule(const QString &module) const;
    void refreshStaticSystemInfo();
    void sampleCpu();
    void sampleMemory();
    void sampleNetwork(double elapsedSeconds);
    void sampleDisk(double elapsedSeconds);
    void sampleGpu();
    void startNvidiaGpuSample();
    void sampleSystem();
    void sampleProcesses();
    void appendHistory(QVariantList &history, double value);
    void setProcessActionError(const QString &message);

    bool m_available = false;
    int m_refreshInterval = 2000;
    QTimer m_refreshTimer;
    QElapsedTimer m_rateClock;
    QHash<QString, QStringList> m_clients;
    QSet<QString> m_activeModules;

    QString m_cpuModel;
    int m_logicalCores = 1;
    double m_cpuUsage = 0;
    double m_cpuFrequencyMHz = 0;
    double m_cpuTemperature = 0;
    CpuSnapshot m_lastCpu;
    quint64 m_lastCpuTotalDelta = 0;
    QVariantList m_cpuHistory;
    QVariantList m_cpuCores;
    QHash<int, CpuSnapshot> m_lastCoreCpu;
    QHash<int, QVariantList> m_coreHistories;

    double m_memoryUsage = 0;
    qint64 m_memoryUsedBytes = 0;
    qint64 m_memoryTotalBytes = 0;
    qint64 m_memoryAvailableBytes = 0;
    qint64 m_memoryCachedBytes = 0;
    qint64 m_memoryBuffersBytes = 0;
    qint64 m_memorySharedBytes = 0;
    qint64 m_swapUsedBytes = 0;
    qint64 m_swapTotalBytes = 0;
    QVariantList m_memoryHistory;

    quint64 m_lastNetworkRxBytes = 0;
    quint64 m_lastNetworkTxBytes = 0;
    bool m_haveNetworkSample = false;
    double m_networkRxRate = 0;
    double m_networkTxRate = 0;
    QVariantList m_networkRxHistory;
    QVariantList m_networkTxHistory;
    QVariantList m_networkInterfaces;
    QHash<QString, quint64> m_lastInterfaceRxBytes;
    QHash<QString, quint64> m_lastInterfaceTxBytes;
    QHash<QString, QVariantList> m_interfaceRxHistories;
    QHash<QString, QVariantList> m_interfaceTxHistories;

    quint64 m_lastDiskReadBytes = 0;
    quint64 m_lastDiskWriteBytes = 0;
    bool m_haveDiskSample = false;
    double m_diskReadRate = 0;
    double m_diskWriteRate = 0;
    qint64 m_storageUsedBytes = 0;
    qint64 m_storageTotalBytes = 0;
    double m_storageUsage = 0;
    QVariantList m_diskReadHistory;
    QVariantList m_diskWriteHistory;
    QVariantList m_disks;
    QHash<QString, quint64> m_lastDeviceReadBytes;
    QHash<QString, quint64> m_lastDeviceWriteBytes;
    QHash<QString, quint64> m_lastDeviceIoMilliseconds;
    QHash<QString, QVariantList> m_deviceReadHistories;
    QHash<QString, QVariantList> m_deviceWriteHistories;
    QHash<QString, QVariantList> m_deviceUsageHistories;

    QString m_gpuName;
    double m_gpuUsage = -1;
    double m_gpuTemperature = 0;
    qint64 m_gpuMemoryUsedBytes = 0;
    qint64 m_gpuMemoryTotalBytes = 0;
    QVariantList m_gpus;
    QVariantList m_gpuHistory;
    QHash<QString, QVariantList> m_gpuHistories;
    bool m_nvidiaQuerying = false;
    bool m_nvidiaSmiUnavailable = false;

    qint64 m_uptimeSeconds = 0;
    double m_load1 = 0;
    double m_load5 = 0;
    double m_load15 = 0;
    int m_processCount = 0;
    QString m_systemSummary;
    QVariantList m_topCpuProcesses;
    QVariantList m_topMemoryProcesses;
    QVariantList m_processes;
    QString m_processActionError;
    QHash<qint64, quint64> m_lastProcessTicks;
};
