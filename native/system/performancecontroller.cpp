#include "performancecontroller.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QProcess>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QSysInfo>
#include <QThread>
#include <QVariantMap>
#include <QtGlobal>

#include <algorithm>
#include <cerrno>
#include <csignal>
#include <cmath>
#include <cstring>
#include <pwd.h>
#include <sys/resource.h>
#include <unistd.h>

namespace
{
constexpr int kHistoryLimit = 60;

QByteArray readBytes(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return file.readAll();
}

QString readText(const QString &path)
{
    return QString::fromUtf8(readBytes(path)).trimmed();
}

qint64 readInteger(const QString &path, qint64 fallback = -1)
{
    bool ok = false;
    const qint64 value = readText(path).toLongLong(&ok);
    return ok ? value : fallback;
}

double readTemperatureFromHwmon(const QString &path, bool preferCpuLabels)
{
    QDir dir(path);
    const QStringList inputs = dir.entryList({QStringLiteral("temp*_input")}, QDir::Files, QDir::Name);
    double fallback = 0;
    double preferred = 0;
    for (const QString &input : inputs) {
        const qint64 milliDegrees = readInteger(dir.filePath(input));
        if (milliDegrees <= 0) {
            continue;
        }
        const double value = milliDegrees / 1000.0;
        if (value <= 0 || value > 150) {
            continue;
        }
        fallback = std::max(fallback, value);
        if (preferCpuLabels) {
            QString labelFile = input;
            labelFile.replace(QStringLiteral("_input"), QStringLiteral("_label"));
            const QString label = readText(dir.filePath(labelFile)).toLower();
            if (label.contains(QStringLiteral("package"))
                || label.contains(QStringLiteral("tctl"))
                || label.contains(QStringLiteral("tdie"))) {
                preferred = std::max(preferred, value);
            }
        }
    }
    return preferred > 0 ? preferred : fallback;
}

double cpuTemperature()
{
    QDir hwmon(QStringLiteral("/sys/class/hwmon"));
    const QStringList entries = hwmon.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    double fallback = 0;
    for (const QString &entry : entries) {
        const QString base = hwmon.filePath(entry);
        const QString name = readText(base + QStringLiteral("/name")).toLower();
        const double value = readTemperatureFromHwmon(base, true);
        if (value <= 0) {
            continue;
        }
        if (name == QStringLiteral("coretemp")
            || name == QStringLiteral("k10temp")
            || name == QStringLiteral("zenpower")) {
            return value;
        }
        if (name.contains(QStringLiteral("cpu"))
            || name.contains(QStringLiteral("soc"))
            || name == QStringLiteral("acpitz")) {
            fallback = std::max(fallback, value);
        }
    }
    return fallback;
}

double cpuFrequencyMHzForCore(int core)
{
    const qint64 khz = readInteger(
        QStringLiteral("/sys/devices/system/cpu/cpu%1/cpufreq/scaling_cur_freq").arg(core));
    return khz > 0 ? khz / 1000.0 : 0;
}

double currentCpuFrequencyMHz()
{
    QDir cpuRoot(QStringLiteral("/sys/devices/system/cpu"));
    const QStringList cpus = cpuRoot.entryList({QStringLiteral("cpu[0-9]*")},
                                                QDir::Dirs | QDir::NoDotAndDotDot,
                                                QDir::Name);
    double sumKHz = 0;
    int count = 0;
    for (const QString &cpu : cpus) {
        const qint64 khz = readInteger(cpuRoot.filePath(cpu + QStringLiteral("/cpufreq/scaling_cur_freq")));
        if (khz > 0) {
            sumKHz += khz;
            ++count;
        }
    }
    if (count > 0) {
        return sumKHz / count / 1000.0;
    }

    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/cpuinfo")).split('\n');
    double sumMHz = 0;
    count = 0;
    for (const QByteArray &line : lines) {
        if (!line.startsWith("cpu MHz")) {
            continue;
        }
        const int colon = line.indexOf(':');
        bool ok = false;
        const double mhz = line.mid(colon + 1).trimmed().toDouble(&ok);
        if (ok) {
            sumMHz += mhz;
            ++count;
        }
    }
    return count > 0 ? sumMHz / count : 0;
}

QString cpuModelName()
{
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/cpuinfo")).split('\n');
    for (const QByteArray &line : lines) {
        if (line.startsWith("model name") || line.startsWith("Hardware")) {
            const int colon = line.indexOf(':');
            if (colon >= 0) {
                return QString::fromUtf8(line.mid(colon + 1)).trimmed();
            }
        }
    }
    return {};
}

QString gpuVendorLabel(const QString &vendor)
{
    if (vendor.compare(QStringLiteral("0x10de"), Qt::CaseInsensitive) == 0) {
        return QStringLiteral("NVIDIA GPU");
    }
    if (vendor.compare(QStringLiteral("0x1002"), Qt::CaseInsensitive) == 0) {
        return QStringLiteral("AMD GPU");
    }
    if (vendor.compare(QStringLiteral("0x8086"), Qt::CaseInsensitive) == 0) {
        return QStringLiteral("Intel GPU");
    }
    return QStringLiteral("GPU");
}

double gpuTemperatureAt(const QString &devicePath)
{
    QDir hwmonRoot(devicePath + QStringLiteral("/hwmon"));
    const QStringList entries = hwmonRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    double value = 0;
    for (const QString &entry : entries) {
        value = std::max(value, readTemperatureFromHwmon(hwmonRoot.filePath(entry), false));
    }
    return value;
}

QVariantList takeProcesses(const QVector<QVariantMap> &source, int limit)
{
    QVariantList result;
    result.reserve(std::min<qsizetype>(static_cast<qsizetype>(limit), source.size()));
    for (int index = 0; index < source.size() && index < limit; ++index) {
        result.push_back(source.at(index));
    }
    return result;
}
}

PerformanceController::PerformanceController(QObject *parent)
    : QObject(parent)
{
    m_available = QFileInfo::exists(QStringLiteral("/proc/stat"))
        && QFileInfo::exists(QStringLiteral("/proc/meminfo"));
    m_refreshTimer.setInterval(m_refreshInterval);
    connect(&m_refreshTimer, &QTimer::timeout, this, &PerformanceController::refreshNow);
    refreshStaticSystemInfo();
}

bool PerformanceController::available() const { return m_available; }
bool PerformanceController::monitoring() const { return !m_clients.isEmpty(); }

QStringList PerformanceController::activeModules() const
{
    QStringList result = m_activeModules.values();
    result.sort();
    return result;
}

int PerformanceController::refreshInterval() const { return m_refreshInterval; }

void PerformanceController::setRefreshInterval(int interval)
{
    const int bounded = qBound(500, interval, 10000);
    if (bounded == m_refreshInterval) {
        return;
    }
    m_refreshInterval = bounded;
    m_refreshTimer.setInterval(m_refreshInterval);
    Q_EMIT refreshIntervalChanged();
}

double PerformanceController::cpuUsage() const { return m_cpuUsage; }
double PerformanceController::cpuFrequencyMHz() const { return m_cpuFrequencyMHz; }
double PerformanceController::cpuTemperature() const { return m_cpuTemperature; }
QString PerformanceController::cpuModel() const { return m_cpuModel; }
int PerformanceController::logicalCores() const { return m_logicalCores; }
QVariantList PerformanceController::cpuHistory() const { return m_cpuHistory; }
QVariantList PerformanceController::cpuCores() const { return m_cpuCores; }
double PerformanceController::memoryUsage() const { return m_memoryUsage; }
qint64 PerformanceController::memoryUsedBytes() const { return m_memoryUsedBytes; }
qint64 PerformanceController::memoryTotalBytes() const { return m_memoryTotalBytes; }
qint64 PerformanceController::swapUsedBytes() const { return m_swapUsedBytes; }
qint64 PerformanceController::swapTotalBytes() const { return m_swapTotalBytes; }
QVariantList PerformanceController::memoryHistory() const { return m_memoryHistory; }
double PerformanceController::networkRxBytesPerSecond() const { return m_networkRxRate; }
double PerformanceController::networkTxBytesPerSecond() const { return m_networkTxRate; }
QVariantList PerformanceController::networkRxHistory() const { return m_networkRxHistory; }
QVariantList PerformanceController::networkTxHistory() const { return m_networkTxHistory; }
double PerformanceController::diskReadBytesPerSecond() const { return m_diskReadRate; }
double PerformanceController::diskWriteBytesPerSecond() const { return m_diskWriteRate; }
qint64 PerformanceController::storageUsedBytes() const { return m_storageUsedBytes; }
qint64 PerformanceController::storageTotalBytes() const { return m_storageTotalBytes; }
double PerformanceController::storageUsage() const { return m_storageUsage; }
QVariantList PerformanceController::diskReadHistory() const { return m_diskReadHistory; }
QVariantList PerformanceController::diskWriteHistory() const { return m_diskWriteHistory; }
QString PerformanceController::gpuName() const { return m_gpuName; }
double PerformanceController::gpuUsage() const { return m_gpuUsage; }
double PerformanceController::gpuTemperature() const { return m_gpuTemperature; }
qint64 PerformanceController::gpuMemoryUsedBytes() const { return m_gpuMemoryUsedBytes; }
qint64 PerformanceController::gpuMemoryTotalBytes() const { return m_gpuMemoryTotalBytes; }
QVariantList PerformanceController::gpus() const { return m_gpus; }
QVariantList PerformanceController::gpuHistory() const { return m_gpuHistory; }
qint64 PerformanceController::uptimeSeconds() const { return m_uptimeSeconds; }
double PerformanceController::loadAverage1() const { return m_load1; }
double PerformanceController::loadAverage5() const { return m_load5; }
double PerformanceController::loadAverage15() const { return m_load15; }
int PerformanceController::processCount() const { return m_processCount; }
QString PerformanceController::systemSummary() const { return m_systemSummary; }
QVariantList PerformanceController::topCpuProcesses() const { return m_topCpuProcesses; }
QVariantList PerformanceController::topMemoryProcesses() const { return m_topMemoryProcesses; }
QVariantList PerformanceController::processes() const { return m_processes; }
QString PerformanceController::processActionError() const { return m_processActionError; }

void PerformanceController::subscribe(const QString &clientId, const QStringList &modules)
{
    const QString id = clientId.trimmed();
    if (id.isEmpty()) {
        return;
    }
    QStringList normalized;
    for (const QString &module : modules) {
        const QString value = module.trimmed().toLower();
        if (!value.isEmpty() && !normalized.contains(value)) {
            normalized.push_back(value);
        }
    }
    if (normalized.isEmpty()) {
        normalized = {QStringLiteral("cpu"), QStringLiteral("memory"), QStringLiteral("system")};
    }

    const bool wasMonitoring = monitoring();
    m_clients.insert(id, normalized);
    rebuildActiveModules();
    if (!wasMonitoring) {
        m_rateClock.restart();
        m_refreshTimer.start();
        refreshNow();
    }
    Q_EMIT monitoringChanged();
}

void PerformanceController::unsubscribe(const QString &clientId)
{
    const bool wasMonitoring = monitoring();
    if (m_clients.remove(clientId.trimmed()) == 0) {
        return;
    }
    rebuildActiveModules();
    if (m_clients.isEmpty()) {
        m_refreshTimer.stop();
        m_rateClock.invalidate();
        m_lastNetworkRxBytes = 0;
        m_lastNetworkTxBytes = 0;
        m_haveNetworkSample = false;
        m_lastDiskReadBytes = 0;
        m_lastDiskWriteBytes = 0;
        m_haveDiskSample = false;
        m_lastProcessTicks.clear();
    }
    Q_UNUSED(wasMonitoring);
    Q_EMIT monitoringChanged();
}

void PerformanceController::rebuildActiveModules()
{
    QSet<QString> modules;
    for (auto it = m_clients.cbegin(); it != m_clients.cend(); ++it) {
        for (const QString &module : it.value()) {
            modules.insert(module);
        }
    }
    m_activeModules = modules;
}

bool PerformanceController::wantsModule(const QString &module) const
{
    return m_activeModules.contains(QStringLiteral("all")) || m_activeModules.contains(module);
}

void PerformanceController::refreshStaticSystemInfo()
{
    m_cpuModel = cpuModelName();
    m_logicalCores = std::max(1, QThread::idealThreadCount());
    const QString product = QSysInfo::prettyProductName().trimmed();
    const QString kernel = QSysInfo::kernelVersion().trimmed();
    m_systemSummary = product.isEmpty() ? kernel
                                        : (kernel.isEmpty() ? product : product + QStringLiteral(" · ") + kernel);
}

void PerformanceController::refreshNow()
{
    if (!m_available || m_activeModules.isEmpty()) {
        return;
    }

    double elapsedSeconds = 0;
    if (m_rateClock.isValid()) {
        elapsedSeconds = m_rateClock.elapsed() / 1000.0;
        m_rateClock.restart();
    } else {
        m_rateClock.start();
    }

    if (wantsModule(QStringLiteral("cpu")) || wantsModule(QStringLiteral("processes"))) {
        sampleCpu();
    }
    if (wantsModule(QStringLiteral("memory"))) {
        sampleMemory();
    }
    if (wantsModule(QStringLiteral("network"))) {
        sampleNetwork(elapsedSeconds);
    }
    if (wantsModule(QStringLiteral("disk"))) {
        sampleDisk(elapsedSeconds);
    }
    if (wantsModule(QStringLiteral("gpu"))) {
        sampleGpu();
    }
    if (wantsModule(QStringLiteral("system"))) {
        sampleSystem();
    }
    if (wantsModule(QStringLiteral("processes"))) {
        sampleProcesses();
    }
    Q_EMIT metricsChanged();
}

bool PerformanceController::terminateProcess(qint64 pid, bool force)
{
    if (pid <= 1 || pid == static_cast<qint64>(getpid())) {
        setProcessActionError(QStringLiteral("This process cannot be ended from Meo System Monitor."));
        return false;
    }

    const QString procPath = QStringLiteral("/proc/%1").arg(pid);
    if (!QFileInfo::exists(procPath)) {
        setProcessActionError(QStringLiteral("The process has already exited."));
        return false;
    }

    const int signal = force ? SIGKILL : SIGTERM;
    errno = 0;
    if (::kill(static_cast<pid_t>(pid), signal) != 0) {
        setProcessActionError(QStringLiteral("Could not end process %1: %2")
                                  .arg(pid)
                                  .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    setProcessActionError({});
    Q_EMIT processActionCompleted(pid, force ? QStringLiteral("force-stop")
                                              : QStringLiteral("terminate"));
    QTimer::singleShot(150, this, [this]() {
        if (wantsModule(QStringLiteral("processes"))) {
            refreshNow();
        }
    });
    return true;
}

bool PerformanceController::setProcessPriority(qint64 pid, int niceValue)
{
    if (pid <= 1 || pid == static_cast<qint64>(getpid())) {
        setProcessActionError(QStringLiteral("This process priority cannot be changed from Meo System Monitor."));
        return false;
    }

    const int bounded = qBound(-20, niceValue, 19);
    errno = 0;
    if (::setpriority(PRIO_PROCESS, static_cast<id_t>(pid), bounded) != 0) {
        setProcessActionError(QStringLiteral("Could not change priority for process %1: %2")
                                  .arg(pid)
                                  .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    setProcessActionError({});
    Q_EMIT processActionCompleted(pid, QStringLiteral("priority"));
    QTimer::singleShot(100, this, [this]() {
        if (wantsModule(QStringLiteral("processes"))) {
            refreshNow();
        }
    });
    return true;
}

void PerformanceController::clearProcessActionError()
{
    setProcessActionError({});
}

void PerformanceController::setProcessActionError(const QString &message)
{
    if (m_processActionError == message) {
        return;
    }
    m_processActionError = message;
    Q_EMIT processActionErrorChanged();
}

void PerformanceController::sampleCpu()
{
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/stat")).split('\n');
    if (lines.isEmpty()) {
        return;
    }

    auto parseSnapshot = [](const QList<QByteArray> &fields) {
        CpuSnapshot snapshot;
        for (int index = 1; index < fields.size(); ++index) {
            bool ok = false;
            const quint64 value = fields.at(index).toULongLong(&ok);
            if (!ok) {
                continue;
            }
            snapshot.total += value;
            if (index == 4 || index == 5) {
                snapshot.idle += value;
            }
        }
        return snapshot;
    };

    const QList<QByteArray> aggregateFields = lines.constFirst().simplified().split(' ');
    if (aggregateFields.size() < 5 || aggregateFields.constFirst() != "cpu") {
        return;
    }

    const CpuSnapshot current = parseSnapshot(aggregateFields);
    m_lastCpuTotalDelta = 0;
    if (m_lastCpu.total > 0 && current.total > m_lastCpu.total) {
        const quint64 totalDelta = current.total - m_lastCpu.total;
        const quint64 idleDelta = current.idle >= m_lastCpu.idle ? current.idle - m_lastCpu.idle : 0;
        m_lastCpuTotalDelta = totalDelta;
        if (totalDelta > 0) {
            m_cpuUsage = 100.0 * static_cast<double>(totalDelta - std::min(idleDelta, totalDelta))
                / static_cast<double>(totalDelta);
        }
    }
    m_lastCpu = current;

    QVariantList cores;
    static const QRegularExpression cpuLine(QStringLiteral("^cpu(\\d+)$"));
    for (const QByteArray &line : lines) {
        const QList<QByteArray> fields = line.simplified().split(' ');
        if (fields.size() < 5) {
            continue;
        }
        const QString label = QString::fromLatin1(fields.constFirst());
        const QRegularExpressionMatch match = cpuLine.match(label);
        if (!match.hasMatch()) {
            continue;
        }

        bool indexOk = false;
        const int coreIndex = match.captured(1).toInt(&indexOk);
        if (!indexOk) {
            continue;
        }

        const CpuSnapshot coreNow = parseSnapshot(fields);
        const CpuSnapshot previous = m_lastCoreCpu.value(coreIndex);
        double usage = 0;
        if (previous.total > 0 && coreNow.total > previous.total) {
            const quint64 totalDelta = coreNow.total - previous.total;
            const quint64 idleDelta = coreNow.idle >= previous.idle
                ? coreNow.idle - previous.idle : 0;
            if (totalDelta > 0) {
                usage = 100.0 * static_cast<double>(totalDelta - std::min(idleDelta, totalDelta))
                    / static_cast<double>(totalDelta);
            }
        }
        m_lastCoreCpu.insert(coreIndex, coreNow);

        QVariantList history = m_coreHistories.value(coreIndex);
        if (wantsModule(QStringLiteral("cpu"))) {
            appendHistory(history, usage);
            m_coreHistories.insert(coreIndex, history);
        }

        cores.push_back(QVariantMap{
            {QStringLiteral("index"), coreIndex},
            {QStringLiteral("label"), QStringLiteral("CPU %1").arg(coreIndex)},
            {QStringLiteral("usage"), usage},
            {QStringLiteral("frequencyMHz"), cpuFrequencyMHzForCore(coreIndex)},
            {QStringLiteral("history"), history},
        });
    }
    m_cpuCores = cores;

    m_cpuFrequencyMHz = currentCpuFrequencyMHz();
    m_cpuTemperature = cpuTemperature();
    if (wantsModule(QStringLiteral("cpu"))) {
        appendHistory(m_cpuHistory, m_cpuUsage);
    }
}

void PerformanceController::sampleMemory()
{
    QHash<QByteArray, quint64> values;
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/meminfo")).split('\n');
    for (const QByteArray &line : lines) {
        const int colon = line.indexOf(':');
        if (colon <= 0) {
            continue;
        }
        const QByteArray key = line.left(colon);
        const QList<QByteArray> fields = line.mid(colon + 1).simplified().split(' ');
        if (fields.isEmpty()) {
            continue;
        }
        bool ok = false;
        const quint64 kib = fields.constFirst().toULongLong(&ok);
        if (ok) {
            values.insert(key, kib);
        }
    }

    const quint64 totalKiB = values.value("MemTotal");
    const quint64 availableKiB = values.value("MemAvailable");
    const quint64 swapTotalKiB = values.value("SwapTotal");
    const quint64 swapFreeKiB = values.value("SwapFree");
    m_memoryTotalBytes = static_cast<qint64>(totalKiB * 1024ULL);
    m_memoryUsedBytes = static_cast<qint64>((totalKiB > availableKiB ? totalKiB - availableKiB : 0) * 1024ULL);
    m_swapTotalBytes = static_cast<qint64>(swapTotalKiB * 1024ULL);
    m_swapUsedBytes = static_cast<qint64>((swapTotalKiB > swapFreeKiB ? swapTotalKiB - swapFreeKiB : 0) * 1024ULL);
    m_memoryUsage = totalKiB > 0 ? 100.0 * static_cast<double>(totalKiB - std::min(totalKiB, availableKiB))
                                       / static_cast<double>(totalKiB)
                                 : 0;
    appendHistory(m_memoryHistory, m_memoryUsage);
}

void PerformanceController::sampleNetwork(double elapsedSeconds)
{
    quint64 rx = 0;
    quint64 tx = 0;
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/net/dev")).split('\n');
    for (const QByteArray &line : lines) {
        const int colon = line.indexOf(':');
        if (colon <= 0) {
            continue;
        }
        const QByteArray iface = line.left(colon).trimmed();
        if (iface == "lo") {
            continue;
        }
        const QList<QByteArray> fields = line.mid(colon + 1).simplified().split(' ');
        if (fields.size() < 9) {
            continue;
        }
        rx += fields.at(0).toULongLong();
        tx += fields.at(8).toULongLong();
    }

    if (elapsedSeconds > 0 && m_haveNetworkSample) {
        m_networkRxRate = rx >= m_lastNetworkRxBytes ? (rx - m_lastNetworkRxBytes) / elapsedSeconds : 0;
        m_networkTxRate = tx >= m_lastNetworkTxBytes ? (tx - m_lastNetworkTxBytes) / elapsedSeconds : 0;
    } else {
        m_networkRxRate = 0;
        m_networkTxRate = 0;
    }
    m_lastNetworkRxBytes = rx;
    m_lastNetworkTxBytes = tx;
    m_haveNetworkSample = true;
    appendHistory(m_networkRxHistory, m_networkRxRate);
    appendHistory(m_networkTxHistory, m_networkTxRate);
}

void PerformanceController::sampleDisk(double elapsedSeconds)
{
    quint64 readBytesTotal = 0;
    quint64 writeBytesTotal = 0;
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/diskstats")).split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> fields = line.simplified().split(' ');
        if (fields.size() < 10) {
            continue;
        }
        const QString device = QString::fromUtf8(fields.at(2));
        if (device.startsWith(QStringLiteral("loop"))
            || device.startsWith(QStringLiteral("ram"))
            || device.startsWith(QStringLiteral("zram"))
            || device.startsWith(QStringLiteral("fd"))
            || device.startsWith(QStringLiteral("sr"))
            || device.startsWith(QStringLiteral("dm-"))) {
            continue;
        }
        if (QFileInfo::exists(QStringLiteral("/sys/class/block/%1/partition").arg(device))) {
            continue;
        }
        readBytesTotal += fields.at(5).toULongLong() * 512ULL;
        writeBytesTotal += fields.at(9).toULongLong() * 512ULL;
    }

    if (elapsedSeconds > 0 && m_haveDiskSample) {
        m_diskReadRate = readBytesTotal >= m_lastDiskReadBytes
            ? (readBytesTotal - m_lastDiskReadBytes) / elapsedSeconds : 0;
        m_diskWriteRate = writeBytesTotal >= m_lastDiskWriteBytes
            ? (writeBytesTotal - m_lastDiskWriteBytes) / elapsedSeconds : 0;
    } else {
        m_diskReadRate = 0;
        m_diskWriteRate = 0;
    }
    m_lastDiskReadBytes = readBytesTotal;
    m_lastDiskWriteBytes = writeBytesTotal;
    m_haveDiskSample = true;

    QStorageInfo storage = QStorageInfo::root();
    storage.refresh();
    if (storage.isValid() && storage.isReady()) {
        m_storageTotalBytes = storage.bytesTotal();
        m_storageUsedBytes = std::max<qint64>(0, storage.bytesTotal() - storage.bytesAvailable());
        m_storageUsage = m_storageTotalBytes > 0
            ? 100.0 * static_cast<double>(m_storageUsedBytes) / static_cast<double>(m_storageTotalBytes)
            : 0;
    }
    appendHistory(m_diskReadHistory, m_diskReadRate);
    appendHistory(m_diskWriteHistory, m_diskWriteRate);
}

void PerformanceController::sampleGpu()
{
    QVariantList result;
    QDir drm(QStringLiteral("/sys/class/drm"));
    const QStringList cards = drm.entryList({QStringLiteral("card[0-9]*")},
                                             QDir::Dirs | QDir::NoDotAndDotDot,
                                             QDir::Name);
    for (const QString &card : cards) {
        const QString devicePath = drm.filePath(card + QStringLiteral("/device"));
        if (!QFileInfo::exists(devicePath)) {
            continue;
        }

        const QString vendor = readText(devicePath + QStringLiteral("/vendor"));
        const QString device = readText(devicePath + QStringLiteral("/device"));
        const QString driverPath = QFileInfo(devicePath + QStringLiteral("/driver")).canonicalFilePath();
        const QString driver = QFileInfo(driverPath).fileName();

        QVariantMap gpu;
        gpu.insert(QStringLiteral("id"), card);
        gpu.insert(QStringLiteral("name"), gpuVendorLabel(vendor));
        gpu.insert(QStringLiteral("vendorId"), vendor);
        gpu.insert(QStringLiteral("deviceId"), device);
        gpu.insert(QStringLiteral("driver"), driver);

        const qint64 busy = readInteger(devicePath + QStringLiteral("/gpu_busy_percent"));
        const double usage = busy >= 0 ? qBound<qint64>(0, busy, 100) : -1;
        gpu.insert(QStringLiteral("usage"), usage);
        QVariantList history = m_gpuHistories.value(card);
        if (usage >= 0) {
            appendHistory(history, usage);
            m_gpuHistories.insert(card, history);
        }
        gpu.insert(QStringLiteral("history"), history);
        const double temperature = gpuTemperatureAt(devicePath);
        gpu.insert(QStringLiteral("temperature"), temperature);

        const qint64 vramTotal = readInteger(devicePath + QStringLiteral("/mem_info_vram_total"), 0);
        const qint64 vramUsed = readInteger(devicePath + QStringLiteral("/mem_info_vram_used"), 0);
        gpu.insert(QStringLiteral("memoryTotalBytes"), std::max<qint64>(0, vramTotal));
        gpu.insert(QStringLiteral("memoryUsedBytes"), std::max<qint64>(0, vramUsed));
        result.push_back(gpu);
    }

    m_gpus = result;

    bool hasNvidia = false;
    for (const QVariant &entry : result) {
        if (entry.toMap().value(QStringLiteral("vendorId")).toString()
                .compare(QStringLiteral("0x10de"), Qt::CaseInsensitive) == 0) {
            hasNvidia = true;
            break;
        }
    }
    if (hasNvidia) {
        if (m_gpuName.isEmpty()) {
            for (const QVariant &entry : result) {
                const QVariantMap candidate = entry.toMap();
                if (candidate.value(QStringLiteral("vendorId")).toString()
                        .compare(QStringLiteral("0x10de"), Qt::CaseInsensitive) != 0) {
                    continue;
                }
                m_gpuName = candidate.value(QStringLiteral("name")).toString();
                const QString driver = candidate.value(QStringLiteral("driver")).toString();
                if (!driver.isEmpty()) {
                    m_gpuName += QStringLiteral(" · ") + driver;
                }
                m_gpuUsage = candidate.value(QStringLiteral("usage")).toDouble();
                m_gpuTemperature = candidate.value(QStringLiteral("temperature")).toDouble();
                m_gpuMemoryUsedBytes = candidate.value(QStringLiteral("memoryUsedBytes")).toLongLong();
                m_gpuMemoryTotalBytes = candidate.value(QStringLiteral("memoryTotalBytes")).toLongLong();
                break;
            }
        }
        startNvidiaGpuSample();
        return;
    }

    m_gpuName.clear();
    m_gpuUsage = -1;
    m_gpuTemperature = 0;
    m_gpuMemoryUsedBytes = 0;
    m_gpuMemoryTotalBytes = 0;

    if (!result.isEmpty()) {
        QVariantMap selected = result.constFirst().toMap();
        for (const QVariant &entry : result) {
            const QVariantMap candidate = entry.toMap();
            if (candidate.value(QStringLiteral("usage")).toDouble() >= 0
                || candidate.value(QStringLiteral("temperature")).toDouble() > 0) {
                selected = candidate;
                break;
            }
        }
        m_gpuName = selected.value(QStringLiteral("name")).toString();
        const QString driver = selected.value(QStringLiteral("driver")).toString();
        if (!driver.isEmpty()) {
            m_gpuName += QStringLiteral(" · ") + driver;
        }
        m_gpuUsage = selected.value(QStringLiteral("usage")).toDouble();
        m_gpuTemperature = selected.value(QStringLiteral("temperature")).toDouble();
        m_gpuMemoryUsedBytes = selected.value(QStringLiteral("memoryUsedBytes")).toLongLong();
        m_gpuMemoryTotalBytes = selected.value(QStringLiteral("memoryTotalBytes")).toLongLong();
    }
    if (m_gpuUsage >= 0) {
        appendHistory(m_gpuHistory, m_gpuUsage);
    }
}

void PerformanceController::startNvidiaGpuSample()
{
    if (m_nvidiaQuerying || m_nvidiaSmiUnavailable) {
        return;
    }
    if (QStandardPaths::findExecutable(QStringLiteral("nvidia-smi")).isEmpty()) {
        m_nvidiaSmiUnavailable = true;
        return;
    }

    auto *process = new QProcess(this);
    m_nvidiaQuerying = true;
    process->setProgram(QStringLiteral("nvidia-smi"));
    process->setArguments({
        QStringLiteral("--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total"),
        QStringLiteral("--format=csv,noheader,nounits"),
    });
    process->setStandardErrorFile(QProcess::nullDevice());

    const auto finish = [this, process](bool parseOutput) {
        if (parseOutput && wantsModule(QStringLiteral("gpu"))) {
            QVariantList updated = m_gpus;
            const QList<QByteArray> rows = process->readAllStandardOutput().split('\n');
            int nvidiaIndex = 0;
            bool primaryUpdated = false;
            for (const QByteArray &row : rows) {
                if (row.trimmed().isEmpty()) {
                    continue;
                }
                const QList<QByteArray> fields = row.split(',');
                if (fields.size() < 5) {
                    continue;
                }

                bool usageOk = false;
                bool temperatureOk = false;
                bool usedOk = false;
                bool totalOk = false;
                const double usage = fields.at(1).trimmed().toDouble(&usageOk);
                const double temperature = fields.at(2).trimmed().toDouble(&temperatureOk);
                const double memoryUsedMiB = fields.at(3).trimmed().toDouble(&usedOk);
                const double memoryTotalMiB = fields.at(4).trimmed().toDouble(&totalOk);

                QVariantMap gpu;
                int listIndex = -1;
                for (int index = nvidiaIndex; index < updated.size(); ++index) {
                    const QVariantMap candidate = updated.at(index).toMap();
                    if (candidate.value(QStringLiteral("vendorId")).toString()
                            .compare(QStringLiteral("0x10de"), Qt::CaseInsensitive) == 0) {
                        gpu = candidate;
                        listIndex = index;
                        nvidiaIndex = index + 1;
                        break;
                    }
                }

                const QString name = QString::fromUtf8(fields.at(0)).trimmed();
                if (!name.isEmpty()) {
                    gpu.insert(QStringLiteral("name"), name);
                }
                gpu.insert(QStringLiteral("usage"), usageOk ? std::clamp(usage, 0.0, 100.0) : -1.0);
                gpu.insert(QStringLiteral("temperature"), temperatureOk ? temperature : 0.0);
                gpu.insert(QStringLiteral("memoryUsedBytes"),
                           usedOk ? static_cast<qint64>(memoryUsedMiB * 1024.0 * 1024.0) : 0);
                gpu.insert(QStringLiteral("memoryTotalBytes"),
                           totalOk ? static_cast<qint64>(memoryTotalMiB * 1024.0 * 1024.0) : 0);

                if (listIndex < 0) {
                    gpu.insert(QStringLiteral("id"), QStringLiteral("nvidia-%1").arg(nvidiaIndex++));
                    gpu.insert(QStringLiteral("vendorId"), QStringLiteral("0x10de"));
                    gpu.insert(QStringLiteral("driver"), QStringLiteral("nvidia"));
                }

                const QString gpuId = gpu.value(QStringLiteral("id")).toString();
                QVariantList history = m_gpuHistories.value(gpuId);
                if (usageOk) {
                    appendHistory(history, std::clamp(usage, 0.0, 100.0));
                    m_gpuHistories.insert(gpuId, history);
                }
                gpu.insert(QStringLiteral("history"), history);

                if (listIndex >= 0) {
                    updated[listIndex] = gpu;
                } else {
                    updated.push_back(gpu);
                }

                if (!primaryUpdated) {
                    primaryUpdated = true;
                    m_gpuName = gpu.value(QStringLiteral("name")).toString();
                    m_gpuUsage = gpu.value(QStringLiteral("usage")).toDouble();
                    m_gpuTemperature = gpu.value(QStringLiteral("temperature")).toDouble();
                    m_gpuMemoryUsedBytes = gpu.value(QStringLiteral("memoryUsedBytes")).toLongLong();
                    m_gpuMemoryTotalBytes = gpu.value(QStringLiteral("memoryTotalBytes")).toLongLong();
                }
            }

            m_gpus = updated;
            if (m_gpuUsage >= 0) {
                appendHistory(m_gpuHistory, m_gpuUsage);
            }
            Q_EMIT metricsChanged();
        }

        m_nvidiaQuerying = false;
        process->deleteLater();
    };

    connect(process, &QProcess::finished, this,
            [finish](int exitCode, QProcess::ExitStatus status) {
                finish(status == QProcess::NormalExit && exitCode == 0);
            });
    connect(process, &QProcess::errorOccurred, this,
            [finish](QProcess::ProcessError error) {
                if (error == QProcess::FailedToStart) {
                    finish(false);
                }
            });
    process->start();
}

void PerformanceController::sampleSystem()
{
    const QList<QByteArray> uptimeFields = readBytes(QStringLiteral("/proc/uptime")).simplified().split(' ');
    if (!uptimeFields.isEmpty()) {
        bool ok = false;
        const double uptime = uptimeFields.constFirst().toDouble(&ok);
        if (ok) {
            m_uptimeSeconds = static_cast<qint64>(uptime);
        }
    }

    const QList<QByteArray> loadFields = readBytes(QStringLiteral("/proc/loadavg")).simplified().split(' ');
    if (loadFields.size() >= 3) {
        m_load1 = loadFields.at(0).toDouble();
        m_load5 = loadFields.at(1).toDouble();
        m_load15 = loadFields.at(2).toDouble();
    }

    int processCount = 0;
    QDir proc(QStringLiteral("/proc"));
    const QStringList entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    static const QRegularExpression digits(QStringLiteral("^\\d+$"));
    for (const QString &entry : entries) {
        if (digits.match(entry).hasMatch()) {
            ++processCount;
        }
    }
    m_processCount = processCount;
}

void PerformanceController::sampleProcesses()
{
    struct Sample {
        qint64 pid = 0;
        qint64 parentPid = 0;
        QString name;
        QString command;
        QString user;
        QString state;
        qint64 uid = -1;
        int threads = 0;
        int niceValue = 0;
        double cpu = 0;
        qint64 memory = 0;
        bool canControl = false;
    };

    QVector<Sample> samples;
    QHash<qint64, quint64> nextTicks;
    QHash<qint64, QString> userNames;
    const qint64 pageSize = std::max<qint64>(1, sysconf(_SC_PAGESIZE));
    const uid_t currentUid = geteuid();
    QDir proc(QStringLiteral("/proc"));
    const QStringList entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    static const QRegularExpression digits(QStringLiteral("^\\d+$"));

    for (const QString &entry : entries) {
        if (!digits.match(entry).hasMatch()) {
            continue;
        }
        bool pidOk = false;
        const qint64 pid = entry.toLongLong(&pidOk);
        if (!pidOk) {
            continue;
        }

        const QString basePath = proc.filePath(entry);
        const QByteArray stat = readBytes(basePath + QStringLiteral("/stat")).trimmed();
        const int openParen = stat.indexOf('(');
        const int closeParen = stat.lastIndexOf(')');
        if (openParen < 0 || closeParen <= openParen) {
            continue;
        }
        const QString name = QString::fromUtf8(stat.mid(openParen + 1, closeParen - openParen - 1));
        const QList<QByteArray> fields = stat.mid(closeParen + 2).simplified().split(' ');
        if (fields.size() < 22) {
            continue;
        }

        bool parentOk = false;
        const qint64 parentPid = fields.at(1).toLongLong(&parentOk);
        const quint64 ticks = fields.at(11).toULongLong() + fields.at(12).toULongLong();
        nextTicks.insert(pid, ticks);
        double cpu = 0;
        const quint64 previous = m_lastProcessTicks.value(pid);
        if (previous > 0 && ticks >= previous && m_lastCpuTotalDelta > 0) {
            cpu = static_cast<double>(ticks - previous) * m_logicalCores * 100.0
                / static_cast<double>(m_lastCpuTotalDelta);
            cpu = std::clamp(cpu, 0.0, m_logicalCores * 100.0);
        }

        qint64 rssBytes = 0;
        const QList<QByteArray> statm = readBytes(basePath + QStringLiteral("/statm")).simplified().split(' ');
        if (statm.size() >= 2) {
            rssBytes = static_cast<qint64>(statm.at(1).toULongLong()) * pageSize;
        }

        qint64 uid = -1;
        const QList<QByteArray> statusLines = readBytes(basePath + QStringLiteral("/status")).split('\n');
        for (const QByteArray &line : statusLines) {
            if (!line.startsWith("Uid:")) {
                continue;
            }
            const QList<QByteArray> uidFields = line.mid(4).simplified().split(' ');
            if (!uidFields.isEmpty()) {
                bool uidOk = false;
                const qint64 parsedUid = uidFields.constFirst().toLongLong(&uidOk);
                if (uidOk) {
                    uid = parsedUid;
                }
            }
            break;
        }

        QString user = uid >= 0 ? QString::number(uid) : QStringLiteral("?");
        if (uid >= 0) {
            const auto cached = userNames.constFind(uid);
            if (cached != userNames.cend()) {
                user = cached.value();
            } else {
                if (const struct passwd *account = getpwuid(static_cast<uid_t>(uid))) {
                    user = QString::fromLocal8Bit(account->pw_name);
                }
                userNames.insert(uid, user);
            }
        }

        QByteArray rawCommand = readBytes(basePath + QStringLiteral("/cmdline"));
        std::replace(rawCommand.begin(), rawCommand.end(), '\0', ' ');
        QString command = QString::fromUtf8(rawCommand).simplified();
        if (command.isEmpty()) {
            command = name;
        }

        bool niceOk = false;
        const int niceValue = fields.at(16).toInt(&niceOk);
        bool threadsOk = false;
        const int threads = fields.at(17).toInt(&threadsOk);
        const QString state = QString::fromLatin1(fields.at(0));
        const bool canControl = pid > 1
            && pid != static_cast<qint64>(getpid())
            && uid >= 0
            && (currentUid == 0 || static_cast<uid_t>(uid) == currentUid);

        samples.push_back(Sample{
            pid,
            parentOk ? parentPid : 0,
            name,
            command,
            user,
            state,
            uid,
            threadsOk ? std::max(0, threads) : 0,
            niceOk ? niceValue : 0,
            cpu,
            std::max<qint64>(0, rssBytes),
            canControl,
        });
    }

    m_lastProcessTicks = nextTicks;
    m_processCount = samples.size();

    QVector<Sample> cpuSorted = samples;
    std::sort(cpuSorted.begin(), cpuSorted.end(), [](const Sample &left, const Sample &right) {
        if (!qFuzzyCompare(left.cpu + 1.0, right.cpu + 1.0)) {
            return left.cpu > right.cpu;
        }
        return left.memory > right.memory;
    });

    QVector<Sample> memorySorted = samples;
    std::sort(memorySorted.begin(), memorySorted.end(), [](const Sample &left, const Sample &right) {
        if (left.memory != right.memory) {
            return left.memory > right.memory;
        }
        return left.cpu > right.cpu;
    });

    auto toMaps = [](const QVector<Sample> &source) {
        QVector<QVariantMap> maps;
        maps.reserve(source.size());
        for (const Sample &sample : source) {
            maps.push_back(QVariantMap{
                {QStringLiteral("pid"), sample.pid},
                {QStringLiteral("parentPid"), sample.parentPid},
                {QStringLiteral("name"), sample.name},
                {QStringLiteral("command"), sample.command},
                {QStringLiteral("user"), sample.user},
                {QStringLiteral("uid"), sample.uid},
                {QStringLiteral("state"), sample.state},
                {QStringLiteral("threads"), sample.threads},
                {QStringLiteral("nice"), sample.niceValue},
                {QStringLiteral("cpu"), sample.cpu},
                {QStringLiteral("memoryBytes"), sample.memory},
                {QStringLiteral("canControl"), sample.canControl},
            });
        }
        return maps;
    };

    const QVector<QVariantMap> cpuMaps = toMaps(cpuSorted);
    m_processes.clear();
    m_processes.reserve(cpuMaps.size());
    for (const QVariantMap &process : cpuMaps) {
        m_processes.push_back(process);
    }
    m_topCpuProcesses = takeProcesses(cpuMaps, 10);
    m_topMemoryProcesses = takeProcesses(toMaps(memorySorted), 10);
}

void PerformanceController::appendHistory(QVariantList &history, double value)
{
    if (!std::isfinite(value)) {
        return;
    }
    history.push_back(value);
    while (history.size() > kHistoryLimit) {
        history.removeFirst();
    }
}
