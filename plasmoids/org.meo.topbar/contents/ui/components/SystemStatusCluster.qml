import QtQuick
import QtQuick.Layouts
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

    implicitWidth: statusContent.implicitWidth + leftPadding + rightPadding
    implicitHeight: 28 * MeoTheme.globalScale
    leftPadding: MeoTheme.space8
    rightPadding: MeoTheme.space8
    Accessible.name: qsTr("System status")
    Accessible.description: [
        SystemState.networkName,
        SystemState.bluetoothEnabled ? qsTr("Bluetooth on") : "",
        SystemState.batteryAvailable ? qsTr("%1 percent battery").arg(SystemState.batteryPercent) : ""
    ].filter(function(value) { return value !== "" }).join(", ")
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
        type: "pill"
        radius: height / 2
        color: root.active
               ? MeoTheme.primaryContainer
               : (root.hovered || root.down
                  ? MeoTheme.surfaceContainerHighest
                  : Qt.rgba(0, 0, 0, 0))
        strokeColor: Qt.rgba(0, 0, 0, 0)
        strokeWidth: 0

        Behavior on color {
            ColorAnimation {
                duration: MeoTheme.motionDurationEffectDefault
                easing.bezierCurve: MeoTheme.motionEasingStandard
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

    contentItem: RowLayout {
        id: statusContent
        spacing: MeoTheme.space4 + MeoTheme.space2
        MeoIcon {
            visible: root.showNetwork && SystemState.networkAvailable
            icon: SystemState.wirelessEnabled
                  ? (SystemState.networkConnected ? "wifi" : "wifi_find") : "wifi_off"
            size: 18
            color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
        }
        MeoIcon {
            // Bluetooth being merely enabled is not useful persistent status.
            // Match phone shells by surfacing it only for an active connection.
            visible: root.showBluetooth && root.bluetoothConnected
            icon: "bluetooth"
            fill: true
            size: 18
            color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.primary
        }
        MeoIcon {
            visible: root.showVolume && SystemState.audioAvailable
            icon: SystemState.audioMuted ? "volume_off"
                  : (SystemState.volumePercent < 35 ? "volume_down" : "volume_up")
            size: 18
            color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
        }
        RowLayout {
            visible: root.batteryDisplay > 0 && SystemState.batteryAvailable
            spacing: 3 * MeoTheme.globalScale
            MeoIcon {
                icon: SystemState.batteryCharging ? "battery_charging_full" : "battery_full"
                size: 18
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
            }
            MeoText {
                visible: root.batteryDisplay >= 2
                text: root.batteryDisplay === 3 && SystemState.batteryCharging
                      ? qsTr("Charging · %1%").arg(SystemState.batteryPercent)
                      : SystemState.batteryPercent + "%"
                typeRole: "label"
                typeSize: "small"
                emphasized: true
                fontScaleOverride: root.textScale
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
            }
        }
    }
}
