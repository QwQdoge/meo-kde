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
                   MeoTheme.surfaceContainer.b, 0.88)
    border.width: Math.max(1, MeoTheme.globalScale)
    border.color: Qt.rgba(MeoTheme.outlineVariant.r, MeoTheme.outlineVariant.g,
                          MeoTheme.outlineVariant.b, 0.42)

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
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            Rectangle {
                implicitWidth: 36 * MeoTheme.globalScale
                implicitHeight: implicitWidth
                radius: MeoTheme.shapeMedium
                color: MeoTheme.primaryContainer

                MeoIcon {
                    anchors.centerIn: parent
                    icon: "terminal"
                    size: 20 * MeoTheme.globalScale
                    color: MeoTheme.contentOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    text: "meofetch"
                    typeRole: "label"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                }
                MeoText {
                    text: qsTr("UP  ·  %1").arg(root.uptimeText(Performance.uptimeSeconds))
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space16

            Status {
                Layout.fillWidth: true
                iconName: SystemState.networkConnected ? "wifi" : "wifi_off"
                label: SystemState.networkConnected ? qsTr("Connected") : qsTr("Offline")
                active: SystemState.networkConnected
            }
            Status {
                Layout.fillWidth: true
                visible: SystemState.batteryAvailable
                iconName: SystemState.batteryCharging ? "battery_charging_full" : "battery_full"
                label: SystemState.batteryPercent + "%"
                active: !SystemState.batteryAvailable || SystemState.batteryPercent > 15
            }
            Status {
                Layout.fillWidth: true
                visible: SystemState.audioAvailable
                iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
                label: SystemState.audioMuted ? qsTr("Muted") : SystemState.volumePercent + "%"
                active: !SystemState.audioMuted
            }
        }
    }

    component Status: RowLayout {
        id: status

        required property string iconName
        required property string label
        property bool active: true

        spacing: MeoTheme.space4

        MeoIcon {
            icon: status.iconName
            size: 18 * MeoTheme.globalScale
            color: status.active ? MeoTheme.primary : MeoTheme.contentOnSurfaceVariant
        }
        MeoText {
            Layout.fillWidth: true
            text: status.label
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
