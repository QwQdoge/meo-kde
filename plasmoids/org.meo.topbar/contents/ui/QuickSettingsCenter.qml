import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.private.sessions 2.0 as Sessions
import MeoUI 1.0
import MeoKDE 1.0

Item {
    id: root

    property string tileOrder: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileSizes: "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
    signal tileLayoutChanged(string order, string sizes)

    implicitWidth: 440 * MeoTheme.globalScale
    implicitHeight: ShellMetrics.quickSettingsHeight
    Layout.minimumWidth: 360 * MeoTheme.globalScale
    Layout.minimumHeight: 420 * MeoTheme.globalScale

    FrostedSurface {
        anchors.fill: parent
        baseColor: MeoTheme.surfaceContainerLow

        QQC2.StackView {
            id: stack
            anchors.fill: parent
            anchors.margins: ShellMetrics.popupContentMargin
            clip: true
            initialItem: QuickSettingsHome {
                tileOrder: root.tileOrder
                tileSizes: root.tileSizes
                onTileLayoutChanged: function(order, sizes) { root.tileLayoutChanged(order, sizes) }
                onWifiDetailsRequested: stack.push(wifiPageComponent)
                onBluetoothDetailsRequested: stack.push(bluetoothPageComponent)
                onAudioDetailsRequested: stack.push(audioPageComponent)
                onPowerDetailsRequested: stack.push(powerPageComponent)
                onPowerRequested: powerMenu.open()
            }
            pushEnter: Transition {
                NumberAnimation {
                    property: "x"
                    from: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale
                    to: 0
                    duration: MeoTheme.motionDurationPage
                    easing.bezierCurve: MeoTheme.motionEasingEmphasized
                }
                NumberAnimation {
                    property: "opacity"
                    from: MeoTheme.reduceMotion ? 1 : 0
                    to: 1
                    duration: MeoTheme.motionDurationPage
                }
            }
            popExit: Transition {
                NumberAnimation {
                    property: "x"
                    from: 0
                    to: MeoTheme.reduceMotion ? 0 : 24 * MeoTheme.globalScale
                    duration: MeoTheme.motionDurationPage
                    easing.bezierCurve: MeoTheme.motionEasingEmphasized
                }
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: MeoTheme.reduceMotion ? 1 : 0
                    duration: MeoTheme.motionDurationPage
                }
            }
        }
    }

    Component { id: wifiPageComponent; WifiPage { onBackRequested: stack.pop() } }
    Component { id: bluetoothPageComponent; BluetoothPage { onBackRequested: stack.pop() } }
    Component { id: audioPageComponent; AudioPage { onBackRequested: stack.pop() } }
    Component { id: powerPageComponent; PowerPage { onBackRequested: stack.pop() } }

    Sessions.SessionManagement {
        id: sessionManagement
    }

    QQC2.Menu {
        id: powerMenu

        QQC2.MenuItem {
            text: qsTr("Sleep")
            visible: sessionManagement.canSuspend
            onTriggered: sessionManagement.suspend()
        }
        QQC2.MenuItem {
            text: qsTr("Restart")
            visible: sessionManagement.canReboot
            onTriggered: sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt)
        }
        QQC2.MenuItem {
            text: qsTr("Shut down")
            visible: sessionManagement.canShutdown
            onTriggered: sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: qsTr("Sign out")
            visible: sessionManagement.canLogout
            onTriggered: sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt)
        }
    }
}
