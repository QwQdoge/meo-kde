import QtQuick
import MeoUI 1.0

MeoMotionSurface {
    id: root

    property color baseColor: MeoTheme.surfaceContainer
    property real translucentOpacity: MeoTheme.isDarkMode ? 0.76 : 0.82
    readonly property real surfaceOpacity: MeoTheme.transparencyEnabled ? translucentOpacity : 1.0

    radius: ShellMetrics.radiusPopup
    color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, surfaceOpacity)
    elevation: 3
}
