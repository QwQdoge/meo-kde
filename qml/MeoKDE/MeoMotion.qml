pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import MeoUI 1.0 as UI

QtObject {
    readonly property int press: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryShortDuration
    readonly property int hover: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryShortDuration
    readonly property int stateChange: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.shortDuration
    readonly property int popupOpen: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.longDuration
    readonly property int popupClose: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.shortDuration
    readonly property int shelfReveal: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.longDuration
    readonly property int shelfHide: UI.MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryLongDuration

    // Spatial specs proxy the shared analytic springs so shell code can use
    // one MeoMotion name without flattening expressive motion to a duration.
    readonly property var fastSpatial: UI.MeoMotion.fastSpatial
    readonly property var defaultSpatial: UI.MeoMotion.defaultSpatial
    readonly property var slowSpatial: UI.MeoMotion.slowSpatial

    // Shell-facing semantic aliases.  Keep the historical duration names
    // above so installed plasmoids remain source compatible.
    readonly property int press: UI.MeoTheme.reduceMotion ? 80 : Kirigami.Units.shortDuration
    readonly property int reorder: UI.MeoTheme.reduceMotion ? 100 : Kirigami.Units.longDuration
    readonly property int popupEnter: UI.MeoTheme.reduceMotion ? 100 : Kirigami.Units.longDuration
    readonly property int popupExit: UI.MeoTheme.reduceMotion ? 80 : Kirigami.Units.shortDuration
    readonly property int pageEnter: UI.MeoTheme.reduceMotion ? 100 : Kirigami.Units.longDuration
    readonly property int pageExit: UI.MeoTheme.reduceMotion ? 80 : Kirigami.Units.shortDuration
}
