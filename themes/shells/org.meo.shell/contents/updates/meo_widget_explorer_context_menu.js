// The Meo widget browser now opens from the desktop right-click menu
// ("Add or Manage Widgets…"). Remove the desktop button that earlier Meo
// layouts placed in the top-left corner. Runs once per user.
var allDesktops = desktops()
for (var i = 0; i < allDesktops.length; ++i) {
    var buttons = allDesktops[i].widgets("org.meo.widgetexplorer")
    for (var j = 0; j < buttons.length; ++j) {
        buttons[j].remove()
    }
}
