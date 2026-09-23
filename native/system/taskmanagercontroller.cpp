#include "taskmanagercontroller.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantMap>
#include <QtGlobal>

#include <algorithm>
#include <cerrno>
#include <csignal>
#include <cmath>
#include <cstring>
#include <functional>
#include <pwd.h>
#include <sched.h>
#include <sys/resource.h>
#include <unistd.h>

namespace
{
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

struct RawCpuSnapshot {
    quint64 idle = 0;
    quint64 total = 0;
};

RawCpuSnapshot readCpuSnapshot()
{
    RawCpuSnapshot snapshot;
    const QList<QByteArray> lines = readBytes(QStringLiteral("/proc/stat")).split('\n');
    if (lines.isEmpty()) {
        return snapshot;
    }
    const QList<QByteArray> fields = lines.constFirst().simplified().split(' ');
    if (fields.size() < 5 || fields.constFirst() != "cpu") {
        return snapshot;
    }
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
}

QString desktopEntryValue(const QByteArray &content, const QByteArray &key)
{
    bool inDesktopEntry = false;
    const QList<QByteArray> lines = content.split('\n');
    for (QByteArray line : lines) {
        line = line.trimmed();
        if (line.startsWith('[') && line.endsWith(']')) {
            inDesktopEntry = line == "[Desktop Entry]";
            continue;
        }
        if (!inDesktopEntry || line.startsWith('#')) {
            continue;
        }
        const int equals = line.indexOf('=');
        if (equals <= 0) {
            continue;
        }
        if (line.left(equals).trimmed() == key) {
            return QString::fromUtf8(line.mid(equals + 1)).trimmed();
        }
    }
    return {};
}

QByteArray setDesktopEntryKey(QByteArray content, const QByteArray &key, const QByteArray &value)
{
    QList<QByteArray> lines = content.split('\n');
    bool inDesktopEntry = false;
    bool desktopEntryFound = false;
    bool replaced = false;
    int insertIndex = -1;

    for (int index = 0; index < lines.size(); ++index) {
        const QByteArray trimmed = lines.at(index).trimmed();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            if (inDesktopEntry && insertIndex < 0) {
                insertIndex = index;
            }
            inDesktopEntry = trimmed == "[Desktop Entry]";
            desktopEntryFound = desktopEntryFound || inDesktopEntry;
            continue;
        }
        if (!inDesktopEntry) {
            continue;
        }
        const int equals = trimmed.indexOf('=');
        if (equals > 0 && trimmed.left(equals).trimmed() == key) {
            lines[index] = key + '=' + value;
            replaced = true;
            break;
        }
    }

    if (!desktopEntryFound) {
        if (!content.isEmpty() && !content.endsWith('\n')) {
            content += '\n';
        }
        content += "[Desktop Entry]\n" + key + '=' + value + '\n';
        return content;
    }

    if (!replaced) {
        if (insertIndex < 0) {
            insertIndex = lines.size();
        }
        lines.insert(insertIndex, key + '=' + value);
    }
    return lines.join('\n');
}

bool writeFileAtomically(const QString &path, const QByteArray &content)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    if (file.write(content) != content.size()) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
}

QPair<quint64, quint64> readProcessIo(const QString &basePath)
{
    quint64 readBytesValue = 0;
    quint64 writeBytesValue = 0;
    const QList<QByteArray> lines = readBytes(basePath + QStringLiteral("/io")).split('\n');
    for (const QByteArray &line : lines) {
        if (line.startsWith("read_bytes:")) {
            readBytesValue = line.mid(sizeof("read_bytes:") - 1).trimmed().toULongLong();
        } else if (line.startsWith("write_bytes:")) {
            writeBytesValue = line.mid(sizeof("write_bytes:") - 1).trimmed().toULongLong();
        }
    }
    return {readBytesValue, writeBytesValue};
}

quint64 scaledDrmValue(const QByteArray &valueField)
{
    const QList<QByteArray> parts = valueField.simplified().split(' ');
    if (parts.isEmpty()) {
        return 0;
    }
    bool ok = false;
    double value = parts.constFirst().toDouble(&ok);
    if (!ok) {
        return 0;
    }
    if (parts.size() > 1) {
        const QByteArray unit = parts.at(1).toLower();
        if (unit == "kib" || unit == "kb") value *= 1024.0;
        else if (unit == "mib" || unit == "mb") value *= 1024.0 * 1024.0;
        else if (unit == "gib" || unit == "gb") value *= 1024.0 * 1024.0 * 1024.0;
    }
    return static_cast<quint64>(std::max(0.0, value));
}

QPair<quint64, quint64> readProcessDrmStats(qint64 pid)
{
    QHash<QByteArray, quint64> engineTotals;
    quint64 vramBytes = 0;
    QSet<QByteArray> seenClients;
    QDir fdinfo(QStringLiteral("/proc/%1/fdinfo").arg(pid));
    const QStringList entries = fdinfo.entryList(QDir::Files, QDir::Name);
    for (const QString &entry : entries) {
        const QByteArray content = readBytes(fdinfo.filePath(entry));
        if (!content.contains("drm-")) {
            continue;
        }

        QByteArray clientId;
        const QList<QByteArray> lines = content.split('\n');
        for (const QByteArray &line : lines) {
            if (line.startsWith("drm-client-id:")) {
                clientId = line.mid(sizeof("drm-client-id:") - 1).trimmed();
                break;
            }
        }
        if (!clientId.isEmpty() && seenClients.contains(clientId)) {
            continue;
        }
        if (!clientId.isEmpty()) {
            seenClients.insert(clientId);
        }

        for (const QByteArray &line : lines) {
            const int colon = line.indexOf(':');
            if (colon <= 0) {
                continue;
            }
            const QByteArray key = line.left(colon).trimmed();
            const QByteArray value = line.mid(colon + 1).trimmed();
            if (key.startsWith("drm-engine-")) {
                engineTotals[key] = engineTotals.value(key) + scaledDrmValue(value);
            } else if (key == "drm-memory-vram" || key == "drm-memory-gtt") {
                vramBytes += scaledDrmValue(value);
            }
        }
    }
    quint64 busiestEngineNanoseconds = 0;
    for (auto it = engineTotals.cbegin(); it != engineTotals.cend(); ++it) {
        busiestEngineNanoseconds = std::max(busiestEngineNanoseconds, it.value());
    }
    return {busiestEngineNanoseconds, vramBytes};
}

QSet<quint64> socketInodesForPid(qint64 pid)
{
    QSet<quint64> inodes;
    QDir fd(QStringLiteral("/proc/%1/fd").arg(pid));
    const QStringList entries =
        fd.entryList(QDir::Files | QDir::System | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &entry : entries) {
        const QString target = QFileInfo(fd.filePath(entry)).symLinkTarget();
        if (!target.startsWith(QStringLiteral("socket:["))
            || !target.endsWith(QLatin1Char(']'))) {
            continue;
        }
        bool ok = false;
        const quint64 inode =
            target.mid(8, target.size() - 9).toULongLong(&ok);
        if (ok) {
            inodes.insert(inode);
        }
    }
    return inodes;
}

QVariantMap socketProtocolSummary(qint64 pid)
{
    const QSet<quint64> inodes = socketInodesForPid(pid);
    QVariantMap summary{
        {QStringLiteral("total"), inodes.size()},
        {QStringLiteral("tcp"), 0},
        {QStringLiteral("tcpEstablished"), 0},
        {QStringLiteral("tcpListen"), 0},
        {QStringLiteral("udp"), 0},
    };
    if (inodes.isEmpty()) {
        return summary;
    }

    auto scan = [&](const QString &path, bool tcp) {
        const QList<QByteArray> lines = readBytes(path).split('\n');
        for (int lineIndex = 1; lineIndex < lines.size(); ++lineIndex) {
            const QList<QByteArray> fields = lines.at(lineIndex).simplified().split(' ');
            if (fields.size() < 10) {
                continue;
            }
            bool inodeOk = false;
            const quint64 inode = fields.at(9).toULongLong(&inodeOk);
            if (!inodeOk || !inodes.contains(inode)) {
                continue;
            }

            if (tcp) {
                summary[QStringLiteral("tcp")] =
                    summary.value(QStringLiteral("tcp")).toInt() + 1;
                const QByteArray state = fields.at(3);
                if (state == "01") {
                    summary[QStringLiteral("tcpEstablished")] =
                        summary.value(QStringLiteral("tcpEstablished")).toInt() + 1;
                } else if (state == "0A") {
                    summary[QStringLiteral("tcpListen")] =
                        summary.value(QStringLiteral("tcpListen")).toInt() + 1;
                }
            } else {
                summary[QStringLiteral("udp")] =
                    summary.value(QStringLiteral("udp")).toInt() + 1;
            }
        }
    };

    scan(QStringLiteral("/proc/net/tcp"), true);
    scan(QStringLiteral("/proc/net/tcp6"), true);
    scan(QStringLiteral("/proc/net/udp"), false);
    scan(QStringLiteral("/proc/net/udp6"), false);
    return summary;
}

QString usernameForUid(qint64 uid, QHash<qint64, QString> &cache)
{
    if (uid < 0) {
        return QStringLiteral("?");
    }
    const auto cached = cache.constFind(uid);
    if (cached != cache.cend()) {
        return cached.value();
    }
    QString value = QString::number(uid);
    if (const struct passwd *account = getpwuid(static_cast<uid_t>(uid))) {
        value = QString::fromLocal8Bit(account->pw_name);
    }
    cache.insert(uid, value);
    return value;
}

bool safeUnitName(const QString &unit)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9_.@:+-]+\\.service$"));
    return pattern.match(unit).hasMatch();
}

qint64 processUid(qint64 pid)
{
    const QList<QByteArray> lines =
        readBytes(QStringLiteral("/proc/%1/status").arg(pid)).split('\n');
    for (const QByteArray &line : lines) {
        if (!line.startsWith("Uid:")) {
            continue;
        }
        const QList<QByteArray> fields = line.mid(4).simplified().split(' ');
        if (fields.isEmpty()) {
            return -1;
        }
        bool ok = false;
        const qint64 uid = fields.constFirst().toLongLong(&ok);
        return ok ? uid : -1;
    }
    return -1;
}

bool processOwnedByCurrentUser(qint64 pid)
{
    const qint64 uid = processUid(pid);
    return uid >= 0 && static_cast<uid_t>(uid) == geteuid();
}

QVariantList processAffinity(qint64 pid)
{
    QVariantList result;
    cpu_set_t set;
    CPU_ZERO(&set);
    if (::sched_getaffinity(static_cast<pid_t>(pid), sizeof(set), &set) != 0) {
        return result;
    }
    for (int cpu = 0; cpu < CPU_SETSIZE; ++cpu) {
        if (CPU_ISSET(cpu, &set)) {
            result.push_back(cpu);
        }
    }
    return result;
}

int openFileDescriptorCount(qint64 pid)
{
    QDir directory(QStringLiteral("/proc/%1/fd").arg(pid));
    return directory.entryList(QDir::Files | QDir::System | QDir::NoDotAndDotDot).size();
}
}

TaskManagerController::TaskManagerController(QObject *parent)
    : QObject(parent)
{
    m_available = QFileInfo::exists(QStringLiteral("/proc/stat"))
        && QFileInfo::exists(QStringLiteral("/proc/meminfo"));
    m_refreshTimer.setInterval(m_refreshInterval);
    connect(&m_refreshTimer, &QTimer::timeout, this, [this]() {
        if (!wantsProcessSampling()) {
            return;
        }
        double elapsedSeconds = 0;
        if (m_rateClock.isValid()) {
            elapsedSeconds = m_rateClock.elapsed() / 1000.0;
            m_rateClock.restart();
        } else {
            m_rateClock.start();
        }
        sampleProcesses(elapsedSeconds);
        Q_EMIT dataChanged();
    });
    rebuildDesktopAppIndex();
}

bool TaskManagerController::available() const { return m_available; }
bool TaskManagerController::monitoring() const { return !m_clients.isEmpty(); }

QStringList TaskManagerController::activeModules() const
{
    QStringList result = m_activeModules.values();
    result.sort();
    return result;
}

int TaskManagerController::refreshInterval() const { return m_refreshInterval; }
bool TaskManagerController::paused() const { return m_paused; }

void TaskManagerController::setPaused(bool paused)
{
    if (m_paused == paused) {
        return;
    }
    m_paused = paused;
    m_rateClock.invalidate();
    updateTimer();
    if (!m_paused && wantsProcessSampling()) {
        refreshNow();
    }
    Q_EMIT pausedChanged();
}

void TaskManagerController::setRefreshInterval(int interval)
{
    const int bounded = qBound(500, interval, 10000);
    if (bounded == m_refreshInterval) {
        return;
    }
    m_refreshInterval = bounded;
    m_refreshTimer.setInterval(m_refreshInterval);
    Q_EMIT refreshIntervalChanged();
}

QVariantList TaskManagerController::processes() const { return m_processes; }
QVariantList TaskManagerController::processTree() const { return m_processTree; }
QVariantList TaskManagerController::processGroups() const { return m_processGroups; }
QVariantList TaskManagerController::userSummaries() const { return m_userSummaries; }
QVariantMap TaskManagerController::selectedProcessDetails() const { return m_selectedProcessDetails; }
qint64 TaskManagerController::selectedPid() const { return m_selectedPid; }
bool TaskManagerController::processNetworkThroughputAvailable() const { return false; }
bool TaskManagerController::selectedProcessGpuAvailable() const { return m_selectedProcessGpuAvailable; }
QVariantList TaskManagerController::startupApps() const { return m_startupApps; }
QVariantList TaskManagerController::services() const { return m_services; }
bool TaskManagerController::servicesAvailable() const { return m_servicesAvailable; }
bool TaskManagerController::serviceQuerying() const { return m_serviceQuerying; }
QString TaskManagerController::actionError() const { return m_actionError; }

void TaskManagerController::subscribe(const QString &clientId, const QStringList &modules)
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
        normalized = {QStringLiteral("processes")};
    }

    const bool wasMonitoring = monitoring();
    m_clients.insert(id, normalized);
    rebuildActiveModules();

    if (wantsModule(QStringLiteral("startup"))) {
        refreshStartupApps();
    }
    if (wantsModule(QStringLiteral("services"))) {
        refreshServices();
    }
    if (wantsProcessSampling()) {
        m_rateClock.restart();
        sampleProcesses(0);
        Q_EMIT dataChanged();
    }
    updateTimer();

    if (wasMonitoring != monitoring()) {
        Q_EMIT monitoringChanged();
    } else {
        Q_EMIT monitoringChanged();
    }
}

void TaskManagerController::unsubscribe(const QString &clientId)
{
    if (m_clients.remove(clientId.trimmed()) == 0) {
        return;
    }
    rebuildActiveModules();
    updateTimer();
    if (!wantsProcessSampling()) {
        m_rateClock.invalidate();
        m_lastCpu = {};
        m_lastCpuTotalDelta = 0;
        m_lastProcessTicks.clear();
        m_lastProcessReadBytes.clear();
        m_lastProcessWriteBytes.clear();
    }
    Q_EMIT monitoringChanged();
}

void TaskManagerController::rebuildActiveModules()
{
    QSet<QString> modules;
    for (auto it = m_clients.cbegin(); it != m_clients.cend(); ++it) {
        for (const QString &module : it.value()) {
            modules.insert(module);
        }
    }
    m_activeModules = modules;
}

bool TaskManagerController::wantsModule(const QString &module) const
{
    return m_activeModules.contains(QStringLiteral("all")) || m_activeModules.contains(module);
}

bool TaskManagerController::wantsProcessSampling() const
{
    return wantsModule(QStringLiteral("processes"))
        || wantsModule(QStringLiteral("details"))
        || wantsModule(QStringLiteral("users"));
}

void TaskManagerController::updateTimer()
{
    if (wantsProcessSampling() && !m_paused) {
        if (!m_refreshTimer.isActive()) {
            m_refreshTimer.start();
        }
    } else {
        m_refreshTimer.stop();
    }
}

void TaskManagerController::refreshNow()
{
    if (!m_available) {
        return;
    }

    if (wantsProcessSampling()) {
        double elapsedSeconds = 0;
        if (m_rateClock.isValid()) {
            elapsedSeconds = m_rateClock.elapsed() / 1000.0;
            m_rateClock.restart();
        } else {
            m_rateClock.start();
        }
        sampleProcesses(elapsedSeconds);
        Q_EMIT dataChanged();
    }
    if (wantsModule(QStringLiteral("startup"))) {
        refreshStartupApps();
    }
    if (wantsModule(QStringLiteral("services"))) {
        refreshServices();
    }
}

void TaskManagerController::selectProcess(qint64 pid)
{
    if (m_selectedPid == pid) {
        return;
    }
    m_selectedPid = pid > 0 ? pid : -1;
    m_lastSelectedGpuPid = -1;
    m_lastSelectedGpuEngineNs = 0;
    m_selectedProcessGpuAvailable = false;
    updateSelectedProcessDetails(0);
    Q_EMIT selectedProcessDetailsChanged();
}

void TaskManagerController::rebuildDesktopAppIndex()
{
    m_desktopAppsByExecutable.clear();
    const QStringList roots = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const QString &root : roots) {
        QDirIterator it(root, {QStringLiteral("*.desktop")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            const QByteArray content = readBytes(path);
            if (content.isEmpty()
                || desktopEntryValue(content, "Type") != QStringLiteral("Application")
                || desktopEntryValue(content, "Hidden").compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0) {
                continue;
            }

            const QString execLine = desktopEntryValue(content, "Exec");
            if (execLine.isEmpty()) {
                continue;
            }
            QStringList command = QProcess::splitCommand(execLine);
            while (!command.isEmpty() && command.constFirst().contains('=')
                   && !command.constFirst().startsWith('/')) {
                command.removeFirst();
            }
            if (!command.isEmpty()
                && QFileInfo(command.constFirst()).fileName() == QStringLiteral("env")) {
                command.removeFirst();
                while (!command.isEmpty() && command.constFirst().contains('=')) {
                    command.removeFirst();
                }
            }
            if (command.isEmpty()) {
                continue;
            }

            QString executable = command.constFirst();
            if (executable.startsWith('%')) {
                continue;
            }
            executable = QFileInfo(executable).fileName();
            if (executable.isEmpty()) {
                continue;
            }

            DesktopAppInfo info;
            info.name = desktopEntryValue(content, "Name");
            info.icon = desktopEntryValue(content, "Icon");
            info.desktopId = QFileInfo(path).fileName();
            if (info.name.isEmpty()) {
                info.name = QFileInfo(path).completeBaseName();
            }
            if (!m_desktopAppsByExecutable.contains(executable)) {
                m_desktopAppsByExecutable.insert(executable, info);
            }
        }
    }
}

void TaskManagerController::sampleProcesses(double elapsedSeconds)
{
    struct Sample {
        qint64 pid = 0;
        qint64 parentPid = 0;
        QString name;
        QString appName;
        QString appIcon;
        QString desktopId;
        QString command;
        QString executable;
        QString user;
        QString state;
        QString category;
        qint64 uid = -1;
        int threads = 0;
        int niceValue = 0;
        int treeDepth = 0;
        double cpu = 0;
        qint64 memory = 0;
        double diskReadRate = 0;
        double diskWriteRate = 0;
        bool canControl = false;
        bool efficiency = false;
    };

    const RawCpuSnapshot currentCpu = readCpuSnapshot();
    m_lastCpuTotalDelta = 0;
    if (m_lastCpu.total > 0 && currentCpu.total > m_lastCpu.total) {
        m_lastCpuTotalDelta = currentCpu.total - m_lastCpu.total;
    }
    m_lastCpu.idle = currentCpu.idle;
    m_lastCpu.total = currentCpu.total;

    QVector<Sample> samples;
    QHash<qint64, quint64> nextTicks;
    QHash<qint64, quint64> nextReadBytes;
    QHash<qint64, quint64> nextWriteBytes;
    QHash<qint64, QString> userNames;
    QSet<qint64> livePids;
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
        const quint64 previousTicks = m_lastProcessTicks.value(pid);
        if (previousTicks > 0 && ticks >= previousTicks && m_lastCpuTotalDelta > 0) {
            cpu = static_cast<double>(ticks - previousTicks) * 100.0
                / static_cast<double>(m_lastCpuTotalDelta);
            cpu = std::clamp(cpu, 0.0, 100.0);
        }

        qint64 rssBytes = 0;
        const QList<QByteArray> statm = readBytes(basePath + QStringLiteral("/statm")).simplified().split(' ');
        if (statm.size() >= 2) {
            rssBytes = static_cast<qint64>(statm.at(1).toULongLong()) * pageSize;
        }

        const quint64 startTicks = fields.at(19).toULongLong();
        livePids.insert(pid);
        ProcessStaticInfo staticInfo = m_processStaticInfo.value(pid);
        if (staticInfo.startTicks != startTicks || staticInfo.command.isEmpty()) {
            qint64 uid = -1;
            const QList<QByteArray> statusLines =
                readBytes(basePath + QStringLiteral("/status")).split('\n');
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

            QByteArray rawCommand = readBytes(basePath + QStringLiteral("/cmdline"));
            std::replace(rawCommand.begin(), rawCommand.end(), '\0', ' ');
            QString command = QString::fromUtf8(rawCommand).simplified();
            if (command.isEmpty()) {
                command = name;
            }

            QString executablePath =
                QFileInfo(basePath + QStringLiteral("/exe")).symLinkTarget();
            QString executable = QFileInfo(executablePath).fileName();
            if (executable.isEmpty()) {
                executable = name;
            }

            const DesktopAppInfo appInfo = m_desktopAppsByExecutable.value(executable);
            const bool isCurrentUser =
                uid >= 0 && static_cast<uid_t>(uid) == currentUid;
            QString category;
            if (!isCurrentUser) {
                category = QStringLiteral("system");
            } else if (!appInfo.desktopId.isEmpty()) {
                category = QStringLiteral("app");
            } else {
                category = QStringLiteral("background");
            }

            staticInfo.startTicks = startTicks;
            staticInfo.name = name;
            staticInfo.appName = appInfo.name.isEmpty() ? name : appInfo.name;
            staticInfo.appIcon = appInfo.icon;
            staticInfo.desktopId = appInfo.desktopId;
            staticInfo.command = command;
            staticInfo.executable = executable;
            staticInfo.uid = uid;
            staticInfo.user = usernameForUid(uid, userNames);
            staticInfo.category = category;
            staticInfo.canControl = pid > 1
                && pid != static_cast<qint64>(QCoreApplication::applicationPid())
                && isCurrentUser;
            m_processStaticInfo.insert(pid, staticInfo);
        } else if (staticInfo.name != name) {
            staticInfo.name = name;
            if (staticInfo.desktopId.isEmpty()) {
                staticInfo.appName = name;
            }
            m_processStaticInfo.insert(pid, staticInfo);
        }

        const QPair<quint64, quint64> io = readProcessIo(basePath);
        nextReadBytes.insert(pid, io.first);
        nextWriteBytes.insert(pid, io.second);
        double diskReadRate = 0;
        double diskWriteRate = 0;
        if (elapsedSeconds > 0) {
            const quint64 lastRead = m_lastProcessReadBytes.value(pid);
            const quint64 lastWrite = m_lastProcessWriteBytes.value(pid);
            if (lastRead > 0 && io.first >= lastRead) {
                diskReadRate = static_cast<double>(io.first - lastRead) / elapsedSeconds;
            }
            if (lastWrite > 0 && io.second >= lastWrite) {
                diskWriteRate = static_cast<double>(io.second - lastWrite) / elapsedSeconds;
            }
        }

        bool niceOk = false;
        const int niceValue = fields.at(16).toInt(&niceOk);
        bool threadsOk = false;
        const int threads = fields.at(17).toInt(&threadsOk);
        const QString state = QString::fromLatin1(fields.at(0));

        samples.push_back(Sample{
            pid,
            parentOk ? parentPid : 0,
            name,
            staticInfo.appName,
            staticInfo.appIcon,
            staticInfo.desktopId,
            staticInfo.command,
            staticInfo.executable,
            staticInfo.user,
            state,
            staticInfo.category,
            staticInfo.uid,
            threadsOk ? std::max(0, threads) : 0,
            niceOk ? niceValue : 0,
            0,
            cpu,
            std::max<qint64>(0, rssBytes),
            diskReadRate,
            diskWriteRate,
            staticInfo.canControl,
            (niceOk && niceValue >= 10) || m_efficiencyOriginalNice.contains(pid),
        });
    }

    for (auto it = m_processStaticInfo.begin(); it != m_processStaticInfo.end();) {
        if (!livePids.contains(it.key())) {
            it = m_processStaticInfo.erase(it);
        } else {
            ++it;
        }
    }
    for (auto it = m_efficiencyOriginalNice.begin();
         it != m_efficiencyOriginalNice.end();) {
        if (!livePids.contains(it.key())) {
            it = m_efficiencyOriginalNice.erase(it);
        } else {
            ++it;
        }
    }

    m_lastProcessTicks = nextTicks;
    m_lastProcessReadBytes = nextReadBytes;
    m_lastProcessWriteBytes = nextWriteBytes;

    QHash<qint64, int> indexByPid;
    for (int index = 0; index < samples.size(); ++index) {
        indexByPid.insert(samples.at(index).pid, index);
    }

    std::function<int(qint64, QSet<qint64> &)> depthForPid =
        [&](qint64 pid, QSet<qint64> &visiting) -> int {
            const auto indexIt = indexByPid.constFind(pid);
            if (indexIt == indexByPid.cend()) {
                return 0;
            }
            Sample &sample = samples[indexIt.value()];
            if (sample.parentPid <= 0 || sample.parentPid == sample.pid
                || !indexByPid.contains(sample.parentPid)) {
                return 0;
            }
            if (visiting.contains(pid)) {
                return 0;
            }
            visiting.insert(pid);
            QSet<qint64> nextVisiting = visiting;
            return 1 + depthForPid(sample.parentPid, nextVisiting);
        };

    for (Sample &sample : samples) {
        QSet<qint64> visiting;
        sample.treeDepth = std::min(12, depthForPid(sample.pid, visiting));
    }

    auto toMap = [](const Sample &sample) {
        return QVariantMap{
            {QStringLiteral("pid"), sample.pid},
            {QStringLiteral("parentPid"), sample.parentPid},
            {QStringLiteral("name"), sample.name},
            {QStringLiteral("appName"), sample.appName},
            {QStringLiteral("appIcon"), sample.appIcon},
            {QStringLiteral("desktopId"), sample.desktopId},
            {QStringLiteral("command"), sample.command},
            {QStringLiteral("executable"), sample.executable},
            {QStringLiteral("user"), sample.user},
            {QStringLiteral("uid"), sample.uid},
            {QStringLiteral("state"), sample.state},
            {QStringLiteral("category"), sample.category},
            {QStringLiteral("threads"), sample.threads},
            {QStringLiteral("nice"), sample.niceValue},
            {QStringLiteral("treeDepth"), sample.treeDepth},
            {QStringLiteral("cpu"), sample.cpu},
            {QStringLiteral("memoryBytes"), sample.memory},
            {QStringLiteral("diskReadBytesPerSecond"), sample.diskReadRate},
            {QStringLiteral("diskWriteBytesPerSecond"), sample.diskWriteRate},
            {QStringLiteral("canControl"), sample.canControl},
            {QStringLiteral("efficiency"), sample.efficiency},
        };
    };

    QVector<Sample> cpuSorted = samples;
    std::sort(cpuSorted.begin(), cpuSorted.end(), [](const Sample &left, const Sample &right) {
        if (!qFuzzyCompare(left.cpu + 1.0, right.cpu + 1.0)) {
            return left.cpu > right.cpu;
        }
        return left.memory > right.memory;
    });

    m_processes.clear();
    m_processes.reserve(cpuSorted.size());
    for (const Sample &sample : cpuSorted) {
        m_processes.push_back(toMap(sample));
    }

    QHash<QString, QVariantMap> groupMap;
    for (const Sample &sample : samples) {
        const QString key = !sample.desktopId.isEmpty()
            ? QStringLiteral("desktop:") + sample.desktopId
            : QStringLiteral("pid:%1").arg(sample.pid);
        QVariantMap group = groupMap.value(key);
        if (group.isEmpty()) {
            group.insert(QStringLiteral("key"), key);
            group.insert(QStringLiteral("appName"), sample.appName);
            group.insert(QStringLiteral("appIcon"), sample.appIcon);
            group.insert(QStringLiteral("desktopId"), sample.desktopId);
            group.insert(QStringLiteral("category"), sample.category);
            group.insert(QStringLiteral("processCount"), 0);
            group.insert(QStringLiteral("pids"), QVariantList{});
            group.insert(QStringLiteral("mainPid"), sample.pid);
            group.insert(QStringLiteral("cpu"), 0.0);
            group.insert(QStringLiteral("memoryBytes"), static_cast<qint64>(0));
            group.insert(QStringLiteral("diskReadBytesPerSecond"), 0.0);
            group.insert(QStringLiteral("diskWriteBytesPerSecond"), 0.0);
            group.insert(QStringLiteral("canControl"), sample.canControl);
        }

        QVariantList pids = group.value(QStringLiteral("pids")).toList();
        pids.push_back(sample.pid);
        group[QStringLiteral("pids")] = pids;
        group[QStringLiteral("processCount")] =
            group.value(QStringLiteral("processCount")).toInt() + 1;
        group[QStringLiteral("cpu")] =
            group.value(QStringLiteral("cpu")).toDouble() + sample.cpu;
        group[QStringLiteral("memoryBytes")] =
            group.value(QStringLiteral("memoryBytes")).toLongLong() + sample.memory;
        group[QStringLiteral("diskReadBytesPerSecond")] =
            group.value(QStringLiteral("diskReadBytesPerSecond")).toDouble() + sample.diskReadRate;
        group[QStringLiteral("diskWriteBytesPerSecond")] =
            group.value(QStringLiteral("diskWriteBytesPerSecond")).toDouble() + sample.diskWriteRate;
        group[QStringLiteral("canControl")] =
            group.value(QStringLiteral("canControl")).toBool() && sample.canControl;
        groupMap.insert(key, group);
    }

    m_processGroups.clear();
    m_processGroups.reserve(groupMap.size());
    for (auto it = groupMap.cbegin(); it != groupMap.cend(); ++it) {
        m_processGroups.push_back(it.value());
    }
    std::sort(m_processGroups.begin(), m_processGroups.end(),
              [](const QVariant &left, const QVariant &right) {
        const QVariantMap a = left.toMap();
        const QVariantMap b = right.toMap();
        const double aCpu = a.value(QStringLiteral("cpu")).toDouble();
        const double bCpu = b.value(QStringLiteral("cpu")).toDouble();
        if (!qFuzzyCompare(aCpu + 1.0, bCpu + 1.0)) {
            return aCpu > bCpu;
        }
        return a.value(QStringLiteral("memoryBytes")).toLongLong()
            > b.value(QStringLiteral("memoryBytes")).toLongLong();
    });

    QHash<qint64, QVector<qint64>> children;
    QVector<qint64> roots;
    for (const Sample &sample : samples) {
        if (sample.parentPid > 0 && sample.parentPid != sample.pid
            && indexByPid.contains(sample.parentPid)) {
            children[sample.parentPid].push_back(sample.pid);
        } else {
            roots.push_back(sample.pid);
        }
    }

    auto nameForPid = [&](qint64 pid) {
        const auto it = indexByPid.constFind(pid);
        return it == indexByPid.cend() ? QString() : samples.at(it.value()).appName;
    };
    auto sortPids = [&](QVector<qint64> &pids) {
        std::sort(pids.begin(), pids.end(), [&](qint64 left, qint64 right) {
            return nameForPid(left).localeAwareCompare(nameForPid(right)) < 0;
        });
    };
    sortPids(roots);
    for (auto it = children.begin(); it != children.end(); ++it) {
        sortPids(it.value());
    }

    m_processTree.clear();
    QSet<qint64> visited;
    std::function<void(qint64)> appendTree = [&](qint64 pid) {
        if (visited.contains(pid)) {
            return;
        }
        visited.insert(pid);
        const auto indexIt = indexByPid.constFind(pid);
        if (indexIt == indexByPid.cend()) {
            return;
        }
        m_processTree.push_back(toMap(samples.at(indexIt.value())));
        const QVector<qint64> childList = children.value(pid);
        for (qint64 child : childList) {
            appendTree(child);
        }
    };
    for (qint64 rootPid : roots) {
        appendTree(rootPid);
    }
    for (const Sample &sample : samples) {
        appendTree(sample.pid);
    }

    QHash<qint64, QVariantMap> userMap;
    for (const Sample &sample : samples) {
        QVariantMap summary = userMap.value(sample.uid);
        if (summary.isEmpty()) {
            summary.insert(QStringLiteral("uid"), sample.uid);
            summary.insert(QStringLiteral("user"), sample.user);
            summary.insert(QStringLiteral("processCount"), 0);
            summary.insert(QStringLiteral("cpu"), 0.0);
            summary.insert(QStringLiteral("memoryBytes"), static_cast<qint64>(0));
            summary.insert(QStringLiteral("diskReadBytesPerSecond"), 0.0);
            summary.insert(QStringLiteral("diskWriteBytesPerSecond"), 0.0);
            summary.insert(QStringLiteral("sessionActive"),
                           sample.uid >= 0 && QFileInfo::exists(QStringLiteral("/run/user/%1").arg(sample.uid)));
            summary.insert(QStringLiteral("currentUser"), sample.uid >= 0
                           && static_cast<uid_t>(sample.uid) == currentUid);
        }
        summary[QStringLiteral("processCount")] = summary.value(QStringLiteral("processCount")).toInt() + 1;
        summary[QStringLiteral("cpu")] = summary.value(QStringLiteral("cpu")).toDouble() + sample.cpu;
        summary[QStringLiteral("memoryBytes")] = summary.value(QStringLiteral("memoryBytes")).toLongLong() + sample.memory;
        summary[QStringLiteral("diskReadBytesPerSecond")] =
            summary.value(QStringLiteral("diskReadBytesPerSecond")).toDouble() + sample.diskReadRate;
        summary[QStringLiteral("diskWriteBytesPerSecond")] =
            summary.value(QStringLiteral("diskWriteBytesPerSecond")).toDouble() + sample.diskWriteRate;
        userMap.insert(sample.uid, summary);
    }

    QList<qint64> userIds = userMap.keys();
    std::sort(userIds.begin(), userIds.end(), [&](qint64 left, qint64 right) {
        const bool leftCurrent = userMap.value(left).value(QStringLiteral("currentUser")).toBool();
        const bool rightCurrent = userMap.value(right).value(QStringLiteral("currentUser")).toBool();
        if (leftCurrent != rightCurrent) {
            return leftCurrent;
        }
        return userMap.value(left).value(QStringLiteral("user")).toString()
            .localeAwareCompare(userMap.value(right).value(QStringLiteral("user")).toString()) < 0;
    });
    m_userSummaries.clear();
    for (qint64 uid : userIds) {
        const QVariantMap summary = userMap.value(uid);
        if (!summary.value(QStringLiteral("currentUser")).toBool()
            && !summary.value(QStringLiteral("sessionActive")).toBool()) {
            continue;
        }
        m_userSummaries.push_back(summary);
    }

    updateSelectedProcessDetails(elapsedSeconds);
}

void TaskManagerController::updateSelectedProcessDetails(double elapsedSeconds)
{
    QVariantMap selected;
    for (const QVariant &entry : m_processes) {
        const QVariantMap process = entry.toMap();
        if (process.value(QStringLiteral("pid")).toLongLong() == m_selectedPid) {
            selected = process;
            break;
        }
    }

    if (selected.isEmpty()) {
        m_selectedProcessDetails.clear();
        m_selectedProcessGpuAvailable = false;
        if (m_selectedPid > 0 && !QFileInfo::exists(QStringLiteral("/proc/%1").arg(m_selectedPid))) {
            m_selectedPid = -1;
        }
        Q_EMIT selectedProcessDetailsChanged();
        return;
    }

    const QString procBase = QStringLiteral("/proc/%1").arg(m_selectedPid);
    const QString executablePath = QFileInfo(procBase + QStringLiteral("/exe")).symLinkTarget();
    const QString workingDirectory = QFileInfo(procBase + QStringLiteral("/cwd")).symLinkTarget();
    const QVariantList affinity = processAffinity(m_selectedPid);

    quint64 cpuTicks = 0;
    quint64 startTicks = 0;
    const QByteArray selectedStat = readBytes(procBase + QStringLiteral("/stat")).trimmed();
    const int selectedCloseParen = selectedStat.lastIndexOf(')');
    if (selectedCloseParen >= 0) {
        const QList<QByteArray> fields =
            selectedStat.mid(selectedCloseParen + 2).simplified().split(' ');
        if (fields.size() > 19) {
            cpuTicks = fields.at(11).toULongLong() + fields.at(12).toULongLong();
            startTicks = fields.at(19).toULongLong();
        }
    }
    const long ticksPerSecond = std::max<long>(1, sysconf(_SC_CLK_TCK));
    double uptimeSeconds = 0;
    bool uptimeOk = false;
    const QList<QByteArray> uptimeFields =
        readBytes(QStringLiteral("/proc/uptime")).simplified().split(' ');
    if (!uptimeFields.isEmpty()) {
        uptimeSeconds = uptimeFields.constFirst().toDouble(&uptimeOk);
    }
    const double elapsedProcessSeconds =
        uptimeOk && startTicks > 0
        ? std::max(0.0, uptimeSeconds
                  - static_cast<double>(startTicks) / static_cast<double>(ticksPerSecond))
        : 0.0;
    const QPair<quint64, quint64> totalIo = readProcessIo(procBase);

    QHash<QByteArray, qint64> selectedMemoryKiB;
    int noNewPrivileges = -1;
    int seccompMode = -1;
    const QList<QByteArray> selectedStatusLines =
        readBytes(procBase + QStringLiteral("/status")).split('\n');
    for (const QByteArray &line : selectedStatusLines) {
        const int colon = line.indexOf(':');
        if (colon <= 0) {
            continue;
        }
        const QByteArray key = line.left(colon).trimmed();
        const QByteArray value = line.mid(colon + 1).simplified();
        if (key == "VmSize" || key == "VmHWM" || key == "RssAnon"
            || key == "RssFile" || key == "RssShmem" || key == "VmSwap") {
            const QList<QByteArray> fields = value.split(' ');
            bool ok = false;
            const qint64 kib = fields.value(0).toLongLong(&ok);
            if (ok) {
                selectedMemoryKiB.insert(key, kib);
            }
        } else if (key == "NoNewPrivs") {
            noNewPrivileges = value.toInt();
        } else if (key == "Seccomp") {
            seccompMode = value.toInt();
        }
    }

    QString cgroupPath;
    const QList<QByteArray> cgroupLines =
        readBytes(procBase + QStringLiteral("/cgroup")).split('\n');
    for (const QByteArray &line : cgroupLines) {
        if (line.startsWith("0::")) {
            cgroupPath = QString::fromUtf8(line.mid(3)).trimmed();
            break;
        }
    }

    bool oomOk = false;
    const int oomScore =
        readText(procBase + QStringLiteral("/oom_score")).toInt(&oomOk);

    selected.insert(QStringLiteral("executablePath"), executablePath);
    selected.insert(QStringLiteral("workingDirectory"), workingDirectory);
    selected.insert(QStringLiteral("openFileDescriptorCount"), openFileDescriptorCount(m_selectedPid));
    selected.insert(QStringLiteral("cpuAffinity"), affinity);
    selected.insert(QStringLiteral("cpuTimeSeconds"),
                    static_cast<double>(cpuTicks) / static_cast<double>(ticksPerSecond));
    selected.insert(QStringLiteral("elapsedSeconds"), elapsedProcessSeconds);
    selected.insert(QStringLiteral("diskReadBytesTotal"), static_cast<qint64>(totalIo.first));
    selected.insert(QStringLiteral("diskWriteBytesTotal"), static_cast<qint64>(totalIo.second));
    selected.insert(QStringLiteral("virtualMemoryBytes"),
                    selectedMemoryKiB.value("VmSize") * 1024LL);
    selected.insert(QStringLiteral("peakResidentMemoryBytes"),
                    selectedMemoryKiB.value("VmHWM") * 1024LL);
    selected.insert(QStringLiteral("anonymousMemoryBytes"),
                    selectedMemoryKiB.value("RssAnon") * 1024LL);
    selected.insert(QStringLiteral("fileMemoryBytes"),
                    selectedMemoryKiB.value("RssFile") * 1024LL);
    selected.insert(QStringLiteral("sharedMemoryBytes"),
                    selectedMemoryKiB.value("RssShmem") * 1024LL);
    selected.insert(QStringLiteral("swapMemoryBytes"),
                    selectedMemoryKiB.value("VmSwap") * 1024LL);
    selected.insert(QStringLiteral("cgroupPath"), cgroupPath);
    selected.insert(QStringLiteral("oomScore"), oomOk ? oomScore : -1);
    selected.insert(QStringLiteral("noNewPrivileges"), noNewPrivileges == 1);
    selected.insert(QStringLiteral("seccompMode"), seccompMode);
    selected.insert(QStringLiteral("logicalCpuCount"),
                    static_cast<int>(std::max<long>(1, sysconf(_SC_NPROCESSORS_CONF))));
    selected.insert(QStringLiteral("suspended"),
                    selected.value(QStringLiteral("state")).toString() == QStringLiteral("T")
                    || selected.value(QStringLiteral("state")).toString() == QStringLiteral("t"));
    const QVariantMap socketSummary = socketProtocolSummary(m_selectedPid);
    selected.insert(QStringLiteral("socketCount"),
                    socketSummary.value(QStringLiteral("total")));
    selected.insert(QStringLiteral("tcpSocketCount"),
                    socketSummary.value(QStringLiteral("tcp")));
    selected.insert(QStringLiteral("tcpEstablishedCount"),
                    socketSummary.value(QStringLiteral("tcpEstablished")));
    selected.insert(QStringLiteral("tcpListenCount"),
                    socketSummary.value(QStringLiteral("tcpListen")));
    selected.insert(QStringLiteral("udpSocketCount"),
                    socketSummary.value(QStringLiteral("udp")));
    selected.insert(QStringLiteral("networkThroughputAvailable"), false);
    selected.insert(QStringLiteral("networkNote"),
                    QStringLiteral("Linux does not expose generic per-process byte throughput in /proc; sockets are shown without fabricated bandwidth."));

    const auto drm = readProcessDrmStats(m_selectedPid);
    double gpuUsage = -1;
    if (drm.first > 0 && m_lastSelectedGpuPid == m_selectedPid
        && m_lastSelectedGpuEngineNs > 0 && drm.first >= m_lastSelectedGpuEngineNs
        && elapsedSeconds > 0) {
        gpuUsage = std::clamp(
            static_cast<double>(drm.first - m_lastSelectedGpuEngineNs)
                / (elapsedSeconds * 1000000000.0) * 100.0,
            0.0, 100.0);
    }
    m_lastSelectedGpuPid = m_selectedPid;
    m_lastSelectedGpuEngineNs = drm.first;
    m_selectedProcessGpuAvailable = drm.first > 0 || drm.second > 0;
    selected.insert(QStringLiteral("gpuUsage"), gpuUsage);
    selected.insert(QStringLiteral("gpuMemoryBytes"), static_cast<qint64>(drm.second));
    selected.insert(QStringLiteral("gpuAvailable"), m_selectedProcessGpuAvailable);

    m_selectedProcessDetails = selected;
    Q_EMIT selectedProcessDetailsChanged();
}

bool TaskManagerController::terminateProcess(qint64 pid, bool force)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("This process cannot be ended from Meo System Monitor."));
        return false;
    }
    if (!QFileInfo::exists(QStringLiteral("/proc/%1").arg(pid))) {
        setActionError(QStringLiteral("The process has already exited."));
        return false;
    }

    errno = 0;
    if (::kill(static_cast<pid_t>(pid), force ? SIGKILL : SIGTERM) != 0) {
        setActionError(QStringLiteral("Could not end process %1: %2")
                           .arg(pid)
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    setActionError({});
    Q_EMIT processActionCompleted(pid, force ? QStringLiteral("force-stop")
                                              : QStringLiteral("terminate"));
    QTimer::singleShot(150, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::terminateProcessTree(qint64 pid, bool force)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("This process tree cannot be ended from Meo System Monitor."));
        return false;
    }

    QHash<qint64, QVector<qint64>> children;
    QDir proc(QStringLiteral("/proc"));
    static const QRegularExpression digits(QStringLiteral("^\\d+$"));
    const QStringList entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &entry : entries) {
        if (!digits.match(entry).hasMatch()) {
            continue;
        }
        bool childOk = false;
        const qint64 childPid = entry.toLongLong(&childOk);
        if (!childOk || childPid <= 1) {
            continue;
        }
        const QByteArray stat = readBytes(proc.filePath(entry) + QStringLiteral("/stat")).trimmed();
        const int closeParen = stat.lastIndexOf(')');
        if (closeParen < 0) {
            continue;
        }
        const QList<QByteArray> fields = stat.mid(closeParen + 2).simplified().split(' ');
        if (fields.size() < 2) {
            continue;
        }
        bool parentOk = false;
        const qint64 parentPid = fields.at(1).toLongLong(&parentOk);
        if (parentOk) {
            children[parentPid].push_back(childPid);
        }
    }

    QVector<qint64> ordered;
    QSet<qint64> visited;
    std::function<void(qint64)> appendPostOrder = [&](qint64 current) {
        if (visited.contains(current)) {
            return;
        }
        visited.insert(current);
        for (qint64 child : children.value(current)) {
            appendPostOrder(child);
        }
        ordered.push_back(current);
    };
    appendPostOrder(pid);

    const int signal = force ? SIGKILL : SIGTERM;
    int failed = 0;
    int signalled = 0;
    for (qint64 target : ordered) {
        if (target <= 1 || target == static_cast<qint64>(QCoreApplication::applicationPid())
            || !processOwnedByCurrentUser(target)) {
            continue;
        }
        errno = 0;
        if (::kill(static_cast<pid_t>(target), signal) == 0) {
            ++signalled;
        } else if (errno != ESRCH) {
            ++failed;
        }
    }

    if (signalled == 0 || failed > 0) {
        setActionError(failed > 0
            ? QStringLiteral("Some processes in the tree could not be ended.")
            : QStringLiteral("No controllable processes were found in this tree."));
        return false;
    }

    setActionError({});
    Q_EMIT processActionCompleted(pid, force ? QStringLiteral("force-stop-tree")
                                              : QStringLiteral("terminate-tree"));
    QTimer::singleShot(150, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::setProcessSuspended(qint64 pid, bool suspended)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("This process cannot be suspended or resumed."));
        return false;
    }

    errno = 0;
    if (::kill(static_cast<pid_t>(pid), suspended ? SIGSTOP : SIGCONT) != 0) {
        setActionError(QStringLiteral("Could not %1 process %2: %3")
                           .arg(suspended ? QStringLiteral("suspend") : QStringLiteral("resume"))
                           .arg(pid)
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    setActionError({});
    Q_EMIT processActionCompleted(pid, suspended ? QStringLiteral("suspend")
                                                  : QStringLiteral("resume"));
    QTimer::singleShot(100, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::setProcessPriority(qint64 pid, int niceValue)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("This process priority cannot be changed from Meo System Monitor."));
        return false;
    }

    const int bounded = qBound(-20, niceValue, 19);
    errno = 0;
    if (::setpriority(PRIO_PROCESS, static_cast<id_t>(pid), bounded) != 0) {
        setActionError(QStringLiteral("Could not change priority for process %1: %2")
                           .arg(pid)
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    if (bounded < 10) {
        m_efficiencyOriginalNice.remove(pid);
    }
    setActionError({});
    Q_EMIT processActionCompleted(pid, QStringLiteral("priority"));
    QTimer::singleShot(100, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::setProcessEfficiency(qint64 pid, bool enabled)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("Efficiency mode cannot be changed for this process."));
        return false;
    }

    errno = 0;
    const int currentNice = ::getpriority(PRIO_PROCESS, static_cast<id_t>(pid));
    if (errno != 0) {
        setActionError(QStringLiteral("Could not read process priority: %1")
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    int targetNice = currentNice;
    const bool hadOriginalNice = m_efficiencyOriginalNice.contains(pid);
    if (enabled) {
        if (!hadOriginalNice) {
            m_efficiencyOriginalNice.insert(pid, currentNice);
        }
        targetNice = std::max(currentNice, 10);
    } else {
        targetNice = m_efficiencyOriginalNice.value(pid, 0);
    }

    errno = 0;
    if (::setpriority(PRIO_PROCESS, static_cast<id_t>(pid), targetNice) != 0) {
        if (enabled && !hadOriginalNice) {
            m_efficiencyOriginalNice.remove(pid);
        }
        setActionError(QStringLiteral("Could not change efficiency mode: %1")
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    if (!enabled) {
        m_efficiencyOriginalNice.remove(pid);
    }
    setActionError({});
    Q_EMIT processActionCompleted(pid, enabled ? QStringLiteral("efficiency-on")
                                                : QStringLiteral("efficiency-off"));
    QTimer::singleShot(100, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::setProcessCpuAffinity(qint64 pid, const QVariantList &cpuIndices)
{
    if (pid <= 1 || pid == static_cast<qint64>(QCoreApplication::applicationPid())
        || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("CPU affinity cannot be changed for this process."));
        return false;
    }

    cpu_set_t set;
    CPU_ZERO(&set);
    int count = 0;
    for (const QVariant &entry : cpuIndices) {
        bool ok = false;
        const int cpu = entry.toInt(&ok);
        if (!ok || cpu < 0 || cpu >= CPU_SETSIZE) {
            continue;
        }
        CPU_SET(cpu, &set);
        ++count;
    }
    if (count == 0) {
        setActionError(QStringLiteral("Select at least one CPU."));
        return false;
    }

    errno = 0;
    if (::sched_setaffinity(static_cast<pid_t>(pid), sizeof(set), &set) != 0) {
        setActionError(QStringLiteral("Could not change CPU affinity: %1")
                           .arg(QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    setActionError({});
    Q_EMIT processActionCompleted(pid, QStringLiteral("cpu-affinity"));
    QTimer::singleShot(100, this, &TaskManagerController::refreshNow);
    return true;
}

bool TaskManagerController::setProcessCpuAffinityAll(qint64 pid)
{
    QVariantList cpus;
    const long count = std::max<long>(1, sysconf(_SC_NPROCESSORS_CONF));
    for (int cpu = 0; cpu < std::min<long>(count, CPU_SETSIZE); ++cpu) {
        cpus.push_back(cpu);
    }
    return setProcessCpuAffinity(pid, cpus);
}

bool TaskManagerController::openProcessLocation(qint64 pid)
{
    if (pid <= 1 || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("The executable path is unavailable."));
        return false;
    }

    const QString target = QFileInfo(QStringLiteral("/proc/%1/exe").arg(pid)).symLinkTarget();
    if (target.isEmpty()) {
        setActionError(QStringLiteral("The executable path is unavailable."));
        return false;
    }
    const QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
    if (opener.isEmpty()
        || !QProcess::startDetached(opener, {QFileInfo(target).absolutePath()})) {
        setActionError(QStringLiteral("Could not open the executable location."));
        return false;
    }
    setActionError({});
    return true;
}

bool TaskManagerController::openProcessWorkingDirectory(qint64 pid)
{
    if (pid <= 1 || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("The working directory is unavailable."));
        return false;
    }

    const QString target = QFileInfo(QStringLiteral("/proc/%1/cwd").arg(pid)).symLinkTarget();
    if (target.isEmpty()) {
        setActionError(QStringLiteral("The working directory is unavailable."));
        return false;
    }
    const QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
    if (opener.isEmpty() || !QProcess::startDetached(opener, {target})) {
        setActionError(QStringLiteral("Could not open the working directory."));
        return false;
    }
    setActionError({});
    return true;
}

bool TaskManagerController::copyProcessCommand(qint64 pid)
{
    if (pid <= 1 || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("The process command line is unavailable."));
        return false;
    }

    QByteArray raw = readBytes(QStringLiteral("/proc/%1/cmdline").arg(pid));
    std::replace(raw.begin(), raw.end(), '\0', ' ');
    const QString value = QString::fromUtf8(raw).simplified();
    if (value.isEmpty() || !QGuiApplication::clipboard()) {
        setActionError(QStringLiteral("The process command line is unavailable."));
        return false;
    }
    QGuiApplication::clipboard()->setText(value);
    setActionError({});
    return true;
}

bool TaskManagerController::copyProcessExecutablePath(qint64 pid)
{
    if (pid <= 1 || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("The executable path is unavailable."));
        return false;
    }

    const QString value = QFileInfo(QStringLiteral("/proc/%1/exe").arg(pid)).symLinkTarget();
    if (value.isEmpty() || !QGuiApplication::clipboard()) {
        setActionError(QStringLiteral("The executable path is unavailable."));
        return false;
    }
    QGuiApplication::clipboard()->setText(value);
    setActionError({});
    return true;
}

bool TaskManagerController::copyProcessWorkingDirectory(qint64 pid)
{
    if (pid <= 1 || !processOwnedByCurrentUser(pid)) {
        setActionError(QStringLiteral("The working directory is unavailable."));
        return false;
    }

    const QString value = QFileInfo(QStringLiteral("/proc/%1/cwd").arg(pid)).symLinkTarget();
    if (value.isEmpty() || !QGuiApplication::clipboard()) {
        setActionError(QStringLiteral("The working directory is unavailable."));
        return false;
    }
    QGuiApplication::clipboard()->setText(value);
    setActionError({});
    return true;
}

void TaskManagerController::refreshStartupApps()
{
    const QString currentDesktopValue = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
    QStringList currentDesktops = currentDesktopValue.split(':', Qt::SkipEmptyParts);
    for (QString &desktop : currentDesktops) {
        desktop = desktop.trimmed();
    }
    if (currentDesktops.isEmpty()) {
        currentDesktops = {QStringLiteral("KDE")};
    }

    auto desktopListContainsCurrent = [&currentDesktops](const QString &value) {
        const QStringList entries = value.split(';', Qt::SkipEmptyParts);
        for (const QString &entry : entries) {
            for (const QString &desktop : currentDesktops) {
                if (entry.trimmed().compare(desktop, Qt::CaseInsensitive) == 0) {
                    return true;
                }
            }
        }
        return false;
    };

    const QString userConfig = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QString userDir = QDir(userConfig).filePath(QStringLiteral("autostart"));
    QHash<QString, QString> userPaths;
    QHash<QString, QString> systemPaths;

    auto scanDirectory = [](const QString &directory, QHash<QString, QString> &target) {
        QDir dir(directory);
        const QStringList files = dir.entryList({QStringLiteral("*.desktop")}, QDir::Files, QDir::Name);
        for (const QString &file : files) {
            if (!target.contains(file)) {
                target.insert(file, dir.filePath(file));
            }
        }
    };

    scanDirectory(userDir, userPaths);
    const QStringList configRoots = QStandardPaths::standardLocations(QStandardPaths::GenericConfigLocation);
    for (const QString &root : configRoots) {
        const QString candidate = QDir(root).filePath(QStringLiteral("autostart"));
        if (QFileInfo(candidate).canonicalFilePath() == QFileInfo(userDir).canonicalFilePath()) {
            continue;
        }
        scanDirectory(candidate, systemPaths);
    }

    QSet<QString> ids;
    for (auto it = userPaths.cbegin(); it != userPaths.cend(); ++it) ids.insert(it.key());
    for (auto it = systemPaths.cbegin(); it != systemPaths.cend(); ++it) ids.insert(it.key());

    QStringList sortedIds = ids.values();
    sortedIds.sort(Qt::CaseInsensitive);
    m_startupApps.clear();
    m_startupById.clear();

    for (const QString &id : sortedIds) {
        const QString userPath = userPaths.value(id);
        const QString systemPath = systemPaths.value(id);
        const QString effectivePath = !userPath.isEmpty() ? userPath : systemPath;
        const QByteArray content = readBytes(effectivePath);
        if (content.isEmpty()) {
            continue;
        }

        const QString name = desktopEntryValue(content, "Name");
        const QString exec = desktopEntryValue(content, "Exec");
        const QString icon = desktopEntryValue(content, "Icon");
        const QString comment = desktopEntryValue(content, "Comment");
        const bool hidden = desktopEntryValue(content, "Hidden").compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0;
        const QString gnomeEnabled = desktopEntryValue(content, "X-GNOME-Autostart-enabled");
        const QString onlyShowIn = desktopEntryValue(content, "OnlyShowIn");
        const QString notShowIn = desktopEntryValue(content, "NotShowIn");
        const QString tryExec = desktopEntryValue(content, "TryExec");

        bool eligible = true;
        if (!onlyShowIn.isEmpty() && !desktopListContainsCurrent(onlyShowIn)) {
            eligible = false;
        }
        if (!notShowIn.isEmpty() && desktopListContainsCurrent(notShowIn)) {
            eligible = false;
        }
        if (!tryExec.isEmpty()
            && QStandardPaths::findExecutable(QProcess::splitCommand(tryExec).value(0)).isEmpty()) {
            eligible = false;
        }
        if (!eligible) {
            continue;
        }

        const bool enabled = !hidden
            && gnomeEnabled.compare(QStringLiteral("false"), Qt::CaseInsensitive) != 0;
        const bool meoDisabled =
            desktopEntryValue(content, "X-Meo-Disabled").compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0;
        const bool meoOverride =
            desktopEntryValue(content, "X-Meo-Override").compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0;
        const QString source = meoOverride && !systemPath.isEmpty()
            ? QStringLiteral("system")
            : (userPath.isEmpty() ? QStringLiteral("system") : QStringLiteral("user"));

        QVariantMap app{
            {QStringLiteral("id"), id},
            {QStringLiteral("name"), name.isEmpty() ? QFileInfo(id).completeBaseName() : name},
            {QStringLiteral("exec"), exec},
            {QStringLiteral("icon"), icon},
            {QStringLiteral("description"), comment},
            {QStringLiteral("enabled"), enabled},
            {QStringLiteral("source"), source},
            {QStringLiteral("path"), effectivePath},
            {QStringLiteral("userPath"), userPath},
            {QStringLiteral("systemPath"), systemPath},
            {QStringLiteral("meoDisabled"), meoDisabled},
            {QStringLiteral("meoOverride"), meoOverride},
        };
        m_startupApps.push_back(app);
        m_startupById.insert(id, app);
    }

    std::sort(m_startupApps.begin(), m_startupApps.end(), [](const QVariant &left, const QVariant &right) {
        return left.toMap().value(QStringLiteral("name")).toString()
            .localeAwareCompare(right.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    Q_EMIT startupAppsChanged();
}

bool TaskManagerController::setStartupEnabled(const QString &desktopId, bool enabled)
{
    const QVariantMap info = m_startupById.value(desktopId);
    if (info.isEmpty()) {
        setActionError(QStringLiteral("Startup entry was not found."));
        return false;
    }

    const QString userDir = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation))
                                .filePath(QStringLiteral("autostart"));
    const QString userPath = QDir(userDir).filePath(desktopId);
    const QString currentUserPath = info.value(QStringLiteral("userPath")).toString();
    const QString systemPath = info.value(QStringLiteral("systemPath")).toString();

    if (enabled) {
        if (!currentUserPath.isEmpty()
            && info.value(QStringLiteral("meoOverride")).toBool()
            && !systemPath.isEmpty()) {
            if (!QFile::remove(currentUserPath)) {
                setActionError(QStringLiteral("Could not remove the Meo startup override."));
                return false;
            }
        } else {
            const QString path = !currentUserPath.isEmpty() ? currentUserPath : userPath;
            QByteArray content = readBytes(path);
            if (content.isEmpty() && !systemPath.isEmpty()) {
                content = readBytes(systemPath);
            }
            content = setDesktopEntryKey(content, "Hidden", "false");
            content = setDesktopEntryKey(content, "X-GNOME-Autostart-enabled", "true");
            content = setDesktopEntryKey(content, "X-Meo-Disabled", "false");
            content = setDesktopEntryKey(content, "X-Meo-Override", "false");
            if (!writeFileAtomically(path, content)) {
                setActionError(QStringLiteral("Could not enable the startup entry."));
                return false;
            }
        }
    } else {
        const bool creatingOverride = currentUserPath.isEmpty() && !systemPath.isEmpty();
        QByteArray content = readBytes(!currentUserPath.isEmpty() ? currentUserPath : systemPath);
        if (content.isEmpty()) {
            setActionError(QStringLiteral("Could not read the startup entry."));
            return false;
        }
        content = setDesktopEntryKey(content, "Hidden", "true");
        content = setDesktopEntryKey(content, "X-Meo-Disabled", "true");
        content = setDesktopEntryKey(content, "X-Meo-Override", creatingOverride ? "true" : "false");
        const QString targetPath = !currentUserPath.isEmpty() ? currentUserPath : userPath;
        if (!writeFileAtomically(targetPath, content)) {
            setActionError(QStringLiteral("Could not create the startup override."));
            return false;
        }
    }

    setActionError({});
    refreshStartupApps();
    Q_EMIT startupActionCompleted(desktopId, enabled);
    return true;
}

void TaskManagerController::refreshServices()
{
    if (m_serviceQuerying) {
        return;
    }
    const QString systemctl = QStandardPaths::findExecutable(QStringLiteral("systemctl"));
    if (systemctl.isEmpty()) {
        m_servicesAvailable = false;
        m_services.clear();
        Q_EMIT servicesChanged();
        return;
    }

    m_serviceQuerying = true;
    Q_EMIT servicesChanged();

    auto *unitsProcess = new QProcess(this);
    unitsProcess->setProgram(systemctl);
    unitsProcess->setArguments({
        QStringLiteral("--user"),
        QStringLiteral("list-units"),
        QStringLiteral("--type=service"),
        QStringLiteral("--all"),
        QStringLiteral("--plain"),
        QStringLiteral("--full"),
        QStringLiteral("--no-legend"),
        QStringLiteral("--no-pager"),
    });
    unitsProcess->setStandardErrorFile(QProcess::nullDevice());

    connect(unitsProcess, &QProcess::finished, this,
            [this, unitsProcess, systemctl](int exitCode, QProcess::ExitStatus status) {
        QHash<QString, QVariantMap> units;
        if (status == QProcess::NormalExit && exitCode == 0) {
            const QList<QByteArray> rows = unitsProcess->readAllStandardOutput().split('\n');
            for (const QByteArray &rawRow : rows) {
                const QByteArray row = rawRow.simplified();
                if (row.isEmpty()) {
                    continue;
                }
                QList<QByteArray> fields = row.split(' ');
                if (!fields.isEmpty() && !fields.constFirst().endsWith(".service")) {
                    fields.removeFirst();
                }
                if (fields.size() < 4) {
                    continue;
                }
                const QString unit = QString::fromUtf8(fields.at(0));
                const QString load = QString::fromUtf8(fields.at(1));
                const QString active = QString::fromUtf8(fields.at(2));
                const QString sub = QString::fromUtf8(fields.at(3));
                QByteArray descriptionBytes;
                for (int fieldIndex = 4; fieldIndex < fields.size(); ++fieldIndex) {
                    if (!descriptionBytes.isEmpty()) {
                        descriptionBytes += ' ';
                    }
                    descriptionBytes += fields.at(fieldIndex);
                }
                const QString description = QString::fromUtf8(descriptionBytes);
                units.insert(unit, QVariantMap{
                    {QStringLiteral("unit"), unit},
                    {QStringLiteral("description"), description},
                    {QStringLiteral("loadState"), load},
                    {QStringLiteral("activeState"), active},
                    {QStringLiteral("subState"), sub},
                    {QStringLiteral("enabledState"), QString()},
                });
            }
        }
        unitsProcess->deleteLater();

        auto *filesProcess = new QProcess(this);
        filesProcess->setProgram(systemctl);
        filesProcess->setArguments({
            QStringLiteral("--user"),
            QStringLiteral("list-unit-files"),
            QStringLiteral("--type=service"),
            QStringLiteral("--no-legend"),
            QStringLiteral("--no-pager"),
        });
        filesProcess->setStandardErrorFile(QProcess::nullDevice());

        const bool unitsSucceeded = status == QProcess::NormalExit && exitCode == 0;
        connect(filesProcess, &QProcess::finished, this,
                [this, filesProcess, units = std::move(units), unitsSucceeded](int filesExitCode, QProcess::ExitStatus filesStatus) mutable {
            if (filesStatus == QProcess::NormalExit && filesExitCode == 0) {
                const QList<QByteArray> rows = filesProcess->readAllStandardOutput().split('\n');
                for (const QByteArray &rawRow : rows) {
                    const QList<QByteArray> fields = rawRow.simplified().split(' ');
                    if (fields.size() < 2 || fields.constFirst().isEmpty()) {
                        continue;
                    }
                    const QString unit = QString::fromUtf8(fields.at(0));
                    const QString enabledState = QString::fromUtf8(fields.at(1));
                    QVariantMap service = units.value(unit);
                    if (service.isEmpty()) {
                        service.insert(QStringLiteral("unit"), unit);
                        service.insert(QStringLiteral("description"), QString());
                        service.insert(QStringLiteral("loadState"), QStringLiteral("loaded"));
                        service.insert(QStringLiteral("activeState"), QStringLiteral("inactive"));
                        service.insert(QStringLiteral("subState"), QStringLiteral("dead"));
                    }
                    service.insert(QStringLiteral("enabledState"), enabledState);
                    units.insert(unit, service);
                }
            }
            filesProcess->deleteLater();

            QStringList names = units.keys();
            names.sort(Qt::CaseInsensitive);
            QVariantList userServices;
            for (const QString &name : names) {
                QVariantMap service = units.value(name);
                const QString active = service.value(QStringLiteral("activeState")).toString();
                service.insert(QStringLiteral("running"), active == QStringLiteral("active"));
                service.insert(QStringLiteral("scope"), QStringLiteral("user"));
                service.insert(QStringLiteral("actionable"), true);
                userServices.push_back(service);
            }
            const bool filesSucceeded = filesStatus == QProcess::NormalExit && filesExitCode == 0;
            const bool userQuerySucceeded = unitsSucceeded || filesSucceeded;

            auto *systemUnitsProcess = new QProcess(this);
            systemUnitsProcess->setProgram(QStandardPaths::findExecutable(QStringLiteral("systemctl")));
            systemUnitsProcess->setArguments({
                QStringLiteral("list-units"),
                QStringLiteral("--type=service"),
                QStringLiteral("--all"),
                QStringLiteral("--plain"),
                QStringLiteral("--full"),
                QStringLiteral("--no-legend"),
                QStringLiteral("--no-pager"),
            });
            systemUnitsProcess->setStandardErrorFile(QProcess::nullDevice());

            connect(systemUnitsProcess, &QProcess::finished, this,
                    [this, systemUnitsProcess, userServices, userQuerySucceeded]
                    (int systemExitCode, QProcess::ExitStatus systemStatus) mutable {
                QVariantList combined = userServices;
                const bool systemQuerySucceeded =
                    systemStatus == QProcess::NormalExit && systemExitCode == 0;

                if (systemQuerySucceeded) {
                    const QList<QByteArray> rows = systemUnitsProcess->readAllStandardOutput().split('\n');
                    for (const QByteArray &rawRow : rows) {
                        const QByteArray row = rawRow.simplified();
                        if (row.isEmpty()) {
                            continue;
                        }
                        QList<QByteArray> fields = row.split(' ');
                        if (!fields.isEmpty() && !fields.constFirst().endsWith(".service")) {
                            fields.removeFirst();
                        }
                        if (fields.size() < 4) {
                            continue;
                        }

                        QByteArray descriptionBytes;
                        for (int fieldIndex = 4; fieldIndex < fields.size(); ++fieldIndex) {
                            if (!descriptionBytes.isEmpty()) {
                                descriptionBytes += ' ';
                            }
                            descriptionBytes += fields.at(fieldIndex);
                        }

                        const QString unit = QString::fromUtf8(fields.at(0));
                        const QString active = QString::fromUtf8(fields.at(2));
                        combined.push_back(QVariantMap{
                            {QStringLiteral("unit"), unit},
                            {QStringLiteral("description"), QString::fromUtf8(descriptionBytes)},
                            {QStringLiteral("loadState"), QString::fromUtf8(fields.at(1))},
                            {QStringLiteral("activeState"), active},
                            {QStringLiteral("subState"), QString::fromUtf8(fields.at(3))},
                            {QStringLiteral("enabledState"), QString()},
                            {QStringLiteral("running"), active == QStringLiteral("active")},
                            {QStringLiteral("scope"), QStringLiteral("system")},
                            {QStringLiteral("actionable"), false},
                        });
                    }
                }
                systemUnitsProcess->deleteLater();

                std::sort(combined.begin(), combined.end(), [](const QVariant &left, const QVariant &right) {
                    const QVariantMap a = left.toMap();
                    const QVariantMap b = right.toMap();
                    const QString aScope = a.value(QStringLiteral("scope")).toString();
                    const QString bScope = b.value(QStringLiteral("scope")).toString();
                    if (aScope != bScope) {
                        return aScope == QStringLiteral("user");
                    }
                    return a.value(QStringLiteral("unit")).toString()
                        .localeAwareCompare(b.value(QStringLiteral("unit")).toString()) < 0;
                });

                m_services = combined;
                m_servicesAvailable = userQuerySucceeded || systemQuerySucceeded;
                m_serviceQuerying = false;
                if (!m_servicesAvailable) {
                    setActionError(QStringLiteral("Could not query systemd services."));
                }
                Q_EMIT servicesChanged();
            });
            systemUnitsProcess->start();
            QTimer::singleShot(5000, systemUnitsProcess, [systemUnitsProcess]() {
                if (systemUnitsProcess->state() != QProcess::NotRunning) {
                    systemUnitsProcess->kill();
                }
            });
        });
        filesProcess->start();
        QTimer::singleShot(5000, filesProcess, [filesProcess]() {
            if (filesProcess->state() != QProcess::NotRunning) {
                filesProcess->kill();
            }
        });
    });
    unitsProcess->start();
    QTimer::singleShot(5000, unitsProcess, [unitsProcess]() {
        if (unitsProcess->state() != QProcess::NotRunning) {
            unitsProcess->kill();
        }
    });
}

void TaskManagerController::serviceAction(const QString &unit, const QString &action)
{
    static const QSet<QString> allowed{
        QStringLiteral("start"),
        QStringLiteral("stop"),
        QStringLiteral("restart"),
        QStringLiteral("enable"),
        QStringLiteral("disable"),
    };
    if (!safeUnitName(unit) || !allowed.contains(action)) {
        setActionError(QStringLiteral("Invalid service action."));
        return;
    }

    const QString systemctl = QStandardPaths::findExecutable(QStringLiteral("systemctl"));
    if (systemctl.isEmpty()) {
        setActionError(QStringLiteral("systemctl is unavailable."));
        return;
    }

    auto *process = new QProcess(this);
    process->setProgram(systemctl);
    process->setArguments({QStringLiteral("--user"), action, unit});
    connect(process, &QProcess::finished, this,
            [this, process, unit, action](int exitCode, QProcess::ExitStatus status) {
        if (status != QProcess::NormalExit || exitCode != 0) {
            QString error = QString::fromUtf8(process->readAllStandardError()).trimmed();
            if (error.isEmpty()) {
                error = QStringLiteral("systemctl exited with code %1").arg(exitCode);
            }
            setActionError(error);
        } else {
            setActionError({});
            Q_EMIT serviceActionCompleted(unit, action);
            refreshServices();
        }
        process->deleteLater();
    });
    process->start();
}

void TaskManagerController::clearActionError()
{
    setActionError({});
}

void TaskManagerController::setActionError(const QString &message)
{
    if (m_actionError == message) {
        return;
    }
    m_actionError = message;
    Q_EMIT actionErrorChanged();
}
