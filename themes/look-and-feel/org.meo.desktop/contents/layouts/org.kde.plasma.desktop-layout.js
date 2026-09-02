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
// Keep the initial panel aligned with the compact Meo status controls. Plasma
// adds its own framing around this value, so the former 40 px request produced
// an unnecessarily tall top bar on a 1x output.
topPanel.height = 32
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

// org.meo.dock starts as an independent Layer Shell surface. It owns the
// floating capsule geometry, rounded blur region and continuous magnification
// input, while KDE TaskManager remains the source of real launchers/windows.
// A native Icons-Only Task Manager panel remains available through
// Panels/DockImplementation=native for recovery and compatibility.

// Wallpaper setup
var existingDesktops = desktopsForActivity(currentActivity())
for (var i = 0; i < existingDesktops.length; ++i) {
    existingDesktops[i].wallpaperPlugin = "org.kde.image"
    existingDesktops[i].currentConfigGroup = ["/Wallpaper/org.kde.image/General"]
    existingDesktops[i].writeConfig("Image", "file:///usr/share/wallpapers/MeoArch/installer_background.png")
    existingDesktops[i].writeConfig("FillMode", "2")
}
