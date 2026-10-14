/* Presentation only; KScreenLocker owns authentication and the secure window. */
import QtQuick
import MeoUI 1.0

Item {
    id: clock
    property date dateTime: new Date()
    property real centerScale: 1.0
    property color foregroundColor: MeoTheme.contentOnSurface
    readonly property var displayLocale: Qt.locale(Qt.uiLanguage)
    readonly property string shortTimeFormat: displayLocale.timeFormat(Locale.ShortFormat)
    readonly property bool twelveHourClock: shortTimeFormat.includes("AP")
                                             || shortTimeFormat.includes("ap")
    readonly property string hours: Qt.formatTime(dateTime, twelveHourClock ? "h" : "HH")
    readonly property string minutes: Qt.formatTime(dateTime, "mm")
    readonly property string amPm: twelveHourClock ? displayLocale.toString(dateTime, "AP") : ""
    readonly property string dateLabel: displayLocale.toString(dateTime, "ddd, MMM d")
    implicitWidth: Math.max(timeColumn.implicitWidth, dateLabelItem.implicitWidth)
    implicitHeight: timeColumn.implicitHeight + MeoTheme.space16 + dateLabelItem.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: hours + ":" + minutes + (amPm !== "" ? " " + amPm : "") + ", " + dateLabel

    Timer {
        interval: 1000
        running: clock.visible
        repeat: true
        onTriggered: clock.dateTime = new Date()
    }

    Column {
        id: timeColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: -MeoTheme.space8 * clock.centerScale
        Text {
            objectName: "lockHours"
            text: clock.hours
            color: clock.foregroundColor
            font.family: MeoTheme.typefacePlain
            font.pixelSize: 176 * clock.centerScale * MeoTheme.globalScale
            font.weight: Font.Normal
            font.letterSpacing: -4 * clock.centerScale * MeoTheme.globalScale
            anchors.horizontalCenter: parent.horizontalCenter
            lineHeight: 0.9
        }
        Text {
            objectName: "lockMinutes"
            text: clock.minutes
            color: clock.foregroundColor
            font.family: MeoTheme.typefacePlain
            font.pixelSize: 176 * clock.centerScale * MeoTheme.globalScale
            font.weight: Font.Normal
            font.letterSpacing: -4 * clock.centerScale * MeoTheme.globalScale
            anchors.horizontalCenter: parent.horizontalCenter
            lineHeight: 0.9
        }
    }
    MeoText {
        id: dateLabelItem
        objectName: "lockDate"
        anchors.top: timeColumn.bottom
        anchors.topMargin: MeoTheme.space16
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.dateLabel
        typeRole: "label"
        typeSize: "large"
        emphasized: true
        color: clock.foregroundColor
        horizontalAlignment: Text.AlignHCenter
    }
}
