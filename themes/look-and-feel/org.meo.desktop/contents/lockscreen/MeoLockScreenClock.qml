/* KDE-safe visual port of the standalone lock clock. */
import QtQuick

import MeoUI 1.0

Item {
    id: clock

    property date dateTime: new Date()
    property real centerScale: 1.0
    readonly property var displayLocale: Qt.locale(Qt.uiLanguage)
    readonly property string shortTimeFormat: displayLocale.timeFormat(Locale.ShortFormat)
    readonly property bool twelveHourClock: shortTimeFormat.includes("AP")
                                             || shortTimeFormat.includes("ap")
    readonly property string hours: Qt.formatTime(dateTime, twelveHourClock ? "h" : "HH")
    readonly property string minutes: Qt.formatTime(dateTime, "mm")
    readonly property string amPm: twelveHourClock ? Qt.formatTime(dateTime, "AP") : ""
    readonly property string dateLabel: Qt.formatDate(dateTime, "dddd • d MMM").toUpperCase()

    implicitWidth: timeRow.implicitWidth
    implicitHeight: timeRow.implicitHeight + MeoTheme.space8 + dateLabelItem.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: hours + ":" + minutes
                     + (amPm !== "" ? " " + amPm : "")
                     + ", " + dateLabel

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.dateTime = new Date()
    }

    Row {
        id: timeRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: MeoTheme.space8

        Text {
            id: hoursLabel
            text: clock.hours
            color: MeoTheme.primary
            font.family: MeoTheme.typefacePlain
            font.pixelSize: 224 * clock.centerScale * MeoTheme.globalScale
            font.weight: Font.Medium
            font.letterSpacing: -2.0 * clock.centerScale * MeoTheme.globalScale
        }

        Item {
            id: minuteBlock
            width: minutesLabel.implicitWidth
            height: hoursLabel.implicitHeight

            Text {
                id: minutesLabel
                anchors.top: parent.top
                anchors.right: parent.right
                text: clock.minutes
                color: MeoTheme.secondary
                font.family: MeoTheme.typefacePlain
                font.pixelSize: (clock.twelveHourClock ? 122 : 224)
                                * clock.centerScale * MeoTheme.globalScale
                font.weight: Font.Medium
                font.letterSpacing: -2.0 * clock.centerScale * MeoTheme.globalScale
            }

            Rectangle {
                id: amPmPill
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: clock.twelveHourClock
                width: Math.max(minutesLabel.implicitWidth,
                                86 * clock.centerScale * MeoTheme.globalScale)
                height: 48 * clock.centerScale * MeoTheme.globalScale
                radius: height / 2
                color: MeoTheme.surfaceContainerHigh

                MeoText {
                    anchors.centerIn: parent
                    text: clock.amPm
                    typeRole: "headline"
                    typeSize: "small"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
            }
        }
    }

    MeoText {
        id: dateLabelItem
        anchors.top: timeRow.bottom
        anchors.topMargin: MeoTheme.space8
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.dateLabel
        typeRole: "title"
        typeSize: "medium"
        emphasized: true
        color: MeoTheme.contentOnSurface
        horizontalAlignment: Text.AlignHCenter
    }
}
