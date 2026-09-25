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

// Mirrors Caelestia's three expressive resource shapes, using MeoUI's own
// Material 3 shape engine rather than importing Quickshell/M3Shapes.
Rectangle {
    id: root

    readonly property string clientId: "meo-lock-performance-" + root.toString()
    readonly property bool hasData: Performance.available

    visible: hasData
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible ? 186 * MeoTheme.globalScale : 0
    radius: MeoTheme.shapeExtraLarge
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.92)

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
        anchors.fill: parent
        anchors.margins: MeoTheme.space16
        spacing: MeoTheme.space10

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoText {
                Layout.fillWidth: true
                text: qsTr("Resources")
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.outline
            }

            MeoShape {
                visible: Performance.cpuTemperature > 0
                implicitWidth: 48 * MeoTheme.globalScale
                implicitHeight: implicitWidth
                type: Performance.cpuTemperature >= 90 ? "SoftBurst" : "Circle"
                color: Performance.cpuTemperature >= 90
                       ? MeoTheme.errorContainer : MeoTheme.secondaryContainer

                MeoText {
                    anchors.centerIn: parent
                    text: Math.round(Performance.cpuTemperature) + "°"
                    typeRole: "label"
                    typeSize: "small"
                    emphasized: true
                    color: Performance.cpuTemperature >= 90
                           ? MeoTheme.contentOnErrorContainer
                           : MeoTheme.contentOnSecondaryContainer
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: MeoTheme.space12

            ResourceShape {
                Layout.fillWidth: true
                label: "CPU"
                iconName: "memory"
                value: Math.max(0, Math.min(100, Performance.cpuUsage))
                shapeName: "Pentagon"
                containerColor: MeoTheme.primaryContainer
                contentColor: MeoTheme.primary
            }

            ResourceShape {
                Layout.fillWidth: true
                label: qsTr("RAM")
                iconName: "memory_alt"
                value: Math.max(0, Math.min(100, Performance.memoryUsage))
                shapeName: "Slanted"
                containerColor: MeoTheme.tertiaryContainer
                contentColor: MeoTheme.tertiary
            }

            ResourceShape {
                Layout.fillWidth: true
                label: qsTr("Disk")
                iconName: "hard_disk"
                value: Math.max(0, Math.min(100, Performance.storageUsage))
                shapeName: "Gem"
                containerColor: MeoTheme.secondaryContainer
                contentColor: MeoTheme.secondary
            }
        }
    }

    component ResourceShape: Item {
        id: metric

        required property string label
        required property string iconName
        required property real value
        required property string shapeName
        required property color containerColor
        required property color contentColor

        Layout.preferredHeight: width
        Layout.minimumWidth: 72 * MeoTheme.globalScale

        MeoShape {
            anchors.fill: parent
            type: metric.shapeName
            color: metric.containerColor
        }

        // Usage drives tonal emphasis without introducing a second chart
        // language. The silhouette remains the recognizable Caelestia-style
        // resource shape while Meo keeps its own dynamic color roles.
        MeoShape {
            anchors.centerIn: parent
            width: parent.width * (0.70 + metric.value / 100 * 0.20)
            height: width
            type: metric.shapeName
            color: metric.contentColor
            opacity: 0.10 + metric.value / 100 * 0.18

            Behavior on width {
                enabled: !MeoTheme.reduceMotion
                NumberAnimation {
                    duration: MeoTheme.motionDurationMedium1
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -MeoTheme.space2

            MeoIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: metric.iconName
                size: 20 * MeoTheme.globalScale
                color: metric.contentColor
                fill: true
            }

            MeoText {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round(metric.value) + "%"
                typeRole: "headline"
                typeSize: "small"
                emphasized: true
                color: metric.contentColor
            }

            MeoText {
                Layout.alignment: Qt.AlignHCenter
                text: metric.label
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }
    }
}
