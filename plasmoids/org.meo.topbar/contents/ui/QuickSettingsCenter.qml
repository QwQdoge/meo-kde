import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

Item {
    id: root

    property string tileOrder: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileSizes: "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
    property string tileVisibility: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileDensity: "comfortable"
    property bool revealActive: true
    signal tileLayoutChanged(string order, string sizes, string visibility, string density)

    function prepareToClose() {
        if (stack.currentItem && stack.currentItem.prepareToClose)
            stack.currentItem.prepareToClose()
        if (stack.depth > 1)
            stack.pop(null, QQC2.StackView.Immediate)
        if (stack.currentItem && stack.currentItem.prepareToClose)
            stack.currentItem.prepareToClose()
        powerMenu.close()
    }

    implicitWidth: ShellMetrics.quickSettingsWidth
    implicitHeight: ShellMetrics.quickSettingsHeight
    Layout.minimumWidth: 280 * MeoTheme.globalScale
    Layout.minimumHeight: 360 * MeoTheme.globalScale

    MeoRevealMotion {
        id: revealMotion
        active: root.revealActive
        animateOnCompleted: true
        motionProfile: "pixel"
        speed: "default"
        // A top-right anchored popout starts slightly toward its trigger and
        // resolves on the shared 2D spring. The primitive, not this shell
        // surface, owns the actual motion physics.
        closedOffsetX: MeoMotion.popupOffset(motionProfile) * 0.5 * MeoTheme.globalScale
        closedOffsetY: -MeoMotion.popupOffset(motionProfile) * MeoTheme.globalScale
    }

    transform: [
        Translate {
            x: revealMotion.resolvedOffsetX
            y: revealMotion.resolvedOffsetY
        },
        Scale {
            origin.x: root.width
            origin.y: 0
            xScale: revealMotion.resolvedScale
            yScale: revealMotion.resolvedScale
        }
    ]

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
                tileVisibility: root.tileVisibility
                tileDensity: root.tileDensity
                onTileLayoutChanged: function(order, sizes, visibility, density) {
                    root.tileLayoutChanged(order, sizes, visibility, density)
                }
                onWifiDetailsRequested: stack.push(wifiPageComponent)
                onBluetoothDetailsRequested: stack.push(bluetoothPageComponent)
                onAudioDetailsRequested: stack.push(audioPageComponent)
                onPowerDetailsRequested: stack.push(powerPageComponent)
                onPowerRequested: powerMenu.open()
                onEditRequested: stack.push(editorPageComponent, {
                    "tileOrder": root.tileOrder,
                    "tileSizes": root.tileSizes,
                    "tileVisibility": root.tileVisibility,
                    "tileDensity": root.tileDensity
                })
            }

            pushEnter: Transition {
                NumberAnimation { property: "x"; from: MeoMotion.pageOffset("pixel"); to: 0; duration: MeoMotion.navigation; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoMotion.navigation }
            }
            pushExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: -MeoMotion.pageOffset("pixel") * 0.35; duration: MeoMotion.navigation; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedAccelerate }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: MeoMotion.navigation }
            }
            popEnter: Transition {
                NumberAnimation { property: "x"; from: -MeoMotion.pageOffset("pixel") * 0.35; to: 0; duration: MeoMotion.navigation; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoMotion.navigation }
            }
            popExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: MeoMotion.pageOffset("pixel"); duration: MeoMotion.navigation; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedAccelerate }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: MeoMotion.navigation }
            }
        }

        MeoContextMenu {
            id: powerMenu
            parent: root
            model: [
                { label: MeoI18n.translator.i18n("Lock screen"), icon: "lock", action: function() { SystemState.lockScreen() } },
                { label: MeoI18n.translator.i18n("Log out"), icon: "logout", action: function() { SystemState.logout() } },
                { type: "separator" },
                { label: MeoI18n.translator.i18n("Restart"), icon: "restart_alt", action: function() { SystemState.restart() } },
                { label: MeoI18n.translator.i18n("Shut down"), icon: "power_settings_new", action: function() { SystemState.shutdown() } }
            ]
        }
    }

    Component {
        id: wifiPageComponent
        WifiPage { onBackRequested: stack.pop() }
    }
    Component {
        id: bluetoothPageComponent
        BluetoothPage { onBackRequested: stack.pop() }
    }
    Component {
        id: audioPageComponent
        AudioPage { onBackRequested: stack.pop() }
    }
    Component {
        id: powerPageComponent
        PowerPage { onBackRequested: stack.pop() }
    }
    Component {
        id: editorPageComponent
        QuickSettingsEditor {
            onBackRequested: stack.pop()
            onTileLayoutChanged: function(order, sizes, visibility, density) {
                root.tileLayoutChanged(order, sizes, visibility, density)
            }
        }
    }
}
