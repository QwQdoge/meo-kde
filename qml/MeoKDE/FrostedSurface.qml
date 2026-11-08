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
    // Over real blur the tint can be thinner: the backdrop is reduced to soft
    // colour, so only a faint hint of it shows through (the Pixel "frosted
    // glass" look). Without blur a thin tint would look like cheap
    // transparency, so it keeps the denser value above.
    property real blurredOpacity: MeoTheme.isDarkMode ? 0.70 : 0.74
    readonly property bool blurActive: MeoSystem.ShellAppearance.blur
    readonly property real surfaceOpacity: !MeoSystem.ShellAppearance.transparency ? 1.0
                                           : (blurActive ? blurredOpacity : translucentOpacity)

    radius: ShellMetrics.radiusPopup
    color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, surfaceOpacity)
    elevation: 3
    // A hairline edge keeps a blurred popup crisp against what is behind it.
    showOutline: blurActive
}
