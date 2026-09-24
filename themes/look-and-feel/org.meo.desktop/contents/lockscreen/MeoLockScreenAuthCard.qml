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
    property bool showClock: true
    property url avatarSource: ""
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

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: MeoTheme.space24

        // The standalone centre keeps the split-colour clock above the
        // identity and password pill. It is repeated here only while the
        // KScreenLocker authentication surface is active.
        MeoLockScreenClock {
            Layout.alignment: Qt.AlignHCenter
            visible: card.showClock
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 196 * MeoTheme.globalScale
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: MeoTheme.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: card.avatarSource
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
            }

            MeoIcon {
                anchors.centerIn: parent
                icon: "person"
                size: 52 * MeoTheme.globalScale
                color: MeoTheme.contentOnSurfaceVariant
                Accessible.ignored: true
            }
        }

        MeoText {
            Layout.fillWidth: true
            visible: text !== ""
            text: card.title
            typeRole: "title"
            typeSize: "medium"
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
