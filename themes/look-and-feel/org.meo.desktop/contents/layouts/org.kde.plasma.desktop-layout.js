// Meo Desktop Plasma Layout Specification
//
// This is the canonical default layout. KDE applets retain launching, task,
// menu and StatusNotifier behaviour; Meo applets contribute only the two MD3
// surfaces whose generic controls and tokens are implemented in MeoUI.
// Top launcher/status panel.  Kickoff keeps Plasma's canonical Meta action and
// search/provider integrations; the Meo applet owns only the MD3 status and
// quick-settings surface.
var topPanel = new Panel
topPanel.location = "top"
topPanel.height = 40
topPanel.floating = false
topPanel.hiding = "none"
topPanel.currentConfigGroup = ["MeoShell"]
topPanel.writeConfig("Managed", true)
topPanel.writeConfig("Role", "top")

var launcher = topPanel.addWidget("org.kde.plasma.kickoff")
launcher.currentConfigGroup = ["Shortcuts"]
launcher.writeConfig("global", "Meta")
launcher.reloadConfig()
topPanel.addWidget("org.kde.plasma.appmenu")
topPanel.addWidget("org.kde.plasma.panelspacer")
// Preserve KDE's native StatusNotifier application icons and auxiliary tray
// applets. Meo owns network/audio/power and notification controls, so omit
// those duplicate compact representations from the tray's requested items.
var systemTray = topPanel.addWidget("org.kde.plasma.systemtray")
systemTray.currentConfigGroup = ["General"]
systemTray.writeConfig("extraItems", "org.kde.kdeconnect,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.keyboardindicator,org.kde.plasma.weather,org.kde.kscreen,org.kde.plasma.keyboardlayout,org.kde.plasma.vault,org.kde.plasma.printmanager")
systemTray.writeConfig("hiddenItems", "org.kde.plasma.devicenotifier,org.kde.plasma.networkmanagement,org.kde.plasma.bluetooth,org.kde.plasma.volume,org.kde.plasma.battery,org.kde.plasma.brightness,org.kde.plasma.mediacontroller,org.kde.plasma.notifications")
systemTray.reloadConfig()
var quickSettings = topPanel.addWidget("org.meo.topbar")
quickSettings.currentConfigGroup = ["Appearance"]
quickSettings.writeConfig("textScalePercent", 100)
quickSettings.writeConfig("showNetwork", true)
quickSettings.writeConfig("showBluetooth", true)
quickSettings.writeConfig("showVolume", true)
quickSettings.writeConfig("batteryDisplay", 2)
quickSettings.writeConfig("showDate", true)
quickSettings.writeConfig("showNotifications", true)
quickSettings.writeConfig("use24HourClock", true)
quickSettings.writeConfig("quickTileVisibility", "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot")
quickSettings.writeConfig("quickTileDensity", "comfortable")
quickSettings.reloadConfig()
var timeCenter = topPanel.addWidget("org.meo.timecenter")
timeCenter.currentConfigGroup = ["Appearance"]
timeCenter.writeConfig("textScalePercent", 100)
timeCenter.writeConfig("showDate", true)
timeCenter.writeConfig("showNotifications", true)
timeCenter.writeConfig("use24HourClock", true)
timeCenter.reloadConfig()

// Bottom application Dock. Icons-Only Task Manager remains the source of
// truth for pinned launchers, grouping, previews, window actions and per-user
// task settings. Autohide reveals it from the screen bottom and retracts once
// an application needs the space.
var bottomPanel = new Panel
bottomPanel.location = "bottom"
bottomPanel.height = 56
bottomPanel.floating = true
bottomPanel.hiding = "autohide"
bottomPanel.lengthMode = "fit"
bottomPanel.alignment = "center"
bottomPanel.currentConfigGroup = ["MeoShell"]
bottomPanel.writeConfig("Managed", true)
bottomPanel.writeConfig("Role", "dock")

bottomPanel.addWidget("org.kde.plasma.icontasks")

// Wallpaper setup
var existingDesktops = desktopsForActivity(currentActivity())
for (var i = 0; i < existingDesktops.length; ++i) {
    existingDesktops[i].wallpaperPlugin = "org.kde.image"
    existingDesktops[i].currentConfigGroup = ["/Wallpaper/org.kde.image/General"]
    existingDesktops[i].writeConfig("Image", "file:///usr/share/wallpapers/MeoArch/installer_background.png")
    existingDesktops[i].writeConfig("FillMode", "2")
}
