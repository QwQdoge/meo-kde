// Meo Desktop Plasma Layout Specification
//
// Deliberately composed only from first-party Plasma applets.  Theme packages
// provide appearance; launching, task management, menus and status handling
// stay in the KDE components that already own those behaviours.
// Top global-menu/status panel
var topPanel = new Panel
topPanel.location = "top"
topPanel.height = 36
topPanel.floating = false
topPanel.hiding = "none"

topPanel.addWidget("org.kde.plasma.appmenu")
topPanel.addWidget("org.kde.plasma.panelspacer")
topPanel.addWidget("org.kde.plasma.systemtray")
topPanel.addWidget("org.kde.plasma.digitalclock")

// Bottom application panel. Kickoff provides Plasma's canonical Meta action;
// Icons-Only Task Manager provides pinning, grouping, previews and window
// actions without recreating them in QML.
var bottomPanel = new Panel
bottomPanel.location = "bottom"
bottomPanel.height = 48
bottomPanel.floating = false
bottomPanel.hiding = "none"

bottomPanel.addWidget("org.kde.plasma.kickoff")
bottomPanel.addWidget("org.kde.plasma.icontasks")
bottomPanel.addWidget("org.kde.plasma.marginsseparator")
bottomPanel.addWidget("org.kde.plasma.showdesktop")

// Wallpaper setup
var existingDesktops = desktopsForActivity(currentActivity())
for (var i = 0; i < existingDesktops.length; ++i) {
    existingDesktops[i].wallpaperPlugin = "org.kde.image"
    existingDesktops[i].currentConfigGroup = ["/Wallpaper/org.kde.image/General"]
    existingDesktops[i].writeConfig("Image", "file:///usr/share/wallpapers/MeoArch/installer_background.png")
    existingDesktops[i].writeConfig("FillMode", "2")
}
