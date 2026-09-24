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
    property string accessibleLabel: qsTr("Password")
    // SessionManagementScreen needs a non-TextField focus target before a
    // successful unlock response. This preserves the upstream Qt
    // shutdown workaround while keeping the visual submit affordance local.
    property alias unlockButton: submitButton

    signal unlockRequested()

    implicitWidth: 360 * MeoTheme.globalScale
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
        icon.name: field.passwordVisible ? "visibility" : "lock"
        Accessible.name: field.passwordVisible ? qsTr("Hide password") : qsTr("Show password")
        onClicked: field.passwordVisible = !field.passwordVisible
    }

    MeoIconButton {
        id: submitButton
        objectName: "meoLockScreenSubmitButton"
        anchors.right: parent.right
        anchors.rightMargin: MeoTheme.space8
        anchors.verticalCenter: parent.verticalCenter
        type: "filled"
        size: "s"
        icon.name: "arrow_forward"
        enabled: field.enabled && field.text.length > 0
        Accessible.name: qsTr("Unlock")
        onClicked: field.unlockRequested()
    }
}
