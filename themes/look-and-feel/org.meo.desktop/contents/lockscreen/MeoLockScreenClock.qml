/* KDE-safe visual port of the standalone lock clock. */
import QtQuick

import MeoUI 1.0

Item {
    id: clock

    property date dateTime: new Date()
    property real centerScale: 1.0
    readonly property var displayLocale: Qt.locale(Qt.uiLanguage)
    readonly property string hours: Qt.formatTime(dateTime, "HH")
    readonly property string minutes: Qt.formatTime(dateTime, "mm")
    readonly property string dateLabel: Qt.formatDate(dateTime, "dddd • d MMM").toUpperCase()

    implicitWidth: timeRow.implicitWidth
    implicitHeight: timeRow.implicitHeight + MeoTheme.space8 + dateLabelItem.implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: hours + ":" + minutes + ", " + dateLabel

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
            text: clock.hours
            color: MeoTheme.primary
            font.family: MeoTheme.typefacePlain
            font.pixelSize: 224 * clock.centerScale * MeoTheme.globalScale
            font.weight: Font.Medium
            font.letterSpacing: -2.0 * clock.centerScale * MeoTheme.globalScale
        }
        Text {
            text: clock.minutes
            color: MeoTheme.secondary
            font.family: MeoTheme.typefacePlain
            font.pixelSize: 224 * clock.centerScale * MeoTheme.globalScale
            font.weight: Font.Medium
            font.letterSpacing: -2.0 * clock.centerScale * MeoTheme.globalScale
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
