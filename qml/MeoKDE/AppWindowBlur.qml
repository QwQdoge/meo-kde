import QtQuick
import Meo.System 1.0 as MeoSystem

// Asks the compositor to blur what is behind a native Meo application window,
// but only when the user opted in (SurfaceBlur in meo-shellrc). Give the
// window a translucent background with MeoTheme.windowBackground so the blur
// shows. Place it inside the application's root Window.
MeoSystem.WindowBlur {
    id: root

    required property var window

    enabled: MeoSystem.ShellAppearance.blur
    rect: window ? Qt.rect(0, 0, window.width, window.height) : Qt.rect(0, 0, 0, 0)
}
