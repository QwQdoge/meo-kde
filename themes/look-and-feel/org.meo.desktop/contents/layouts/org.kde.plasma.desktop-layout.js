// Meo Desktop Plasma Layout Specification
// KDE owns tasks, global menus and StatusNotifier integrations. MeoUI supplies
// the system menu, compact status controls and paired launcher/search surface.
var topPanel = new Panel
topPanel.location = "top"
// Googlebook OS keeps its status surfaces compact at the top edge. Keep Meo's
// bar equally quiet while preserving Plasma's native app-menu/tray backends.
topPanel.height = 32
topPanel.floating = false
topPanel.hiding = "none"
topPanel.currentConfigGroup = ["MeoShell"]
topPanel.writeConfig("Managed", true)
topPanel.writeConfig("Role", "top")

topPanel.addWidget("org.meo.systemmenu")
topPanel.addWidget("org.kde.plasma.appmenu")
topPanel.addWidget("org.kde.plasma.panelspacer")
// Preserve KDE's native StatusNotifier application icons and auxiliary tray
// applets. Meo owns network/audio/power and notification controls, so omit
// those duplicate compact representations from the tray's requested items.
var systemTray = topPanel.addWidget("org.kde.plasma.systemtray")
systemTray.currentConfigGroup = ["General"]
systemTray.writeConfig("extraItems", "org.kde.plasma.vault,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.keyboardindicator,org.kde.plasma.weather,org.kde.kscreen,org.kde.plasma.keyboardlayout,org.kde.plasma.printmanager")
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
var timeCenter = topPanel.addWidget("org.meo.time-notifications")
timeCenter.currentConfigGroup = ["Appearance"]
timeCenter.writeConfig("textScalePercent", 100)
timeCenter.writeConfig("showDate", true)
timeCenter.writeConfig("showNotifications", true)
timeCenter.writeConfig("use24HourClock", true)
timeCenter.reloadConfig()

// Googlebook OS keeps a compact dock centered at the bottom instead of
// painting a full-width taskbar. Plasma 6 exposes FitContent directly, so let
// the native IconTasks backend grow the dock with the running/pinned apps.
var shelf = new Panel
shelf.location = "bottom"
shelf.height = 64
shelf.floating = true
shelf.hiding = "none"
shelf.lengthMode = "fit"
shelf.alignment = "center"
shelf.currentConfigGroup = ["MeoShell"]
shelf.writeConfig("Managed", true)
shelf.writeConfig("Role", "dock")
var launcher = shelf.addWidget("org.meo.shelf")
launcher.currentConfigGroup = ["Shortcuts"]
launcher.writeConfig("global", "Meta")
launcher.reloadConfig()
var tasks = shelf.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("fill", false)
tasks.writeConfig("launchers", "applications:org.meo.settings.desktop,applications:omnistore.desktop,applications:org.kde.dolphin.desktop")
tasks.reloadConfig()

// Wallpaper setup
var existingDesktops = desktopsForActivity(currentActivity())
for (var i = 0; i < existingDesktops.length; ++i) {
    // A compact, desktop-only entry point to the Meo Widget Explorer. It
    // adds reviewed widgets to this containment but never configures panels,
    // task managers, or the native Dock.
    existingDesktops[i].addWidget("org.meo.widgetexplorer")
    existingDesktops[i].wallpaperPlugin = "org.kde.image"
    existingDesktops[i].currentConfigGroup = ["/Wallpaper/org.kde.image/General"]
    existingDesktops[i].writeConfig("Image", "file:///usr/share/wallpapers/MeoArch/installer_background.png")
    existingDesktops[i].writeConfig("FillMode", "2")
}
