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

    readonly property real radiusWindow: MeoTheme.shapeLarge
    readonly property real radiusPopup: MeoTheme.shapeExtraLarge
    readonly property real radiusLarge: MeoTheme.shapeLargeIncreased
    readonly property real radiusMedium: MeoTheme.shapeLarge
    readonly property real radiusControl: MeoTheme.shapeMedium
    readonly property real radiusSmall: MeoTheme.shapeSmall

    readonly property real desktopHitTarget: 44 * MeoTheme.globalScale
    readonly property real panelOutlineWidth: MeoTheme.strokeWidthThin
}
