import QtQuick
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0

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
    onOpened: {
        while (stack.depth > 1)
            stack.pop()
    }

    contentItem: Item {
        anchors.fill: parent
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
