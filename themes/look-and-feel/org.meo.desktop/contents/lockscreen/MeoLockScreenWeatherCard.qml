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
    property real rootHeight: 0
    readonly property bool detailsVisible: rootHeight >= 550 * MeoTheme.globalScale
                                           && Weather.apparentTemperatureText !== ""
                                           && Weather.highTemperatureText !== ""
                                           && Weather.lowTemperatureText !== ""
    readonly property bool forecastVisible: showForecast && Weather.forecast.length > 0
    readonly property int forecastItemCount: Math.min(Weather.forecast.length,
                                                       Math.max(1, Math.floor(
                                                           (width - MeoTheme.space48)
                                                           / (58 * MeoTheme.globalScale))))

    visible: Weather.available
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible
                    ? (forecastVisible ? 420 : detailsVisible ? 244 : 190)
                      * MeoTheme.globalScale
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
            visible: root.detailsVisible
            text: qsTr("Feels like %1").arg(Weather.apparentTemperatureText)
            typeRole: "body"
            typeSize: "large"
            color: MeoTheme.contentOnSurfaceVariant
        }

        MeoText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.detailsVisible
            text: qsTr("High %1 • Low %2")
                    .arg(Weather.highTemperatureText)
                    .arg(Weather.lowTemperatureText)
            typeRole: "body"
            typeSize: "medium"
            color: MeoTheme.contentOnSurfaceVariant
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
            Layout.topMargin: MeoTheme.space10
            Layout.preferredHeight: forecastLayout.implicitHeight + MeoTheme.space16 * 2
            visible: root.forecastVisible
            radius: MeoTheme.shapeExtraLarge
            color: MeoTheme.surfaceContainerHigh

            ColumnLayout {
                id: forecastLayout
                anchors.fill: parent
                anchors.margins: MeoTheme.space16
                spacing: MeoTheme.space10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space6

                    MeoIcon {
                        icon: "schedule"
                        size: 19 * MeoTheme.globalScale
                        color: MeoTheme.contentOnSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: qsTr("Hourly forecast")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        color: MeoTheme.contentOnSurface
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space6

                    Repeater {
                        model: Weather.forecast.slice(0, root.forecastItemCount)

                        ColumnLayout {
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: MeoTheme.space4

                            MeoShape {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 48 * MeoTheme.globalScale
                                implicitHeight: implicitWidth
                                type: "Cookie4Sided"
                                color: index === 0 ? MeoTheme.primary : "transparent"

                                MeoText {
                                    anchors.centerIn: parent
                                    text: modelData.temperatureText || ""
                                    typeRole: "label"
                                    typeSize: "medium"
                                    emphasized: true
                                    color: index === 0
                                           ? MeoTheme.contentOnPrimary
                                           : MeoTheme.contentOnSurface
                                }
                            }

                            MeoIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: iconMapper.materialSymbolFor(modelData.iconName || "")
                                size: 24 * MeoTheme.globalScale
                                color: MeoTheme.secondary
                                fill: true
                            }

                            MeoText {
                                Layout.alignment: Qt.AlignHCenter
                                text: String(modelData.precipitationChance || 0) + "%"
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.primary
                            }

                            MeoText {
                                Layout.alignment: Qt.AlignHCenter
                                text: index === 0 ? qsTr("Now") : (modelData.time || "")
                                font.family: MeoTheme.fontFamilyMonospace
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
