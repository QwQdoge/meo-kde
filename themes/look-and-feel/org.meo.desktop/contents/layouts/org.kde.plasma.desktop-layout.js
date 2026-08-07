// Meo Desktop Plasma Layout Specification
// Top Context Bar Panel
var topPanel = new Panel
topPanel.location = "top"
topPanel.height = 40
topPanel.floating = false
topPanel.hiding = "none"

topPanel.addWidget("org.meo.topbar")
topPanel.addWidget("org.kde.plasma.systemtray")

// Bottom Shelf Panel
var bottomPanel = new Panel
bottomPanel.location = "bottom"
bottomPanel.height = 68
bottomPanel.floating = true
bottomPanel.hiding = "dodgewindows"

bottomPanel.addWidget("org.meo.shelf")

// Wallpaper setup
var existingDesktops = desktopsForActivity(currentActivity())
for (var i = 0; i < existingDesktops.length; ++i) {
    existingDesktops[i].wallpaperPlugin = "org.kde.image"
    existingDesktops[i].currentConfigGroup = ["/Wallpaper/org.kde.image/General"]
    existingDesktops[i].writeConfig("Image", "file:///usr/share/wallpapers/MeoArch/installer_background.png")
    existingDesktops[i].writeConfig("FillMode", "2")
}
