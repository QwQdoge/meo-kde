/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0
import Meo.System 1.0

// Caelestia-style brief weather hierarchy, backed only by Meo's bounded
// weather cache. No network request is made from the secure lock surface.
Rectangle {
    id: root

    property bool showLocation: false
    property bool showForecast: false
    readonly property bool forecastVisible: showForecast && Weather.forecast.length > 0

    visible: Weather.available
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible
                    ? (forecastVisible ? 276 : 190) * MeoTheme.globalScale
                    : 0
    radius: MeoTheme.shapeExtraLarge * 1.35
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.92)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Weather")

    // Reuse the shared MeoUI KDE-weather-icon -> Material Symbol mapping.
    // This mapper stays non-visual and prevents a second icon vocabulary from
    // drifting away from the compact weather component.
    MeoWeatherStatus {
        id: iconMapper
        available: false
        visible: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        spacing: MeoTheme.space6

        Item { Layout.fillHeight: true }

        MeoText {
            Layout.alignment: Qt.AlignHCenter
            text: Weather.condition
            typeRole: "body"
            typeSize: "large"
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: MeoTheme.space12

            MeoText {
                text: Weather.temperatureText
                typeRole: "display"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.primary
            }

            MeoIcon {
                icon: iconMapper.materialSymbolFor(Weather.iconName)
                size: 52 * MeoTheme.globalScale
                color: MeoTheme.secondary
                fill: true
            }
        }

        MeoText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showLocation && Weather.location !== ""
            text: Weather.location
            typeRole: "body"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MeoText {
            Layout.alignment: Qt.AlignHCenter
            visible: Weather.stale
            text: qsTr("Cached weather")
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.outline
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, MeoTheme.globalScale)
            Layout.topMargin: MeoTheme.space8
            visible: root.forecastVisible
            color: Qt.rgba(MeoTheme.outlineVariant.r,
                           MeoTheme.outlineVariant.g,
                           MeoTheme.outlineVariant.b, 0.44)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: MeoTheme.space4
            visible: root.forecastVisible
            spacing: MeoTheme.space8

            Repeater {
                model: Weather.forecast.slice(0, 4)

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: MeoTheme.space2

                    MeoText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.time || ""
                        font.family: MeoTheme.fontFamilyMonospace
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.outline
                    }

                    MeoIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: iconMapper.materialSymbolFor(modelData.iconName || "")
                        size: 22 * MeoTheme.globalScale
                        color: MeoTheme.secondary
                        fill: true
                    }

                    MeoText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.temperatureText || ""
                        typeRole: "label"
                        typeSize: "medium"
                        emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
