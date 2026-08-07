pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami
import MeoUI 1.0

QtObject {
    readonly property int press: MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryShortDuration
    readonly property int hover: MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryShortDuration
    readonly property int stateChange: MeoTheme.reduceMotion ? 0 : Kirigami.Units.shortDuration
    readonly property int popupOpen: MeoTheme.reduceMotion ? 0 : Kirigami.Units.longDuration
    readonly property int popupClose: MeoTheme.reduceMotion ? 0 : Kirigami.Units.shortDuration
    readonly property int shelfReveal: MeoTheme.reduceMotion ? 0 : Kirigami.Units.longDuration
    readonly property int shelfHide: MeoTheme.reduceMotion ? 0 : Kirigami.Units.veryLongDuration
}

