#include "platformcontroller.h"

#include <KLocalizedString>
#include <KSharedConfig>
#include <KConfigGroup>
#include <QFile>
#include <QStandardPaths>
#include <QXmlStreamReader>
#include <QDBusConnectionInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <KSystemInhibitor>

#include <QDBusConnection>
#include <QDBusArgument>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QVariantMap>
#include <QProcess>
#include <QStandardPaths>
#include <QtGlobal>

namespace
{
constexpr auto brightnessService = "org.kde.ScreenBrightness";
constexpr auto brightnessPath = "/org/kde/ScreenBrightness";
constexpr auto brightnessInterface = "org.kde.ScreenBrightness";
constexpr auto brightnessDisplayInterface = "org.kde.ScreenBrightness.Display";
constexpr auto nightLightService = "org.kde.KWin.NightLight";
constexpr auto nightLightPath = "/org/kde/KWin/NightLight";
constexpr auto nightLightInterface = "org.kde.KWin.NightLight";
constexpr auto powerProfilesService = "org.freedesktop.UPower.PowerProfiles";
constexpr auto powerProfilesPath = "/org/freedesktop/UPower/PowerProfiles";
constexpr auto powerProfilesInterface = "org.freedesktop.UPower.PowerProfiles";

QVariant unwrap(const QVariant &value)
{
    return value.canConvert<QDBusVariant>() ? value.value<QDBusVariant>().variant() : value;
}
}

PlatformController::PlatformController(QObject *parent)
    : QObject(parent)
{
    auto sessionBus = QDBusConnection::sessionBus();
    sessionBus.connect(brightnessService, brightnessPath, brightnessInterface, "BrightnessChanged",
                       this, SLOT(refreshBrightness()));
    sessionBus.connect(brightnessService, brightnessPath, brightnessInterface, "DisplayAdded",
                       this, SLOT(refreshBrightness()));
    sessionBus.connect(brightnessService, brightnessPath, brightnessInterface, "DisplayRemoved",
                       this, SLOT(refreshBrightness()));
    sessionBus.connect(nightLightService, nightLightPath, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                       this, SLOT(refreshNightLight()));
    QDBusConnection::systemBus().connect(powerProfilesService, powerProfilesPath,
                                         "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                         this, SLOT(refreshPowerProfiles()));
    const auto screenLockConfig = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
    m_screenLockWatcher = KConfigWatcher::create(screenLockConfig);
    connect(m_screenLockWatcher.data(), &KConfigWatcher::configChanged, this,
        [this](const KConfigGroup &group, const QByteArrayList &) { if (group.name() == QStringLiteral("Daemon")) Q_EMIT screenLockPolicyChanged(); });
    auto *screenLockOwner = new QDBusServiceWatcher(QStringLiteral("org.kde.screensaver"), sessionBus,
        QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(screenLockOwner, &QDBusServiceWatcher::serviceOwnerChanged, this, &PlatformController::screenLockPolicyChanged);
    m_nightLightWatcher = KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("kwinrc")));
    connect(m_nightLightWatcher.data(), &KConfigWatcher::configChanged, this,
        [this](const KConfigGroup &group, const QByteArrayList &) {
            if (group.name() == QStringLiteral("NightColor")) { refreshNightLight(); Q_EMIT nightLightChanged(); }
        });
    refreshBrightness();
    refreshNightLight();
    refreshPowerProfiles();
}

bool PlatformController::brightnessAvailable() const { return !m_brightnessDisplays.isEmpty(); }
QVariantList PlatformController::brightnessDisplays() const { return m_brightnessDisplays; }
bool PlatformController::nightLightAvailable() const { return m_nightLightAvailable; }
bool PlatformController::nightLightEnabled() const { return m_nightLightEnabled; }
bool PlatformController::nightLightRunning() const { return m_nightLightRunning; }
int PlatformController::nightLightTemperature() const { return m_nightLightTemperature; }
bool PlatformController::powerProfilesAvailable() const { return !m_powerProfiles.isEmpty(); }
QStringList PlatformController::powerProfiles() const { return m_powerProfiles; }
QString PlatformController::activePowerProfile() const { return m_activePowerProfile; }
QString PlatformController::powerProfileDegradedReason() const { return m_powerProfileDegradedReason; }
bool PlatformController::keepAwake() const { return m_keepAwakeInhibitor != nullptr; }
QString PlatformController::lastError() const { return m_lastError; }

void PlatformController::refreshBrightness()
{
    QDBusInterface root(brightnessService, brightnessPath, brightnessInterface, QDBusConnection::sessionBus());
    const auto ids = root.property("DisplaysDBusNames").toStringList();
    QVariantList displays;
    for (const auto &id : ids) {
        QDBusInterface display(brightnessService, QString::fromLatin1(brightnessPath) + '/' + id,
                               brightnessDisplayInterface, QDBusConnection::sessionBus());
        const int maximum = display.property("MaxBrightness").toInt();
        if (!display.isValid() || maximum <= 0) continue;
        displays.push_back(QVariantMap{{"id", id}, {"label", display.property("Label").toString()},
                                       {"brightness", display.property("Brightness").toInt()},
                                       {"maximum", maximum}, {"internal", display.property("IsInternal").toBool()}});
    }
    if (m_brightnessDisplays != displays) { m_brightnessDisplays = displays; Q_EMIT brightnessChanged(); }
}

void PlatformController::setBrightness(const QString &displayId, int brightness)
{
    for (const auto &entry : m_brightnessDisplays) {
        const auto display = entry.toMap();
        if (display.value("id").toString() != displayId) continue;
        QDBusInterface iface(brightnessService, QString::fromLatin1(brightnessPath) + '/' + displayId,
                             brightnessDisplayInterface, QDBusConnection::sessionBus());
        iface.asyncCall("SetBrightnessWithContext", qBound(0, brightness, display.value("maximum").toInt()),
                        static_cast<uint>(0), QStringLiteral("org.meo.quicksettings"));
        return;
    }
    setError(i18nd("meo-desktop", "Brightness display is no longer available."));
}

void PlatformController::refreshNightLight()
{
    QDBusInterface iface(nightLightService, nightLightPath, nightLightInterface, QDBusConnection::sessionBus());
    const bool available = iface.isValid() && iface.property("available").toBool();
    const bool enabled = available && iface.property("enabled").toBool();
    const bool running = available && iface.property("running").toBool();
    const int temperature = available ? iface.property("currentTemperature").toInt() : 0;
    if (m_nightLightAvailable != available || m_nightLightEnabled != enabled || m_nightLightRunning != running || m_nightLightTemperature != temperature) {
        m_nightLightAvailable = available; m_nightLightEnabled = enabled; m_nightLightRunning = running; m_nightLightTemperature = temperature;
        Q_EMIT nightLightChanged();
    }
}

QVariantMap PlatformController::nightLightSettings() const
{
    // KWin 6.7 uses the shared dark/light scheduler. Older versions used a
    // different Mode enum: never interpret their numeric values as this one.
    const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("config.kcfg/nightlightsettings.kcfg"));
    QFile schema(path); QStringList choices;
    if (schema.open(QIODevice::ReadOnly)) {
        QXmlStreamReader xml(&schema);
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement() && xml.name() == QStringLiteral("choice")) choices.append(xml.attributes().value("name").toString());
        }
        if (xml.hasError()) choices.clear();
    }
    if (choices != QStringList{QStringLiteral("Constant"), QStringLiteral("DarkLight")}) return {};
    const auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc")); config->reparseConfiguration();
    const auto group = config->group(QStringLiteral("NightColor"));
    const QString configuredMode = group.readEntry("Mode", QStringLiteral("DarkLight"));
    const int mode = configuredMode == QStringLiteral("Constant") || configuredMode == QStringLiteral("0") ? 0 : 1;
    return {{"mode", mode}, {"dayTemperature", group.readEntry("DayTemperature", 6500)},
        {"nightTemperature", group.readEntry("NightTemperature", 4500)}};
}

void PlatformController::setNightLightEnabled(bool enabled)
{
    if (!nightLightAvailable()) { setError(i18nd("meo-desktop", "Night Light is unavailable.")); return; }
    // The DBus enabled property is read-only. KWin watches its KConfig owner.
    const auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    config->group(QStringLiteral("NightColor")).writeEntry("Active", enabled, KConfig::Notify);
    if (!config->sync()) { setError(i18nd("meo-desktop", "Could not save Night Light.")); return; }
    clearError();
}

void PlatformController::configureNightLight(int mode, int dayTemperature, int nightTemperature)
{
    if (!nightLightAvailable() || nightLightSettings().isEmpty() || (mode != 0 && mode != 1)
        || dayTemperature < 1000 || dayTemperature > 6500 || nightTemperature < 1000 || nightTemperature > 6500) {
        setError(i18nd("meo-desktop", "Choose a supported Night Light mode and temperatures between 1000 and 6500 K.")); return;
    }
    const auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    auto group = config->group(QStringLiteral("NightColor"));
    group.writeEntry("Mode", mode == 0 ? QStringLiteral("Constant") : QStringLiteral("DarkLight"), KConfig::Notify);
    group.writeEntry("DayTemperature", dayTemperature, KConfig::Notify);
    group.writeEntry("NightTemperature", nightTemperature, KConfig::Notify);
    if (!config->sync()) { setError(i18nd("meo-desktop", "Could not save Night Light.")); return; }
    clearError();
}

void PlatformController::refreshPowerProfiles()
{
    QDBusInterface iface(powerProfilesService, powerProfilesPath, powerProfilesInterface, QDBusConnection::systemBus());
    const QString active = iface.property("ActiveProfile").toString();
    const QString degraded = iface.property("PerformanceDegraded").toString();
    QStringList profiles;
    QDBusInterface properties(powerProfilesService, powerProfilesPath, "org.freedesktop.DBus.Properties",
                              QDBusConnection::systemBus());
    const QDBusReply<QDBusVariant> profilesReply = properties.call(
        "Get", QString::fromLatin1(powerProfilesInterface), QStringLiteral("Profiles"));
    const auto profilesValue = profilesReply.isValid() ? profilesReply.value().variant() : QVariant{};
    for (const auto &entry : profilesValue.toList()) {
        const auto profile = unwrap(entry).toMap().value("Profile").toString();
        if (!profile.isEmpty()) profiles.push_back(profile);
    }
    if (profiles.isEmpty() && profilesValue.canConvert<QDBusArgument>()) {
        QDBusArgument argument = profilesValue.value<QDBusArgument>();
        argument.beginArray();
        while (!argument.atEnd()) {
            QVariantMap map;
            argument >> map;
            const auto profile = map.value("Profile").toString();
            if (!profile.isEmpty()) profiles.push_back(profile);
        }
        argument.endArray();
    }
    if (m_powerProfiles != profiles || m_activePowerProfile != active || m_powerProfileDegradedReason != degraded) {
        m_powerProfiles = profiles; m_activePowerProfile = active; m_powerProfileDegradedReason = degraded;
        Q_EMIT powerProfilesChanged();
    }
}

void PlatformController::setActivePowerProfile(const QString &profile)
{
    if (!m_powerProfiles.contains(profile)) { setError(i18nd("meo-desktop", "Power profile is unavailable.")); return; }
    QDBusInterface properties(powerProfilesService, powerProfilesPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    properties.asyncCall("Set", QString::fromLatin1(powerProfilesInterface), QStringLiteral("ActiveProfile"), QVariant::fromValue(QDBusVariant(profile)));
}

void PlatformController::setKeepAwake(bool enabled)
{
    if (enabled == keepAwake()) return;
    if (enabled) m_keepAwakeInhibitor = new KSystemInhibitor(
        i18nd("meo-desktop", "Keep Awake"), KSystemInhibitor::Types(KSystemInhibitor::Type::Idle) | KSystemInhibitor::Type::Suspend,
        nullptr, this);
    else { delete m_keepAwakeInhibitor; m_keepAwakeInhibitor = nullptr; }
    Q_EMIT keepAwakeChanged();
}

void PlatformController::lockScreen()
{
    QDBusInterface iface("org.kde.screensaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", QDBusConnection::sessionBus());
    if (!iface.isValid()) { setError(i18nd("meo-desktop", "Screen locking service is unavailable.")); return; }
    iface.asyncCall("Lock");
}

void PlatformController::clearError() { setError({}); }
void PlatformController::setError(const QString &error) { if (m_lastError != error) { m_lastError = error; Q_EMIT errorChanged(); } }

// Fixed, unprivileged desktop entry points. No caller-supplied executable or
// arguments cross the QML boundary.
bool PlatformController::openSystemAbout()
{
    const auto meo = QStandardPaths::findExecutable(QStringLiteral("meo-settings"));
    const bool started = !meo.isEmpty()
        ? QProcess::startDetached(meo, {QStringLiteral("--route"), QStringLiteral("about")})
        : QProcess::startDetached(QStringLiteral("systemsettings"), {QStringLiteral("kcm_about-distro")});
    if (!started) setError(i18n("Could not open system information."));
    return started;
}

bool PlatformController::openTaskManager()
{
    const auto meo = QStandardPaths::findExecutable(QStringLiteral("meo-system-monitor"));
    const bool started = QProcess::startDetached(meo.isEmpty()
        ? QStringLiteral("plasma-systemmonitor") : meo, QStringList{});
    if (!started) setError(i18n("Could not open the task manager."));
    return started;
}

QVariantMap PlatformController::screenLockPolicy() const
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc")); config->reparseConfiguration();
    const auto group = config->group(QStringLiteral("Daemon"));
    bool writable = true;
    for (const char *key : {"Autolock", "Timeout", "LockOnResume", "LockOnStart", "LockGrace"}) writable &= !group.isEntryImmutable(key);
    auto *bus = QDBusConnection::sessionBus().interface();
    return {{"available", bus && bus->isServiceRegistered(QStringLiteral("org.kde.screensaver"))}, {"writable", writable},
        {"automatic", group.readEntry("Autolock", true)}, {"minutes", group.readEntry("Timeout", 5.0)},
        {"onResume", group.readEntry("LockOnResume", true)}, {"onStart", group.readEntry("LockOnStart", false)},
        {"graceSeconds", group.readEntry("LockGrace", 5)}, {"passwordRequired", group.readEntry("RequirePassword", true)},
        {"lockAfterGrace", group.readEntry("Lock", true)}};
}

void PlatformController::configureScreenLock(bool automatic, qreal minutes, bool onResume, bool onStart, int graceSeconds)
{
    if (m_screenLockPolicyBusy) return;
    const auto policy = screenLockPolicy();
    if (!policy.value("available").toBool() || !policy.value("writable").toBool()
        || !qIsFinite(minutes) || minutes < 0.1 || minutes > 240 || graceSeconds < 0 || graceSeconds > 300) {
        setError(i18nd("meo-desktop", "Choose an available screen locker, idle time from 0.1 to 240 minutes, and grace time from 0 to 300 seconds.")); return;
    }
    const auto config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
    auto group = config->group(QStringLiteral("Daemon"));
    const QVariantMap values{{"Autolock", automatic}, {"Timeout", double(minutes)},
        {"LockOnResume", onResume}, {"LockOnStart", onStart}, {"LockGrace", graceSeconds}};
    QVariantMap previous;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        if (group.hasKey(it.key())) previous.insert(it.key(), group.readEntry(it.key(), QString()));
    }
    const auto restore = [config, values, previous] {
        auto settings = config->group(QStringLiteral("Daemon"));
        for (auto it = values.cbegin(); it != values.cend(); ++it) {
            if (previous.contains(it.key())) settings.writeEntry(it.key(), previous.value(it.key()), KConfig::Notify);
            else settings.deleteEntry(it.key(), KConfig::Notify);
        }
        return config->sync();
    };
    for (auto it = values.cbegin(); it != values.cend(); ++it) group.writeEntry(it.key(), it.value(), KConfig::Notify);
    if (!config->sync()) {
        const bool restored = restore();
        setError(restored ? i18nd("meo-desktop", "Screen lock preferences could not be saved; the previous configuration was restored.")
                          : i18nd("meo-desktop", "Screen lock preferences and recovery could not be saved. Check configuration permissions.")); return;
    }
    m_screenLockPolicyBusy = true; clearError(); Q_EMIT screenLockPolicyChanged();
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.screensaver"), QStringLiteral("/ScreenSaver"),
        QStringLiteral("org.kde.screensaver"), QStringLiteral("configure"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 5000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, message, restore](QDBusPendingCallWatcher *finished) {
        const QDBusPendingReply<> reply = *finished; finished->deleteLater();
        if (reply.isError()) {
            const bool restored = restore();
            if (restored) QDBusConnection::sessionBus().asyncCall(message, 5000);
            setError(restored ? i18nd("meo-desktop", "The screen locker did not confirm the change. Previous preferences were restored: %1", reply.error().message())
                              : i18nd("meo-desktop", "Screen lock recovery failed. Check the advanced screen lock settings: %1", reply.error().message()));
        }
        m_screenLockPolicyBusy = false; Q_EMIT screenLockPolicyChanged();
    });
}
