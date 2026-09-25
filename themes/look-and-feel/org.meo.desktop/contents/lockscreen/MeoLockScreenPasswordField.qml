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
    readonly property var maskShapes: [
        "Slanted", "Arch", "Fan", "Arrow", "SemiCircle", "Triangle",
        "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny",
        "Cookie4Sided", "Ghostish", "SoftBurst"
    ]
    readonly property real maskShapeSize: 18 * MeoTheme.globalScale
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
    // When hidden, the real TextField still owns the credential, cursor,
    // editing and IME contract. Its glyphs are visually replaced by a
    // count-only expressive mask below; no password character is copied into
    // another model or property.
    color: passwordVisible ? MeoTheme.contentOnSurface : "transparent"
    font.family: MeoTheme.typefacePlain
    font.pixelSize: MeoTheme.bodyLarge.size * MeoTheme.globalScale
    font.weight: MeoTheme.bodyLarge.weight
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

    MeoIcon {
        anchors.left: parent.left
        anchors.leftMargin: 20 * MeoTheme.globalScale
        anchors.verticalCenter: parent.verticalCenter
        visible: !field.hasInput
        icon: field.fingerprintAvailable ? "fingerprint"
              : field.smartcardAvailable ? "badge"
              : "lock"
        size: 22 * MeoTheme.globalScale
        color: field.fingerprintAvailable || field.smartcardAvailable
               ? MeoTheme.secondary : MeoTheme.contentOnSurfaceVariant
        Accessible.ignored: true
    }

    MeoIconButton {
        anchors.left: parent.left
        anchors.leftMargin: MeoTheme.space8
        anchors.verticalCenter: parent.verticalCenter
        visible: field.hasInput
        type: "standard"
        size: "s"
        icon.name: field.passwordVisible ? "visibility_off" : "visibility"
        Accessible.name: field.passwordVisible ? qsTr("Hide password") : qsTr("Show password")
        onClicked: field.passwordVisible = !field.passwordVisible
    }

    Item {
        id: expressivePasswordMask
        anchors.left: parent.left
        anchors.leftMargin: field.leftPadding
        anchors.right: parent.right
        anchors.rightMargin: field.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        height: Math.max(32 * MeoTheme.globalScale, field.maskShapeSize * 1.6)
        visible: field.hasInput && !field.passwordVisible
        clip: true
        Accessible.ignored: true

        ListView {
            id: maskList
            anchors.centerIn: parent
            width: Math.min(parent.width, contentWidth)
            height: parent.height
            orientation: ListView.Horizontal
            spacing: MeoTheme.space4
            interactive: false
            model: field.passwordVisible ? 0 : field.text.length
            contentX: Math.max(0, contentWidth - width)

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "scale"
                        from: 0.35
                        to: 1.0
                        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort4
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0.0
                        to: 1.0
                        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort4
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingStandard
                    }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "scale"
                        to: 0.55
                        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort3
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingEmphasizedAccelerate
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 0.0
                        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort3
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingStandard
                    }
                }
            }

            delegate: Item {
                required property int index

                width: field.maskShapeSize * 1.35
                height: maskList.height

                MeoShape {
                    anchors.centerIn: parent
                    width: field.maskShapeSize
                    height: width
                    type: field.maskShapes[index % field.maskShapes.length]
                    color: MeoTheme.contentOnSurface
                    rotationAngle: (index % 2 === 0 ? -1 : 1) * (index % 4) * 7
                }
            }
        }
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
