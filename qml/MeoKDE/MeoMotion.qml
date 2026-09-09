pragma Singleton
import QtQuick
import MeoUI 1.0 as UI

QtObject {
    readonly property int press: UI.MeoTheme.motionDurationPanelState
    readonly property int hover: UI.MeoTheme.motionDurationPanelState
    readonly property int stateChange: UI.MeoTheme.motionDurationSelection
    readonly property int popupOpen: UI.MeoTheme.motionDurationPopupEffectsEnter
    readonly property int popupClose: UI.MeoTheme.motionDurationPopupEffectsExit
    readonly property int shelfReveal: UI.MeoTheme.motionDurationPageEnter
    readonly property int shelfHide: UI.MeoTheme.motionDurationPageExit

    // Spatial specs proxy the shared analytic springs so shell code can use
    // one MeoMotion name without flattening expressive motion to a duration.
    readonly property var fastSpatial: UI.MeoMotion.fastSpatial
    readonly property var defaultSpatial: UI.MeoMotion.defaultSpatial
    readonly property var slowSpatial: UI.MeoMotion.slowSpatial

    // Shell-facing semantic aliases. Keep the historical `press` duration
    // above so installed plasmoids remain source compatible.
    readonly property int pressFeedback: UI.MeoTheme.motionDurationPanelState
    readonly property int reorder: UI.MeoTheme.motionDurationDisclosureEnter
    readonly property int popupEnter: UI.MeoTheme.motionDurationPopupEffectsEnter
    readonly property int popupExit: UI.MeoTheme.motionDurationPopupEffectsExit
    readonly property int pageEnter: UI.MeoTheme.motionDurationPageEnter
    readonly property int pageExit: UI.MeoTheme.motionDurationPageExit
}
