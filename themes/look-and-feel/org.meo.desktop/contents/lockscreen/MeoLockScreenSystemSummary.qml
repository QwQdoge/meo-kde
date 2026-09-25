/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Caelestia-Fetch-inspired system summary with a stricter lock-screen privacy
    boundary: no username, SSID, process list, IP address, or device address.
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0
import Meo.System 1.0

Rectangle {
    id: root

    readonly property string clientId: "meo-lock-system-" + root.toString()

    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: content.implicitHeight + MeoTheme.space24 * 2
    radius: MeoTheme.shapeLarge
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.92)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("System status")

    function syncSubscription() {
        if (visible)
            Performance.subscribe(clientId, ["system"])
        else
            Performance.unsubscribe(clientId)
    }

    function uptimeText(seconds) {
        const totalMinutes = Math.floor(Math.max(0, seconds) / 60)
        const days = Math.floor(totalMinutes / 1440)
        const hours = Math.floor((totalMinutes % 1440) / 60)
        const minutes = totalMinutes % 60
        if (days > 0)
            return qsTr("%1d %2h").arg(days).arg(hours)
        if (hours > 0)
            return qsTr("%1h %2m").arg(hours).arg(minutes)
        return qsTr("%1m").arg(minutes)
    }

    Component.onCompleted: syncSubscription()
    Component.onDestruction: Performance.unsubscribe(clientId)
    onVisibleChanged: syncSubscription()

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        spacing: MeoTheme.space10

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space12

            Rectangle {
                implicitWidth: 40 * MeoTheme.globalScale
                implicitHeight: 34 * MeoTheme.globalScale
                radius: MeoTheme.shapeMedium
                color: MeoTheme.primary

                MeoText {
                    anchors.centerIn: parent
                    text: ">"
                    font.family: MeoTheme.fontFamilyMonospace
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnPrimary
                }
            }

            MeoText {
                Layout.fillWidth: true
                text: "meofetch"
                font.family: MeoTheme.fontFamilyMonospace
                typeRole: "body"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
                elide: Text.ElideRight
            }
        }

        FetchLine {
            label: "UP"
            value: root.uptimeText(Performance.uptimeSeconds)
            iconName: "schedule"
        }
        FetchLine {
            label: "NET"
            value: SystemState.networkConnected ? qsTr("Connected") : qsTr("Offline")
            iconName: SystemState.networkConnected ? "wifi" : "wifi_off"
        }
        FetchLine {
            visible: SystemState.batteryAvailable
            label: "BATT"
            value: (SystemState.batteryCharging ? "(+) " : "") + SystemState.batteryPercent + "%"
            iconName: SystemState.batteryCharging ? "battery_charging_full" : "battery_full"
        }
        FetchLine {
            visible: SystemState.audioAvailable
            label: "VOL"
            value: SystemState.audioMuted ? qsTr("Muted") : SystemState.volumePercent + "%"
            iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
        }
    }

    component FetchLine: RowLayout {
        required property string label
        required property string value
        required property string iconName

        Layout.fillWidth: true
        spacing: MeoTheme.space8

        MeoText {
            text: parent.label.padEnd(4, " ") + ":"
            font.family: MeoTheme.fontFamilyMonospace
            typeRole: "label"
            typeSize: "medium"
            emphasized: true
            color: MeoTheme.primary
        }

        MeoIcon {
            icon: parent.iconName
            size: 18 * MeoTheme.globalScale
            color: MeoTheme.secondary
        }

        MeoText {
            Layout.fillWidth: true
            text: parent.value
            font.family: MeoTheme.fontFamilyMonospace
            typeRole: "label"
            typeSize: "medium"
            color: MeoTheme.contentOnSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
