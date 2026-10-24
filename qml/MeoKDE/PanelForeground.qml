import QtQuick
import QtQuick.Window
import Meo.System 1.0 as MeoSystem

// Black or white content color for a surface that sits on the transparent
// top panel, chosen from the wallpaper pixels directly behind `target`.
//
// - Placed under a trigger/label; `color` is the only output.
// - An opaque panel (for example the black bar shown while a window covers the
//   output) is judged by its own window color instead of the wallpaper.
// - The wallpaper answer comes from the native cached sampler; this item only
//   asks again after the wallpaper, geometry or panel color change, coalesced
//   by a timer. It never captures the screen and has no per-frame work.
// - With no readable local wallpaper the theme-derived foreground is kept.
Item {
    id: root

    property Item target: parent
    // Test/preview override; production leaves this empty (desktop wallpaper).
    property string imagePath: ""
    readonly property bool preferDark: resolvedDark
    readonly property color color: preferDark ? Qt.alpha("black", 0.88) : "white"

    readonly property bool fallbackDark: MeoShellTheme.luminance(MeoShellTheme.panelForeground) > 0.5
    property bool resolvedDark: fallbackDark

    visible: false
    width: 0
    height: 0

    readonly property var panelWindow: target ? target.Window.window : null
    readonly property var contrast: typeof MeoSystem.WallpaperContrast === "undefined"
                                    ? null : MeoSystem.WallpaperContrast

    function refresh() {
        const win = panelWindow
        if (!win || !target || target.width <= 0 || target.height <= 0 || !win.screen) {
            resolvedDark = fallbackDark
            return
        }
        const own = win.color
        if (own && own.a > 0.5) {
            resolvedDark = MeoShellTheme.luminance(own) > 0.25
            return
        }
        if (!contrast) {
            resolvedDark = fallbackDark
            return
        }
        const screen = win.screen
        const origin = target.mapToItem(null, 0, 0)
        resolvedDark = contrast.prefersDarkForeground(
                    win.x - screen.virtualX + origin.x,
                    win.y - screen.virtualY + origin.y,
                    target.width, target.height,
                    screen.width, screen.height, fallbackDark, imagePath)
    }

    Timer {
        id: coalesce
        interval: 120
        onTriggered: root.refresh()
    }
    function schedule() { coalesce.restart() }

    Behavior on resolvedDark { enabled: false }

    onFallbackDarkChanged: schedule()
    onPanelWindowChanged: schedule()
    Component.onCompleted: schedule()

    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onWidthChanged() { root.schedule() }
        function onHeightChanged() { root.schedule() }
        function onXChanged() { root.schedule() }
        function onVisibleChanged() { root.schedule() }
    }
    Connections {
        target: root.panelWindow
        ignoreUnknownSignals: true
        function onColorChanged() { root.schedule() }
        function onXChanged() { root.schedule() }
        function onYChanged() { root.schedule() }
        function onScreenChanged() { root.schedule() }
        function onWidthChanged() { root.schedule() }
    }
    Connections {
        target: root.contrast
        ignoreUnknownSignals: true
        function onChanged() { root.schedule() }
    }
}
