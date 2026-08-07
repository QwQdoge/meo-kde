pragma Singleton
import QtQuick
import MeoUI 1.0

QtObject {
    readonly property real topBarHeight: 40 * MeoTheme.globalScale
    readonly property real screenMargin: 20 * MeoTheme.globalScale
    readonly property real popupGap: 12 * MeoTheme.globalScale

    readonly property real launcherWidth: 420 * MeoTheme.globalScale
    readonly property real launcherMaxHeight: 520 * MeoTheme.globalScale
    readonly property real launcherSearchHeight: 44 * MeoTheme.globalScale
    readonly property real quickSettingsWidth: 372 * MeoTheme.globalScale

    readonly property real shelfPanelHeight: 68 * MeoTheme.globalScale
    readonly property real shelfSurfaceHeight: 56 * MeoTheme.globalScale
    readonly property real shelfBottomMargin: 12 * MeoTheme.globalScale
    readonly property real shelfItemSize: 44 * MeoTheme.globalScale
    readonly property real shelfIconSize: 24 * MeoTheme.globalScale

    readonly property real appDelegateWidth: 68 * MeoTheme.globalScale
    readonly property real appDelegateHeight: 76 * MeoTheme.globalScale
    readonly property real appIconSize: 32 * MeoTheme.globalScale
    readonly property real statusIconSize: 24 * MeoTheme.globalScale

    readonly property real radiusWindow: 18 * MeoTheme.globalScale
    readonly property real radiusPopup: 24 * MeoTheme.globalScale
    readonly property real radiusLarge: 18 * MeoTheme.globalScale
    readonly property real radiusMedium: 16 * MeoTheme.globalScale
    readonly property real radiusControl: 12 * MeoTheme.globalScale
    readonly property real radiusSmall: 10 * MeoTheme.globalScale

    readonly property real desktopHitTarget: 44 * MeoTheme.globalScale
    readonly property real panelOutlineWidth: Math.max(1, MeoTheme.globalScale)
}
