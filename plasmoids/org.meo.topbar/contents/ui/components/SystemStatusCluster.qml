import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.AbstractButton {
    id: root

    signal quickSettingsRequested()
    property real textScale: 1.0
    property bool showNetwork: true
    property bool showBluetooth: true
    property bool showVolume: true
    // 0 hidden, 1 icon, 2 icon plus percentage, 3 includes charging state.
    property int batteryDisplay: 2

    implicitWidth: statusContent.implicitWidth + leftPadding + rightPadding
    // Keep the compact trigger visually present when idle.  A transparent
    // hit area made the cluster read like orphaned tray icons and hid its MD3
    // rounded boundary in the panel.
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

    background: MeoShape {
        id: statusBackground
        type: "pill"
        radius: height / 2
        color: root.hovered || root.down
               ? MeoTheme.surfaceContainerHighest
               : MeoTheme.surfaceContainer
        strokeColor: MeoTheme.outlineVariant
        // The installed MeoUI singleton can be older while a live Plasma
        // session is reloading.  Keep the named thin token when present and
        // fall back to the already-exported scale token during that handoff.
        strokeWidth: typeof MeoTheme.strokeWidthThin === "number"
                     ? MeoTheme.strokeWidthThin
                     : MeoTheme.globalScale

        // Use the shared MD3 state layer rather than changing the base surface
        // directly.  This provides a consistent hover, press and ripple cue
        // without changing the compact trigger's geometry.
        MeoStateLayer {
            anchors.fill: parent
            radius: statusBackground.radius
            color: MeoTheme.primary
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
            color: MeoTheme.onSurface
        }
        MeoIcon {
            visible: root.showBluetooth && SystemState.bluetoothAvailable && SystemState.bluetoothEnabled
            icon: "bluetooth"
            fill: true
            size: 18
            color: MeoTheme.onSurface
        }
        MeoIcon {
            visible: root.showVolume && SystemState.audioAvailable
            icon: SystemState.audioMuted ? "volume_off"
                  : (SystemState.volumePercent < 35 ? "volume_down" : "volume_up")
            size: 18
            color: MeoTheme.onSurface
        }
        RowLayout {
            visible: root.batteryDisplay > 0 && SystemState.batteryAvailable
            spacing: 3 * MeoTheme.globalScale
            MeoIcon {
                icon: SystemState.batteryCharging ? "battery_charging_full" : "battery_full"
                size: 18
                color: MeoTheme.onSurface
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
                color: MeoTheme.onSurface
            }
        }
    }
}
