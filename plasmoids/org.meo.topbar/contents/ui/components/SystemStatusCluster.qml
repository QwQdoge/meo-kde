import QtQuick
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.AbstractButton {
    id: root

    signal quickSettingsRequested()
    property bool active: false
    property real textScale: 1.0
    property bool showNetwork: true
    property bool showBluetooth: true
    property bool showVolume: true
    // 0 hidden, 1 icon, 2 icon plus percentage, 3 includes charging state.
    property int batteryDisplay: 2
    readonly property bool bluetoothConnected: {
        const devices = SystemState.bluetoothDevices
        for (let index = 0; index < devices.length; ++index) {
            if (devices[index].connected)
                return true
        }
        return false
    }
    // MeoKDE owns this adapter only: the generic presentation and all visual
    // roles live in MeoUI's MeoStatusStrip.  Keep the compact model bound to
    // the real SystemState properties, never a local optimistic toggle.
    readonly property var statusModel: [
        {
            id: "network",
            iconName: SystemState.wirelessEnabled
                      ? (SystemState.networkConnected ? "wifi" : "wifi_find")
                      : "wifi_off",
            text: "",
            available: root.showNetwork && SystemState.networkAvailable,
            active: SystemState.networkConnected,
            attention: SystemState.wirelessEnabled && !SystemState.networkConnected,
            accessibleName: SystemState.networkName
                            || (SystemState.wirelessEnabled
                                ? qsTr("Network disconnected")
                                : qsTr("Wi-Fi off"))
        },
        {
            id: "bluetooth",
            iconName: "bluetooth",
            text: "",
            available: root.showBluetooth && root.bluetoothConnected,
            active: root.bluetoothConnected,
            attention: false,
            accessibleName: qsTr("Bluetooth connected")
        },
        {
            id: "audio",
            iconName: SystemState.audioMuted ? "volume_off"
                      : (SystemState.volumePercent < 35 ? "volume_down" : "volume_up"),
            text: "",
            available: root.showVolume && SystemState.audioAvailable,
            active: !SystemState.audioMuted,
            attention: false,
            accessibleName: SystemState.audioMuted
                            ? qsTr("Volume muted")
                            : qsTr("Volume %1 percent").arg(SystemState.volumePercent)
        },
        {
            id: "battery",
            iconName: SystemState.batteryCharging ? "battery_charging_full" : "battery_full",
            text: root.batteryDisplay >= 2
                  ? (root.batteryDisplay === 3 && SystemState.batteryCharging
                     ? qsTr("Charging · %1%").arg(SystemState.batteryPercent)
                     : SystemState.batteryPercent + "%")
                  : "",
            available: root.batteryDisplay > 0 && SystemState.batteryAvailable,
            active: SystemState.batteryCharging,
            attention: false,
            accessibleName: SystemState.batteryCharging
                            ? qsTr("Charging, %1 percent").arg(SystemState.batteryPercent)
                            : qsTr("Battery %1 percent").arg(SystemState.batteryPercent)
        }
    ]

    implicitWidth: statusContent.implicitWidth + leftPadding + rightPadding
    implicitHeight: 28 * MeoTheme.globalScale
    leftPadding: MeoTheme.space8
    rightPadding: MeoTheme.space8
    Accessible.name: qsTr("System status")
    Accessible.description: statusContent.statusDescription()
    onClicked: quickSettingsRequested()

    MeoSpringValue {
        id: pressSpring
        value: 1
        targetValue: root.down ? 0.94 : 1
        spring: MeoMotion.fastSpatial
    }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: pressSpring.value
        yScale: pressSpring.value
    }

    background: MeoShape {
        id: statusBackground
        type: root.hovered && !root.down && !root.active ? "round" : "pill"
        radius: root.hovered && !root.down && !root.active
                ? MeoTheme.shapeSmall : height / 2
        color: root.active
               ? MeoTheme.primaryContainer
               : (root.hovered || root.down
                  ? MeoTheme.surfaceContainerHighest
                  : "transparent")
        strokeColor: "transparent"
        strokeWidth: 0

        Behavior on color {
            ColorAnimation {
                duration: MeoTheme.motionDurationEffectDefault
                easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard
            }
        }

        MeoStateLayer {
            anchors.fill: parent
            radius: statusBackground.radius
            color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface
            hovered: root.hovered
            pressed: root.down
            focused: root.activeFocus
        }
    }

    contentItem: MeoStatusStrip {
        id: statusContent
        statusModel: root.statusModel
        active: root.active
        iconSize: 18
        showText: true
        textScale: root.textScale
    }
}
