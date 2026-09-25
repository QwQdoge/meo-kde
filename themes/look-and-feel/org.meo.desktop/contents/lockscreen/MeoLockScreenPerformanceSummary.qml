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
    property bool sessionControlsEnabled: true
    property bool canSuspend: false
    property bool canHibernate: false
    property bool canReboot: false
    property bool canShutdown: false
    readonly property bool hasSessionControls: sessionControlsEnabled
                                                && (canSuspend || canHibernate || canReboot || canShutdown)
    readonly property bool sessionControlsShown: hasSessionControls && hover.hovered

    signal suspendRequested()
    signal hibernateRequested()
    signal rebootRequested()
    signal shutdownRequested()

    visible: hasData
    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: visible ? 186 * MeoTheme.globalScale : 0
    radius: MeoTheme.shapeExtraLarge
    color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                   MeoTheme.surfaceContainer.b, 0.92)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Performance")

    HoverHandler {
        id: hover
        enabled: root.hasSessionControls
    }

    function syncSubscription() {
        if (visible)
            Performance.subscribe(clientId, ["cpu", "memory", "disk", "system"])
        else
            Performance.unsubscribe(clientId)
    }

    Component.onCompleted: syncSubscription()
    Component.onDestruction: Performance.unsubscribe(clientId)
    onVisibleChanged: syncSubscription()

    Item {
        anchors.fill: parent
        anchors.margins: MeoTheme.space16
        clip: true

        ColumnLayout {
            id: resourceContent
            anchors.fill: parent
            spacing: MeoTheme.space10
            opacity: root.sessionControlsShown ? 0 : 1
            transform: Translate {
                y: root.sessionControlsShown ? root.height * 0.30 : 0
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort4
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingStandard
                }
            }

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

        RowLayout {
            anchors.fill: parent
            spacing: MeoTheme.space12
            opacity: root.sessionControlsShown ? 1 : 0
            enabled: root.sessionControlsShown
            transform: Translate {
                y: root.sessionControlsShown ? 0 : -root.height * 0.30
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort4
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingStandard
                }
            }

            SessionAction {
                visible: root.canSuspend
                iconName: "bedtime"
                accessibleName: qsTr("Sleep")
                onTriggered: root.suspendRequested()
            }
            SessionAction {
                visible: root.canHibernate
                iconName: "mode_night"
                accessibleName: qsTr("Hibernate")
                onTriggered: root.hibernateRequested()
            }
            SessionAction {
                visible: root.canReboot
                iconName: "restart_alt"
                accessibleName: qsTr("Restart")
                onTriggered: root.rebootRequested()
            }
            SessionAction {
                visible: root.canShutdown
                iconName: "power_settings_new"
                accessibleName: qsTr("Shut down")
                onTriggered: root.shutdownRequested()
            }
        }
    }

    component SessionAction: MeoIconButton {
        required property string iconName
        required property string accessibleName
        signal triggered()

        Layout.fillWidth: true
        type: "tonal"
        size: "l"
        shape: pressed ? "square" : "circle"
        icon.name: iconName
        Accessible.name: accessibleName
        onClicked: triggered()
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

        // Match Caelestia's resource language more closely: the metric is a
        // liquid level clipped by the same expressive silhouette. The wave
        // strip is painted once and translated, so idle layout and paths stay
        // stable instead of redrawing a Canvas every frame.
        MeoLockScreenWavyFill {
            anchors.fill: parent
            value: metric.value / 100
            shapeName: metric.shapeName
            fillColor: Qt.rgba(metric.contentColor.r, metric.contentColor.g,
                               metric.contentColor.b, 0.30)
            animate: root.visible && !root.sessionControlsShown
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
