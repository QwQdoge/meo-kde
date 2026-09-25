/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only lock-screen projection. It intentionally subscribes only to
    aggregate CPU, memory, disk and system metrics: no process names, network
    interface names, command lines, or per-process activity cross this surface.
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0
import Meo.System 1.0

Rectangle {
    id: root

    readonly property string clientId: "meo-lock-performance-" + root.toString()
    readonly property bool hasData: Performance.available

    visible: hasData
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible ? content.implicitHeight + MeoTheme.space24 * 2 : 0
    radius: MeoTheme.shapeExtraLarge
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.90)
    border.width: Math.max(1, MeoTheme.globalScale)
    border.color: Qt.rgba(MeoTheme.outlineVariant.r, MeoTheme.outlineVariant.g,
                          MeoTheme.outlineVariant.b, 0.46)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Performance")

    function syncSubscription() {
        if (visible)
            Performance.subscribe(clientId, ["cpu", "memory", "disk", "system"])
        else
            Performance.unsubscribe(clientId)
    }

    Component.onCompleted: syncSubscription()
    Component.onDestruction: Performance.unsubscribe(clientId)
    onVisibleChanged: syncSubscription()

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        spacing: MeoTheme.space16

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoIcon {
                icon: "monitoring"
                size: 24 * MeoTheme.globalScale
                color: MeoTheme.primary
            }
            MeoText {
                Layout.fillWidth: true
                text: qsTr("Performance")
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
            MeoText {
                visible: Performance.cpuTemperature > 0
                text: Math.round(Performance.cpuTemperature) + "°C"
                typeRole: "label"
                typeSize: "small"
                color: Performance.cpuTemperature >= 90
                       ? MeoTheme.error : MeoTheme.contentOnSurfaceVariant
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space12

            Metric {
                Layout.fillWidth: true
                label: "CPU"
                iconName: "memory"
                value: Math.max(0, Math.min(100, Performance.cpuUsage))
                accent: MeoTheme.primary
            }

            Metric {
                Layout.fillWidth: true
                label: qsTr("RAM")
                iconName: "memory_alt"
                value: Math.max(0, Math.min(100, Performance.memoryUsage))
                accent: MeoTheme.tertiary
            }

            Metric {
                Layout.fillWidth: true
                label: qsTr("Storage")
                iconName: "hard_disk"
                value: Math.max(0, Math.min(100, Performance.storageUsage))
                accent: MeoTheme.secondary
            }
        }
    }

    component Metric: ColumnLayout {
        id: metric

        required property string label
        required property string iconName
        required property real value
        required property color accent

        spacing: MeoTheme.space6

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space4
            MeoIcon {
                icon: metric.iconName
                size: 18 * MeoTheme.globalScale
                color: metric.accent
            }
            MeoText {
                Layout.fillWidth: true
                text: metric.label
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }
        }

        MeoText {
            text: Math.round(metric.value) + "%"
            typeRole: "title"
            typeSize: "medium"
            emphasized: true
            color: metric.accent
        }

        MeoProgressBar {
            Layout.fillWidth: true
            value: metric.value / 100
            activeColor: metric.accent
            isThick: true
        }
    }
}
