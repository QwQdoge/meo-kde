/* Presentation only; KScreenLocker owns authentication and the secure window. */
import QtQuick
import MeoUI 1.0

Item {
    id: clock
    property date dateTime: new Date()
    property real centerScale: 1.0
    // Glyph size; the lock screen scales this with the screen height.
    property real pixelSize: 176 * clock.centerScale * MeoTheme.globalScale
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
        spacing: -clock.pixelSize * 0.10
        Text {
            objectName: "lockHours"
            text: clock.hours
            color: clock.foregroundColor
            font.family: MeoTheme.typefaceBrand
            font.pixelSize: clock.pixelSize
            font.weight: Font.Bold
            font.letterSpacing: -clock.pixelSize * 0.01
            anchors.horizontalCenter: parent.horizontalCenter
            lineHeight: 0.86
        }
        Text {
            objectName: "lockMinutes"
            text: clock.minutes
            color: clock.foregroundColor
            font.family: MeoTheme.typefaceBrand
            font.pixelSize: clock.pixelSize
            font.weight: Font.Bold
            font.letterSpacing: -clock.pixelSize * 0.01
            anchors.horizontalCenter: parent.horizontalCenter
            lineHeight: 0.86
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
        typeSize: "medium"
        emphasized: true
        color: clock.foregroundColor
        horizontalAlignment: Text.AlignHCenter
    }
}
