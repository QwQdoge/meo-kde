/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme-local visual port of the standalone lock password pill. Credential
    ownership deliberately remains with the parent KScreenLocker binding.
*/

import QtQuick
import QtQuick.Controls

import MeoUI 1.0

TextField {
    id: field

    property bool passwordVisible: false
    property bool fingerprintAvailable: false
    property bool smartcardAvailable: false
    property string accessibleLabel: qsTr("Password")
    readonly property bool hasInput: text.length > 0
    readonly property real emptyFieldWidth: 304 * MeoTheme.globalScale
    readonly property real filledFieldWidth: Math.min(480 * MeoTheme.globalScale,
                                                       Math.max(360 * MeoTheme.globalScale,
                                                                parent ? parent.width * 0.8
                                                                       : 480 * MeoTheme.globalScale))
    property real submitMorphProgress: hasInput ? 1.0 : 0.0
    // SessionManagementScreen needs a non-TextField focus target before a
    // successful unlock response. This preserves the upstream Qt
    // shutdown workaround while keeping the visual submit affordance local.
    property alias unlockButton: submitButton

    signal unlockRequested()

    implicitWidth: hasInput ? filledFieldWidth : emptyFieldWidth

    Behavior on implicitWidth {
        enabled: !MeoTheme.reduceMotion
        NumberAnimation {
            duration: MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }

    Behavior on submitMorphProgress {
        enabled: !MeoTheme.reduceMotion
        NumberAnimation {
            duration: MeoTheme.motionDurationShapeSettle
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasized
        }
    }
    implicitHeight: 64 * MeoTheme.globalScale
    leftPadding: 64 * MeoTheme.globalScale
    rightPadding: 64 * MeoTheme.globalScale
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    // KScreenLocker uses an invisible focused field to wake from the ambient
    // screen. Do not repaint a cursor until this presentation is visible.
    cursorVisible: visible
    echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
    font.family: MeoTheme.typefacePlain
    font.pixelSize: MeoTheme.bodyLarge.size * MeoTheme.globalScale
    font.weight: MeoTheme.bodyLarge.weight
    color: MeoTheme.contentOnSurface
    placeholderTextColor: MeoTheme.contentOnSurfaceVariant
    selectionColor: Qt.rgba(MeoTheme.primary.r, MeoTheme.primary.g, MeoTheme.primary.b, 0.28)
    selectedTextColor: MeoTheme.contentOnSurface

    Accessible.name: accessibleLabel
    Accessible.description: qsTr("Enter your password to unlock")

    onAccepted: unlockRequested()

    background: Rectangle {
        radius: height / 2
        color: MeoTheme.surfaceContainer
        border.width: field.activeFocus ? 2 * MeoTheme.globalScale : MeoTheme.strokeWidthThin
        border.color: field.activeFocus ? MeoTheme.primary : MeoTheme.outlineVariant

        Behavior on border.color {
            enabled: !MeoTheme.reduceMotion
            ColorAnimation {
                duration: MeoTheme.motionDurationState
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MeoTheme.motionEasingStandard
            }
        }
    }

    MeoIconButton {
        anchors.left: parent.left
        anchors.leftMargin: MeoTheme.space8
        anchors.verticalCenter: parent.verticalCenter
        type: "standard"
        size: "s"
        icon.name: field.passwordVisible ? "visibility"
                                         : field.fingerprintAvailable ? "fingerprint"
                                         : field.smartcardAvailable ? "badge"
                                         : "lock"
        Accessible.name: field.passwordVisible ? qsTr("Hide password") : qsTr("Show password")
        onClicked: field.passwordVisible = !field.passwordVisible
    }

    Button {
        id: submitButton
        objectName: "meoLockScreenSubmitButton"
        anchors.right: parent.right
        anchors.rightMargin: MeoTheme.space8
        anchors.verticalCenter: parent.verticalCenter
        width: 48 * MeoTheme.globalScale
        height: width
        padding: 0
        enabled: field.enabled && field.hasInput
        hoverEnabled: true
        Accessible.name: qsTr("Unlock")
        onClicked: field.unlockRequested()

        background: Item {
            MeoShapeMorph {
                anchors.fill: parent
                anchors.margins: 4 * MeoTheme.globalScale
                fromShape: "Circle"
                toShape: "Arrow"
                morphProgress: field.submitMorphProgress
                rotationAngle: 90
                color: field.hasInput ? MeoTheme.primary : MeoTheme.surfaceContainerHigh
                scale: field.hasInput
                       ? (submitButton.pressed ? 0.68 : submitButton.hovered ? 0.84 : 0.76)
                       : 1.0

                Behavior on scale {
                    enabled: !MeoTheme.reduceMotion
                    NumberAnimation {
                        duration: MeoTheme.motionDurationShort4
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                    }
                }
            }
        }

        contentItem: MeoIcon {
            anchors.centerIn: parent
            visible: !field.hasInput
            icon: "arrow_forward"
            size: 22 * MeoTheme.globalScale
            color: MeoTheme.contentOnSurfaceVariant
        }
    }
}
