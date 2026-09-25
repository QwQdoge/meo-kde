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

    property real rootHeight: 0
    readonly property string clientId: "meo-lock-system-" + root.toString()
    readonly property var paletteSwatches: [
        MeoTheme.primary,
        MeoTheme.secondary,
        MeoTheme.tertiary,
        MeoTheme.error,
        MeoTheme.primaryContainer,
        MeoTheme.secondaryContainer,
        MeoTheme.tertiaryContainer,
        MeoTheme.surfaceContainerHighest
    ]

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

            MeoShape {
                implicitWidth: 38 * MeoTheme.globalScale
                implicitHeight: implicitWidth
                type: "Cookie6Sided"
                color: MeoTheme.secondaryContainer

                MeoIcon {
                    anchors.centerIn: parent
                    icon: "terminal"
                    size: 20 * MeoTheme.globalScale
                    color: MeoTheme.secondary
                    fill: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space16

            MeoShape {
                Layout.alignment: Qt.AlignTop
                visible: root.width >= 330 * MeoTheme.globalScale
                implicitWidth: 76 * MeoTheme.globalScale
                implicitHeight: implicitWidth
                type: "ClamShell"
                color: MeoTheme.primaryContainer

                MeoIcon {
                    anchors.centerIn: parent
                    icon: "desktop_windows"
                    size: 38 * MeoTheme.globalScale
                    color: MeoTheme.primary
                    fill: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space6

                FetchLine {
                    label: "OS"
                    value: Performance.operatingSystemName !== ""
                           ? Performance.operatingSystemName
                           : Performance.kernelVersion
                    iconName: "computer"
                }
                FetchLine {
                    label: "WM"
                    value: Performance.desktopEnvironment !== ""
                           ? Performance.desktopEnvironment
                           : "KDE Plasma"
                    iconName: "web_asset"
                }
                FetchLine {
                    label: "UP"
                    value: root.uptimeText(Performance.uptimeSeconds)
                    iconName: "schedule"
                }
                FetchLine {
                    visible: SystemState.batteryAvailable
                    label: "BATT"
                    value: (SystemState.batteryCharging ? "(+) " : "")
                           + SystemState.batteryPercent + "%"
                    iconName: SystemState.batteryCharging
                              ? "battery_charging_full" : "battery_full"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            StatusChip {
                Layout.fillWidth: true
                iconName: SystemState.networkConnected ? "wifi" : "wifi_off"
                label: SystemState.networkConnected ? qsTr("Connected") : qsTr("Offline")
                active: SystemState.networkConnected
            }

            StatusChip {
                Layout.fillWidth: true
                visible: SystemState.audioAvailable
                iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
                label: SystemState.audioMuted ? qsTr("Muted")
                                              : SystemState.volumePercent + "%"
                active: !SystemState.audioMuted
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.rootHeight >= 570 * MeoTheme.globalScale
            spacing: MeoTheme.space8

            Repeater {
                model: root.paletteSwatches

                MeoShape {
                    required property var modelData
                    implicitWidth: 20 * MeoTheme.globalScale
                    implicitHeight: implicitWidth
                    type: "rect"
                    radius: MeoTheme.shapeSmall
                    color: modelData
                }
            }
        }
    }

    component FetchLine: RowLayout {
        id: fetchLine

        required property string label
        required property string value
        required property string iconName

        Layout.fillWidth: true
        spacing: MeoTheme.space8

        MeoText {
            text: fetchLine.label.padEnd(4, " ") + ":"
            font.family: MeoTheme.fontFamilyMonospace
            typeRole: "label"
            typeSize: "medium"
            emphasized: true
            color: MeoTheme.primary
        }

        MeoIcon {
            icon: fetchLine.iconName
            size: 18 * MeoTheme.globalScale
            color: MeoTheme.secondary
        }

        MeoText {
            Layout.fillWidth: true
            text: fetchLine.value
            font.family: MeoTheme.fontFamilyMonospace
            typeRole: "label"
            typeSize: "medium"
            color: MeoTheme.contentOnSurfaceVariant
            elide: Text.ElideRight
        }
    }

    component StatusChip: Rectangle {
        id: statusChip

        required property string iconName
        required property string label
        property bool active: true

        implicitHeight: 34 * MeoTheme.globalScale
        radius: implicitHeight / 2
        color: active ? MeoTheme.surfaceContainerHigh
                      : MeoTheme.surfaceContainerLowest

        RowLayout {
            anchors.centerIn: parent
            spacing: MeoTheme.space6

            MeoIcon {
                icon: statusChip.iconName
                size: 17 * MeoTheme.globalScale
                color: statusChip.active ? MeoTheme.primary
                                         : MeoTheme.contentOnSurfaceVariant
            }

            MeoText {
                text: statusChip.label
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
