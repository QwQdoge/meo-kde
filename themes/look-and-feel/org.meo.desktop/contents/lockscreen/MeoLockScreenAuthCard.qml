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
    property bool embedded: false
    property real centerScale: 1.0
    property bool showClock: true
    property url avatarSource: ""
    default property alias content: contentLayout.data

    readonly property string effectiveStatus: errorText !== "" ? errorText : statusText
    readonly property color statusColor: errorText !== "" ? MeoTheme.error : MeoTheme.contentOnSurfaceVariant
    readonly property real failureOffset: failureSpring.value
    readonly property real contentInset: embedded ? 0 : MeoTheme.space32

    // Match the wider standalone/DMS-style center while staying bounded on
    // narrow displays. The inset is included in implicit geometry so the
    // layout never clips the clock/avatar/password stack.
    implicitWidth: Math.max(344 * MeoTheme.globalScale,
                            Math.min(600 * MeoTheme.globalScale,
                                     content.implicitWidth + contentInset * 2))
    implicitHeight: content.implicitHeight + contentInset * 2
    opacity: active ? 1 : 0
    // The outer secure stack owns the macro authentication scale/translate.
    // Keeping this card at unit scale avoids multiplying two reveal motions.
    scale: 1
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
    MeoSpringValue {
        id: failureSpring
        motionProfile: "calm"
        speed: "fast"
        enabled: !MeoTheme.reduceMotion
        valueThreshold: 0.01 * MeoTheme.globalScale
        velocityThreshold: 0.02
        targetValue: 0
    }

    // DMS/Caelestia-inspired expressive surface: a quiet Material gradient
    // instead of a flat panel. It remains presentation-only; authentication
    // and secure input are still owned by KScreenLocker.
    Rectangle {
        id: expressiveSurface
        anchors.fill: parent
        radius: card.failed ? MeoTheme.shapeLarge : MeoTheme.shapeExtraLarge
        border.width: card.embedded ? 0 : Math.max(1, MeoTheme.globalScale)
        border.color: card.failed
                      ? Qt.rgba(MeoTheme.error.r, MeoTheme.error.g, MeoTheme.error.b, 0.64)
                      : Qt.rgba(MeoTheme.outline.r, MeoTheme.outline.g, MeoTheme.outline.b, 0.24)
        opacity: card.embedded ? 0 : 1

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0.0
                color: Qt.rgba(MeoTheme.surfaceContainerHighest.r,
                               MeoTheme.surfaceContainerHighest.g,
                               MeoTheme.surfaceContainerHighest.b, 0.94)
            }
            GradientStop {
                position: 0.56
                color: Qt.rgba(MeoTheme.surfaceContainer.r,
                               MeoTheme.surfaceContainer.g,
                               MeoTheme.surfaceContainer.b, 0.92)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(MeoTheme.primaryContainer.r,
                               MeoTheme.primaryContainer.g,
                               MeoTheme.primaryContainer.b, 0.82)
            }
        }

        Behavior on radius {
            enabled: !MeoTheme.reduceMotion
            NumberAnimation {
                duration: MeoTheme.motionDurationMedium1
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MeoTheme.motionEasingEmphasized
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationMedium1
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MeoTheme.motionEasingEmphasized
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, MeoTheme.globalScale)
        visible: !card.embedded
        radius: Math.max(0, expressiveSurface.radius - Math.max(1, MeoTheme.globalScale))
        color: "transparent"
        border.width: Math.max(1, MeoTheme.globalScale)
        border.color: Qt.rgba(MeoTheme.primary.r, MeoTheme.primary.g, MeoTheme.primary.b,
                              card.active ? 0.10 : 0.0)
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: card.contentInset
        spacing: MeoTheme.space24

        // The standalone centre keeps the split-colour clock above the
        // identity and password pill. It is repeated here only while the
        // KScreenLocker authentication surface is active.
        MeoLockScreenClock {
            Layout.alignment: Qt.AlignHCenter
            visible: card.showClock
            centerScale: card.centerScale
        }

        // Reuse MeoUI's existing arbitrary-shape avatar/masking path instead
        // of maintaining a lock-screen-only crop implementation.
        MeoAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: MeoTheme.space16 * card.centerScale
            Layout.bottomMargin: MeoTheme.space8 * card.centerScale
            // Caelestia sizes the profile shape at 70% of its 600dp centre
            // column: 420dp at 1440p, then scales with screen height.
            // MeoAvatar.size is expressed in dp and applies globalScale
            // internally, so do not multiply the token twice here.
            size: Math.max(196, 420 * card.centerScale)
            variant: "ClamShell"
            source: card.avatarSource
            color: MeoTheme.surfaceContainerHighest
            textColor: MeoTheme.contentOnSurfaceVariant
        }

        MeoText {
            Layout.fillWidth: true
            visible: !card.embedded && text !== ""
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
            visible: !card.embedded && text !== ""
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
