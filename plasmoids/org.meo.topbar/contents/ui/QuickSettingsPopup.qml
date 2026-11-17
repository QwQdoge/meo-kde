import QtQuick
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0 as MeoSystem

MeoMotionPopup {
    id: quickSettingsPopup
    y: ShellMetrics.topBarHeight + ShellMetrics.popupGap
    x: parent.width - width - ShellMetrics.screenMargin
    width: Math.min(ShellMetrics.quickSettingsWidth + 40 * MeoTheme.globalScale,
                    Screen.width - 2 * ShellMetrics.screenMargin)
    height: Math.min(ShellMetrics.quickSettingsHeight + 40 * MeoTheme.globalScale,
                     Screen.height - ShellMetrics.topBarHeight - 3 * ShellMetrics.screenMargin)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape
    presentation: MeoMotionPopup.Dialog
    transformOrigin: Item.TopRight
    // Opens like macOS Control Center: it grows out of the status corner
    // (top right) instead of fading in place.
    entranceScale: 0.9
    // Frosted like the other shell popups: translucent with SurfaceTransparency
    // (thinner over real blur, which DialogBlur requests for this window).
    readonly property color baseSurface: MeoTheme.surfaceContainerHigh
    surfaceColor: MeoSystem.ShellAppearance.transparency
                  ? Qt.rgba(baseSurface.r, baseSurface.g, baseSurface.b,
                            MeoTheme.surfaceAlpha(MeoSystem.ShellAppearance.blur ? 0.74 : 0.88))
                  : baseSurface

    // The content settles in just after the surface: it drops 8dp and fades
    // in, which gives the opening some depth.
    Connections {
        target: quickSettingsPopup
        function onAboutToShow() {
            if (MeoTheme.reduceMotion) {
                contentRoot.opacity = 1
                contentShift.y = 0
                return
            }
            contentRoot.opacity = 0
            contentShift.y = -8 * MeoTheme.globalScale
            contentReveal.restart()
        }
    }
    ParallelAnimation {
        id: contentReveal
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: contentRoot; property: "opacity"; to: 1
                duration: 220
                easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandardDecelerate
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: contentShift; property: "y"; to: 0
                duration: 380
                easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
            }
        }
    }
    onOpened: {
        while (stack.depth > 1)
            stack.pop()
    }

    contentItem: Item {
        id: contentRoot
        anchors.fill: parent
        transform: Translate { id: contentShift }
        anchors.margins: 20 * MeoTheme.globalScale
        QQC2.StackView {
            id: stack
            anchors.fill: parent
            clip: true
            initialItem: QuickSettingsHome {
                onWifiDetailsRequested: stack.push(wifiPageComponent)
                onBluetoothDetailsRequested: stack.push(bluetoothPageComponent)
                onPowerDetailsRequested: stack.push(powerPageComponent)
                onPowerRequested: powerMenu.open()
            }
            pushEnter: Transition {
                NumberAnimation { property: "x"; from: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale; to: 0; duration: MeoTheme.motionDurationPage; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasized }
                NumberAnimation { property: "opacity"; from: MeoTheme.reduceMotion ? 1 : 0; to: 1; duration: MeoTheme.motionDurationPage; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
            }
            popExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale; duration: MeoTheme.motionDurationPage; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasized }
                NumberAnimation { property: "opacity"; from: 1; to: MeoTheme.reduceMotion ? 1 : 0; duration: MeoTheme.motionDurationPage; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
            }
        }
    }
    Component { id: wifiPageComponent; WifiPage { onBackRequested: stack.pop() } }
    Component { id: bluetoothPageComponent; BluetoothPage { onBackRequested: stack.pop() } }
    Component { id: powerPageComponent; PowerPage { onBackRequested: stack.pop() } }
    SessionMenu {
        id: powerMenu
        closeTarget: quickSettingsPopup
    }
}
