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
                                ? MeoI18n.translator.i18n("Network disconnected")
                                : MeoI18n.translator.i18n("Wi-Fi off"))
        },
        {
            id: "bluetooth",
            iconName: "bluetooth",
            text: "",
            available: root.showBluetooth && root.bluetoothConnected,
            active: root.bluetoothConnected,
            attention: false,
            accessibleName: MeoI18n.translator.i18n("Bluetooth connected")
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
                            ? MeoI18n.translator.i18n("Volume muted")
                            : MeoI18n.translator.i18n("Volume %1 percent").arg(SystemState.volumePercent)
        },
        {
            id: "battery",
            iconName: SystemState.batteryCharging ? "battery_charging_full" : "battery_full",
            text: root.batteryDisplay >= 2
                  ? (root.batteryDisplay === 3 && SystemState.batteryCharging
                     ? MeoI18n.translator.i18n("Charging · %1%").arg(SystemState.batteryPercent)
                     : SystemState.batteryPercent + "%")
                  : "",
            available: root.batteryDisplay > 0 && SystemState.batteryAvailable,
            active: SystemState.batteryCharging,
            attention: false,
            accessibleName: SystemState.batteryCharging
                            ? MeoI18n.translator.i18n("Charging, %1 percent").arg(SystemState.batteryPercent)
                            : MeoI18n.translator.i18n("Battery %1 percent").arg(SystemState.batteryPercent)
        }
    ]

    implicitWidth: statusContent.implicitWidth + leftPadding + rightPadding
    implicitHeight: 28 * MeoTheme.globalScale
    leftPadding: MeoTheme.space8
    rightPadding: MeoTheme.space8
    Accessible.name: MeoI18n.translator.i18n("System status")
    Accessible.description: statusContent.statusDescription()
    hoverEnabled: true
    activeFocusOnTab: true
    onClicked: quickSettingsRequested()
            MeoInteractionMotion {
                id: interactionMotion
                hovered: root.hovered
                pressed: root.down
                active: root.active
                motionProfile: "pixel"
                speed: "fast"
            }

    transform: [
        Translate { y: interactionMotion.resolvedOffsetY },
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: interactionMotion.resolvedScale
            yScale: interactionMotion.resolvedScale
        }
    ]

    background: ShellTriggerSurface {
        id: statusBackground
        hovered: root.hovered
        pressed: root.down
        focused: root.visualFocus
        active: root.active
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
