/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0
import Meo.System 1.0

Rectangle {
    id: root

    property bool showLocation: false

    visible: Weather.available
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible ? content.implicitHeight + MeoTheme.space24 * 2 : 0
    radius: MeoTheme.shapeExtraLarge
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.90)
    border.width: Math.max(1, MeoTheme.globalScale)
    border.color: Qt.rgba(MeoTheme.outlineVariant.r, MeoTheme.outlineVariant.g,
                          MeoTheme.outlineVariant.b, 0.46)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Weather")

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        spacing: MeoTheme.space16

        MeoIcon {
            icon: Weather.iconName !== "" ? Weather.iconName : "partly_cloudy_day"
            size: 44 * MeoTheme.globalScale
            color: Weather.stale ? MeoTheme.contentOnSurfaceVariant : MeoTheme.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space4

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                MeoText {
                    text: Weather.temperatureText
                    typeRole: "headline"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }

                MeoText {
                    Layout.fillWidth: true
                    text: Weather.condition
                    typeRole: "body"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            MeoText {
                Layout.fillWidth: true
                visible: root.showLocation && Weather.location !== ""
                text: Weather.location
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }

            MeoText {
                visible: Weather.stale
                text: qsTr("Cached weather")
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }
    }
}
