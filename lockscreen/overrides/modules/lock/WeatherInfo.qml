import QtQuick
import QtQuick.Layouts
import qs.components

StyledRect {
    id: root

    required property int rootHeight

    implicitHeight: content.implicitHeight + Tokens.padding.extraLarge * 2
    radius: Tokens.rounding.extraExtraLarge
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: MeoWeatherCache.temperatureText
            color: Colours.palette.m3primary
            font: Tokens.font.headline.large
        }

        StyledText {
            Layout.fillWidth: true
            text: MeoWeatherCache.condition
            color: Colours.palette.m3onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: Tokens.font.body.medium
        }

        StyledText {
            Layout.fillWidth: true
            visible: MeoSessionEntry.weatherLocation !== "hidden" && MeoWeatherCache.location.length > 0
            text: visible ? MeoWeatherCache.location : ""
            color: Colours.palette.m3outline
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: Tokens.font.body.small
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: MeoWeatherCache.highTemperatureText.length > 0
                || MeoWeatherCache.lowTemperatureText.length > 0
            spacing: Tokens.spacing.medium

            StyledText {
                visible: MeoWeatherCache.highTemperatureText.length > 0
                text: `↑ ${MeoWeatherCache.highTemperatureText}`
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledText {
                visible: MeoWeatherCache.lowTemperatureText.length > 0
                text: `↓ ${MeoWeatherCache.lowTemperatureText}`
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }
}
