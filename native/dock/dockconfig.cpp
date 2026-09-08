#include "dockconfig.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QCoreApplication>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>

namespace
{
constexpr auto configFile = "meodockrc";

QStringList normalizedLaunchers(const QStringList &input)
{
    QStringList result;
    QSet<QString> seen;
    for (const QString &raw : input) {
        const QString launcher = raw.trimmed();
        if (!launcher.isEmpty() && !seen.contains(launcher)) {
            result.append(launcher);
            seen.insert(launcher);
        }
    }
    return result;
}

QStringList findLauncherList(const KConfigGroup &group)
{
    if (group.hasKey("launchers")) {
        const QStringList launchers = normalizedLaunchers(group.readEntry("launchers", QStringList{}));
        if (!launchers.isEmpty()) {
            return launchers;
        }
    }
    for (const QString &child : group.groupList()) {
        const QStringList launchers = findLauncherList(group.group(child));
        if (!launchers.isEmpty()) {
            return launchers;
        }
    }
    return {};
}
}

DockConfig::DockConfig(QObject *parent)
    : QObject(parent)
{
    m_launchBoostTimer = new QTimer(this);
    m_launchBoostTimer->setSingleShot(true);
    m_launchBoostTimer->setInterval(1800);
    connect(m_launchBoostTimer, &QTimer::timeout, this, &DockConfig::endLaunchBoost);
    reload();
}

QStringList DockConfig::launcherList() const
{
    return m_launcherList;
}

void DockConfig::setLauncherList(const QStringList &launchers)
{
    const QStringList normalized = normalizedLaunchers(launchers);
    if (normalized == m_launcherList) {
        return;
    }
    m_launcherList = normalized;
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    KConfigGroup(config, QStringLiteral("General")).writeEntry("Launchers", m_launcherList);
    config->sync();
    Q_EMIT launcherListChanged();
}

QString DockConfig::globalIconMode() const
{
    return m_globalIconMode;
}

void DockConfig::setGlobalIconMode(const QString &mode)
{
    const QString normalized = mode.trimmed().toLower();
    if (!isSupportedIconMode(normalized) || normalized == m_globalIconMode) {
        return;
    }
    m_globalIconMode = normalized;
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    KConfigGroup(config, QStringLiteral("General")).writeEntry("IconMode", normalized);
    config->sync();
    Q_EMIT globalIconModeChanged();
}

bool DockConfig::reduceMotion() const
{
    return m_reduceMotion;
}

bool DockConfig::shouldShow() const
{
    const auto shellConfig = KSharedConfig::openConfig(QStringLiteral("meo-shellrc"));
    const KConfigGroup panels(shellConfig, QStringLiteral("Panels"));
    return panels.readEntry("Mode", QStringLiteral("dual")) == QLatin1String("dual")
        && panels.readEntry("DockImplementation", QStringLiteral("standalone"))
               == QLatin1String("standalone");
}

QString DockConfig::iconModeFor(const QString &appId, const QUrl &launcherUrl) const
{
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    const QString key = configKeyForApplication(appId, launcherUrl);
    if (key.isEmpty()) {
        return m_globalIconMode;
    }
    const QString mode = KConfigGroup(config, QStringLiteral("IconOverrides"))
                             .readEntry(key, m_globalIconMode).trimmed().toLower();
    return isSupportedIconMode(mode) ? mode : m_globalIconMode;
}

void DockConfig::setIconModeFor(const QString &appId, const QUrl &launcherUrl,
                                const QString &mode)
{
    const QString key = configKeyForApplication(appId, launcherUrl);
    const QString normalized = mode.trimmed().toLower();
    if (key.isEmpty() || (!normalized.isEmpty() && !isSupportedIconMode(normalized))) {
        return;
    }
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    KConfigGroup overrides(config, QStringLiteral("IconOverrides"));
    if (normalized.isEmpty() || normalized == m_globalIconMode) {
        overrides.deleteEntry(key);
    } else {
        overrides.writeEntry(key, normalized);
    }
    config->sync();
    Q_EMIT iconOverridesChanged();
}

void DockConfig::activateLauncherMenu()
{
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
        QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("activateLauncherMenu"));
    QDBusConnection::sessionBus().asyncCall(message);
}

void DockConfig::setForegroundProcess(quint32 pid)
{
    if (pid == 0 || pid == m_lastForegroundPid) {
        return;
    }
    m_lastForegroundPid = pid;
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("com.system76.Scheduler"),
        QStringLiteral("/com/system76/Scheduler"),
        QStringLiteral("com.system76.Scheduler"),
        QStringLiteral("SetForegroundProcess"));
    message.setArguments({QVariant::fromValue(pid)});
    QDBusConnection::systemBus().asyncCall(message);
}

void DockConfig::beginLaunchBoost(const QString &applicationId)
{
    endLaunchBoost();
    const quint64 generation = ++m_launchBoostGeneration;
    m_launchBoostRequested = true;
    m_launchBoostTimer->start();

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
        QStringLiteral("/org/freedesktop/UPower/PowerProfiles"),
        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
        QStringLiteral("HoldProfile"));
    message.setArguments({QStringLiteral("performance"),
                          QStringLiteral("Meo Instant Launch"),
                          applicationId.left(128)});
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::systemBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, generation] {
                const QDBusPendingReply<quint32> reply = *watcher;
                watcher->deleteLater();
                if (reply.isError()) {
                    return;
                }
                const quint32 cookie = reply.value();
                if (!m_launchBoostRequested || generation != m_launchBoostGeneration) {
                    QDBusMessage release = QDBusMessage::createMethodCall(
                        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
                        QStringLiteral("/org/freedesktop/UPower/PowerProfiles"),
                        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
                        QStringLiteral("ReleaseProfile"));
                    release.setArguments({QVariant::fromValue(cookie)});
                    QDBusConnection::systemBus().asyncCall(release);
                } else {
                    m_profileHoldCookie = cookie;
                }
            });
}

void DockConfig::endLaunchBoost()
{
    m_launchBoostRequested = false;
    ++m_launchBoostGeneration;
    if (m_launchBoostTimer) {
        m_launchBoostTimer->stop();
    }
    if (m_profileHoldCookie == 0) {
        return;
    }
    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
        QStringLiteral("/org/freedesktop/UPower/PowerProfiles"),
        QStringLiteral("org.freedesktop.UPower.PowerProfiles"),
        QStringLiteral("ReleaseProfile"));
    message.setArguments({QVariant::fromValue(m_profileHoldCookie)});
    m_profileHoldCookie = 0;
    QDBusConnection::systemBus().asyncCall(message);
}

QVariantMap DockConfig::launchGeometryFor(const QString &applicationId) const
{
    const QString key = configKeyForApplication(applicationId, {});
    if (key.isEmpty()) {
        return {};
    }
    const auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    const KConfigGroup geometryGroup(config, QStringLiteral("LaunchGeometry"));
    const QRectF geometry = geometryGroup.readEntry(key, QRectF{});
    if (!geometry.isValid() || geometry.width() < 240 || geometry.height() < 160) {
        return {};
    }
    return {{QStringLiteral("x"), geometry.x()},
            {QStringLiteral("y"), geometry.y()},
            {QStringLiteral("width"), geometry.width()},
            {QStringLiteral("height"), geometry.height()}};
}

void DockConfig::rememberLaunchGeometry(const QString &applicationId,
                                        const QRectF &geometry)
{
    const QString key = configKeyForApplication(applicationId, {});
    if (key.isEmpty() || !geometry.isValid()
        || geometry.width() < 240 || geometry.height() < 160) {
        return;
    }
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    KConfigGroup geometryGroup(config, QStringLiteral("LaunchGeometry"));
    const QRectF previous = geometryGroup.readEntry(key, QRectF{});
    if (previous == geometry) {
        return;
    }
    geometryGroup.writeEntry(key, geometry);
    config->sync();
}

void DockConfig::reload()
{
    auto config = KSharedConfig::openConfig(QString::fromLatin1(configFile));
    config->reparseConfiguration();
    const KConfigGroup general(config, QStringLiteral("General"));
    QStringList launchers = normalizedLaunchers(general.readEntry("Launchers", QStringList{}));
    if (launchers.isEmpty()) {
        launchers = migratedLauncherList();
    }
    if (launchers.isEmpty()) {
        launchers = {
            QStringLiteral("applications:org.kde.dolphin.desktop"),
            QStringLiteral("applications:org.kde.konsole.desktop"),
            QStringLiteral("applications:org.meo.settings.desktop"),
        };
    }
    const QString mode = general.readEntry("IconMode", QStringLiteral("original")).trimmed().toLower();
    const bool nextReduceMotion = general.readEntry("ReduceMotion", false);

    if (launchers != m_launcherList) {
        m_launcherList = launchers;
        Q_EMIT launcherListChanged();
    }
    const QString nextMode = isSupportedIconMode(mode) ? mode : QStringLiteral("original");
    if (nextMode != m_globalIconMode) {
        m_globalIconMode = nextMode;
        Q_EMIT globalIconModeChanged();
    }
    if (nextReduceMotion != m_reduceMotion) {
        m_reduceMotion = nextReduceMotion;
        Q_EMIT reduceMotionChanged();
    }
    Q_EMIT iconOverridesChanged();
}

bool DockConfig::isSupportedIconMode(const QString &mode)
{
    return mode == QLatin1String("original") || mode == QLatin1String("tonal")
        || mode == QLatin1String("mono") || mode == QLatin1String("ai");
}

QString DockConfig::stableApplicationId(const QString &appId, const QUrl &launcherUrl)
{
    QString stable = appId.trimmed();
    if (stable.isEmpty() && launcherUrl.isValid()) {
        stable = launcherUrl.fileName();
        if (stable.isEmpty()) {
            stable = launcherUrl.toString(QUrl::FullyDecoded);
        }
    }
    if (stable.endsWith(QLatin1String(".desktop"))) {
        stable.chop(8);
    }
    return stable;
}

QString DockConfig::configKeyForApplication(const QString &appId, const QUrl &launcherUrl)
{
    return QString::fromLatin1(QUrl::toPercentEncoding(stableApplicationId(appId, launcherUrl)));
}

QStringList DockConfig::migratedLauncherList() const
{
    const QString plasmaConfig = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/plasma-org.kde.plasma.desktop-appletsrc");
    if (!QFileInfo::exists(plasmaConfig)) {
        return {};
    }
    const auto config = KSharedConfig::openConfig(plasmaConfig, KConfig::SimpleConfig);
    for (const QString &topLevelGroup : config->groupList()) {
        const QStringList launchers = findLauncherList(KConfigGroup(config, topLevelGroup));
        if (!launchers.isEmpty()) {
            return launchers;
        }
    }
    return {};
}

void DockConfig::Quit()
{
    QCoreApplication::quit();
}
