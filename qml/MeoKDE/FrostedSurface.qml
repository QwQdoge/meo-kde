import QtQuick
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

MeoMotionSurface {
    id: root

    property color baseColor: MeoTheme.surfaceContainer
    // Popups are solid by default. With SurfaceTransparency enabled in
    // meo-shellrc they let a little of what is below show through (and, with
    // SurfaceBlur, the compositor blurs it); see Meo.System.ShellAppearance.
    property real translucentOpacity: MeoTheme.isDarkMode ? 0.86 : 0.88
    readonly property real surfaceOpacity: MeoSystem.ShellAppearance.transparency ? translucentOpacity : 1.0

    radius: ShellMetrics.radiusPopup
    color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, surfaceOpacity)
    elevation: 3
    showOutline: false
}
