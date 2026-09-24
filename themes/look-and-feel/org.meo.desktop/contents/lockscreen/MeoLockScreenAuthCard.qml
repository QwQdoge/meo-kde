/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    KDE presentation adapter inspired by the standalone Meo lock surface.
    It deliberately owns no credentials, PAM state, or session action.
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0

Item {
    id: card

    property bool active: true
    property string title: ""
    property string supportingText: ""
    property string statusText: ""
    property string errorText: ""
    property bool failed: false
    default property alias content: contentLayout.data

    readonly property string effectiveStatus: errorText !== "" ? errorText : statusText
    readonly property color statusColor: errorText !== "" ? MeoTheme.error : MeoTheme.contentOnSurfaceVariant
    readonly property real failureOffset: failureSpring.value

    implicitWidth: Math.max(344 * MeoTheme.globalScale,
                            Math.min(480 * MeoTheme.globalScale, content.implicitWidth))
    implicitHeight: content.implicitHeight
    opacity: active ? 1 : 0
    scale: MeoTheme.reduceMotion ? 1 : (active ? 1 : 0.96)
    transform: Translate { x: card.failureOffset }
    visible: active || opacity > 0.001

    Accessible.role: Accessible.Pane
    Accessible.name: title
    Accessible.description: effectiveStatus

    function triggerFailure() {
        if (MeoTheme.reduceMotion) {
            failureSpring.snapTo(0)
            return
        }
        failureSpring.snapTo(8 * MeoTheme.globalScale)
        failureSpring.targetValue = 0
    }

    Behavior on opacity {
        NumberAnimation {
            duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }

    MeoSpringValue {
        id: failureSpring
        motionProfile: "calm"
        speed: "fast"
        enabled: !MeoTheme.reduceMotion
        valueThreshold: 0.01 * MeoTheme.globalScale
        velocityThreshold: 0.02
        targetValue: 0
    }

    Rectangle {
        id: container
        anchors.fill: parent
        radius: MeoTheme.shapeExtraLarge
        color: MeoTheme.surfaceContainer
        border.width: MeoTheme.strokeWidthThin
        border.color: MeoTheme.outlineVariant
        opacity: 0.92
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: MeoTheme.space32
        spacing: MeoTheme.space16

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 72 * MeoTheme.globalScale
            implicitHeight: implicitWidth
            radius: implicitWidth / 4
            color: MeoTheme.primaryContainer

            MeoIcon {
                anchors.centerIn: parent
                icon: "lock"
                size: 36 * MeoTheme.globalScale
                color: MeoTheme.onPrimaryContainer
                Accessible.ignored: true
            }
        }

        MeoText {
            Layout.fillWidth: true
            text: "Meo"
            typeRole: "display"
            typeSize: "small"
            emphasized: true
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.primary
        }

        MeoText {
            Layout.fillWidth: true
            text: card.title
            typeRole: "title"
            typeSize: "large"
            emphasized: true
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.contentOnSurface
            wrapMode: Text.WordWrap
        }

        MeoText {
            Layout.fillWidth: true
            visible: text !== ""
            text: card.supportingText
            typeRole: "body"
            typeSize: "medium"
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.contentOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: MeoTheme.space12
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.effectiveStatus !== ""
            spacing: MeoTheme.space8

            MeoIcon {
                icon: card.errorText !== "" ? "error" : "info"
                size: 20 * MeoTheme.globalScale
                color: card.statusColor
            }
            MeoText {
                Layout.fillWidth: true
                text: card.effectiveStatus
                typeRole: "body"
                typeSize: "small"
                color: card.statusColor
                wrapMode: Text.WordWrap
            }
        }
    }
}
