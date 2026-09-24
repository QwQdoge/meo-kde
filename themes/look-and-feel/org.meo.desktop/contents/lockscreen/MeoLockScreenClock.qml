/* KDE-safe visual port of the standalone lock clock. */
import QtQuick

import MeoUI 1.0

Item {
    id: clock

    property date dateTime: new Date()
    readonly property var displayLocale: Qt.locale(Qt.uiLanguage)
    readonly property string hours: Qt.formatTime(dateTime, "HH")
    readonly property string minutes: Qt.formatTime(dateTime, "mm")
    readonly property string dateLabel: Qt.formatDate(dateTime, displayLocale, Locale.LongFormat)

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
            font.family: MeoTheme.typefaceBrand
            font.pixelSize: 112 * MeoTheme.globalScale
            font.weight: Font.Normal
            font.letterSpacing: -1.4 * MeoTheme.globalScale
        }
        Text {
            text: clock.minutes
            color: MeoTheme.secondary
            font.family: MeoTheme.typefaceBrand
            font.pixelSize: 112 * MeoTheme.globalScale
            font.weight: Font.Normal
            font.letterSpacing: -1.4 * MeoTheme.globalScale
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
