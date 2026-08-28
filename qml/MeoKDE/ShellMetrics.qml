pragma Singleton
import QtQuick
import MeoUI 1.0

QtObject {
    readonly property real topBarHeight: 32 * MeoTheme.globalScale
    readonly property real screenMargin: 20 * MeoTheme.globalScale
    readonly property real popupGap: 12 * MeoTheme.globalScale
    readonly property real popupContentMargin: 20 * MeoTheme.globalScale
    readonly property real popupSectionSpacing: 16 * MeoTheme.globalScale
    readonly property real popupItemSpacing: 8 * MeoTheme.globalScale
    readonly property real popupHeaderHeight: 48 * MeoTheme.globalScale

    readonly property real launcherWidth: 420 * MeoTheme.globalScale
    readonly property real launcherMaxHeight: 520 * MeoTheme.globalScale
    readonly property real launcherSearchHeight: 44 * MeoTheme.globalScale
    readonly property real quickSettingsWidth: 392 * MeoTheme.globalScale
    readonly property real quickSettingsHeight: 680 * MeoTheme.globalScale
    readonly property real quickSettingsTileHeight: 72 * MeoTheme.globalScale
    // Keep the time and notification surface compact by default. The
    // responsive view still supports wider hosts, but the panel popup should
    // not reopen as a desktop-sized two-column surface after a shell refresh.
    readonly property real statusCenterWidth: 760 * MeoTheme.globalScale
    readonly property real statusCenterHeight: 520 * MeoTheme.globalScale

    readonly property real shelfPanelHeight: 64 * MeoTheme.globalScale
    readonly property real shelfSurfaceHeight: 64 * MeoTheme.globalScale
    readonly property real shelfBottomMargin: 12 * MeoTheme.globalScale
    readonly property real shelfItemSize: 44 * MeoTheme.globalScale
    readonly property real shelfIconSize: 24 * MeoTheme.globalScale

    readonly property real appDelegateWidth: 68 * MeoTheme.globalScale
    readonly property real appDelegateHeight: 76 * MeoTheme.globalScale
    readonly property real appIconSize: 32 * MeoTheme.globalScale
    readonly property real statusIconSize: 24 * MeoTheme.globalScale

    readonly property real radiusWindow: MeoTheme.windowRadius
    readonly property real radiusPopup: MeoTheme.dialogRadius
    readonly property real radiusLarge: MeoTheme.cardRadius
    readonly property real radiusMedium: MeoTheme.windowRadius
    readonly property real radiusControl: MeoTheme.controlRadius
    readonly property real radiusSmall: MeoTheme.shapeSmall

    readonly property real desktopHitTarget: 44 * MeoTheme.globalScale
    readonly property real panelOutlineWidth: MeoTheme.strokeWidthThin
    readonly property real focusRingWidth: MeoTheme.focusRingWidth
}
