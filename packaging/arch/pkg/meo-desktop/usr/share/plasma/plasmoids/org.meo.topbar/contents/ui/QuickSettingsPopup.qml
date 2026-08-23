import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.private.sessions 2.0 as Sessions
import MeoUI 1.0
import MeoKDE 1.0

QQC2.Popup {
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
    transformOrigin: Item.TopRight
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1; to: 0.985; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
    }
    background: FrostedSurface {}
    Sessions.SessionManagement { id: sessionManagement }
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
                onPowerRequested: powerMenu.popup()
            }
            pushEnter: Transition {
                NumberAnimation { property: "x"; from: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale; to: 0; duration: MeoTheme.motionDurationPage; easing.bezierCurve: MeoTheme.motionEasingEmphasized }
                NumberAnimation { property: "opacity"; from: MeoTheme.reduceMotion ? 1 : 0; to: 1; duration: MeoTheme.motionDurationPage }
            }
            popExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale; duration: MeoTheme.motionDurationPage; easing.bezierCurve: MeoTheme.motionEasingEmphasized }
                NumberAnimation { property: "opacity"; from: 1; to: MeoTheme.reduceMotion ? 1 : 0; duration: MeoTheme.motionDurationPage }
            }
        }
    }
    Component { id: wifiPageComponent; WifiPage { onBackRequested: stack.pop() } }
    Component { id: bluetoothPageComponent; BluetoothPage { onBackRequested: stack.pop() } }
    Component { id: powerPageComponent; PowerPage { onBackRequested: stack.pop() } }
    QQC2.Menu {
        id: powerMenu
        background: MeoMotionSurface {
            color: MeoTheme.surfaceContainerHighest
            radius: ShellMetrics.radiusMedium
            elevation: 3
        }
        QQC2.MenuItem { text: qsTr("Sleep"); visible: sessionManagement.canSuspend; onTriggered: { sessionManagement.suspend(); quickSettingsPopup.close() } }
        QQC2.MenuItem { text: qsTr("Restart"); visible: sessionManagement.canReboot; onTriggered: { sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt); quickSettingsPopup.close() } }
        QQC2.MenuItem { text: qsTr("Shut down"); visible: sessionManagement.canShutdown; onTriggered: { sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt); quickSettingsPopup.close() } }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: qsTr("Sign out"); visible: sessionManagement.canLogout; onTriggered: { sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt); quickSettingsPopup.close() } }
    }
}
