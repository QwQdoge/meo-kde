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

    visible: Weather.available
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible ? 190 * MeoTheme.globalScale : 0
    radius: MeoTheme.shapeExtraLarge * 1.35
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.92)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Weather")

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
                icon: Weather.iconName !== "" ? Weather.iconName : "partly_cloudy_day"
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

        Item { Layout.fillHeight: true }
    }
}
