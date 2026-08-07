import QtQuick
import MeoUI 1.0

Rectangle {
    id: root

    property color baseColor: MeoTheme.surfaceContainer
    property real surfaceOpacity: MeoTheme.isDarkMode ? 0.76 : 0.82

    radius: ShellMetrics.radiusPopup
    color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, surfaceOpacity)
    border.width: ShellMetrics.panelOutlineWidth
    border.color: Qt.rgba(MeoTheme.outlineVariant.r,
                         MeoTheme.outlineVariant.g,
                         MeoTheme.outlineVariant.b,
                         MeoTheme.isDarkMode ? 0.30 : 0.45)
}
