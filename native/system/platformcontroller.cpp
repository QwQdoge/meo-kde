#include "platformcontroller.h"

#include <KSystemInhibitor>

#include <QDBusConnection>
#include <QDBusArgument>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QVariantMap>
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
    setError(tr("Brightness display is no longer available."));
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

void PlatformController::setNightLightEnabled(bool enabled)
{
    QDBusInterface properties(nightLightService, nightLightPath, "org.freedesktop.DBus.Properties", QDBusConnection::sessionBus());
    properties.asyncCall("Set", QString::fromLatin1(nightLightInterface), QStringLiteral("enabled"), QVariant::fromValue(QDBusVariant(enabled)));
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
    if (!m_powerProfiles.contains(profile)) { setError(tr("Power profile is unavailable.")); return; }
    QDBusInterface properties(powerProfilesService, powerProfilesPath, "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    properties.asyncCall("Set", QString::fromLatin1(powerProfilesInterface), QStringLiteral("ActiveProfile"), QVariant::fromValue(QDBusVariant(profile)));
}

void PlatformController::setKeepAwake(bool enabled)
{
    if (enabled == keepAwake()) return;
    if (enabled) m_keepAwakeInhibitor = new KSystemInhibitor(
        tr("Keep Awake"), KSystemInhibitor::Types(KSystemInhibitor::Type::Idle) | KSystemInhibitor::Type::Suspend,
        nullptr, this);
    else { delete m_keepAwakeInhibitor; m_keepAwakeInhibitor = nullptr; }
    Q_EMIT keepAwakeChanged();
}

void PlatformController::lockScreen()
{
    QDBusInterface iface("org.kde.screensaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", QDBusConnection::sessionBus());
    if (!iface.isValid()) { setError(tr("Screen locking service is unavailable.")); return; }
    iface.asyncCall("Lock");
}

void PlatformController::clearError() { setError({}); }
void PlatformController::setError(const QString &error) { if (m_lastError != error) { m_lastError = error; Q_EMIT errorChanged(); } }
