import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

Item {
    id: root
    signal backRequested()
    implicitWidth: ShellMetrics.quickSettingsWidth
    implicitHeight: ShellMetrics.quickSettingsHeight

    // The compact surface is deliberately limited to already-authorized
    // operations.  A pairing request can involve a PIN, passkey, numeric
    // comparison, or an authorization prompt, so it belongs to the primary
    // Meo Settings Bluetooth flow rather than being implicitly started by a
    // Quick Settings tile tap.
    function openMeoBluetoothSettings() {
        if (Qt.openUrlExternally("applications:org.meo.settings.bluetooth.desktop"))
            return
        Qt.openUrlExternally("applications:org.meo.settings.desktop")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: MeoI18n.translator.i18n("Bluetooth")
            subtitle: SystemState.bluetoothEnabled ? MeoI18n.translator.i18n("Connect and manage devices") : MeoI18n.translator.i18n("Bluetooth is off")
            onBackRequested: root.backRequested()
            trailingContent: Component {
                RowLayout {
                    spacing: MeoTheme.space4
                    MeoSwitch {
                        size: "s"
                        checked: SystemState.bluetoothEnabled
                        enabled: SystemState.bluetoothAvailable && !SystemState.bluetoothBusy
                        Accessible.name: MeoI18n.translator.i18n("Bluetooth")
                        onToggled: function(checked) { SystemState.bluetoothEnabled = checked }
                    }
                    MeoIconButton {
                        type: "standard"
                        size: "m"
                        icon.name: SystemState.bluetoothDiscovering ? "stop" : "refresh"
                        enabled: SystemState.bluetoothEnabled && !SystemState.bluetoothBusy
                        Accessible.name: SystemState.bluetoothDiscovering
                                         ? MeoI18n.translator.i18n("Stop Bluetooth discovery") : MeoI18n.translator.i18n("Discover Bluetooth devices")
                        onClicked: {
                            if (SystemState.bluetoothDiscovering) SystemState.stopBluetoothDiscovery()
                            else SystemState.startBluetoothDiscovery()
                        }
                    }
                    MeoIconButton {
                        type: "standard"
                        size: "m"
                        icon.name: "settings"
                        Accessible.name: MeoI18n.translator.i18n("Open Bluetooth in Meo Settings")
                        onClicked: root.openMeoBluetoothSettings()
                    }
                }
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: SystemState.operationError
            dismissible: true
            onDismissed: SystemState.clearOperationError()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: SystemState.bluetoothDiscovering
            spacing: MeoTheme.space8
            MeoLoadingIndicator { indeterminate: true; width: 20 * MeoTheme.globalScale; height: width }
            MeoText {
                text: MeoI18n.translator.i18n("Looking for nearby devices…")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.onSurfaceVariant
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: bluetoothList
                anchors.fill: parent
                visible: SystemState.bluetoothAvailable && SystemState.bluetoothEnabled
                         && SystemState.bluetoothDevices.length > 0
                clip: true
                spacing: MeoTheme.space4
                model: SystemState.bluetoothDevices
                delegate: MeoListItem {
                    required property var modelData
                    width: bluetoothList.width
                    isDense: true
                    isSegmented: true
                    roundingStrategy: "all"
                    headline: modelData.name
                    supportingText: modelData.connected
                                    ? (modelData.batteryAvailable
                                       ? MeoI18n.translator.i18n("Connected · %1%").arg(modelData.batteryPercent) : MeoI18n.translator.i18n("Connected"))
                                    : (modelData.paired ? MeoI18n.translator.i18n("Paired")
                                                        : MeoI18n.translator.i18n("Available · Set up in Meo Settings"))
                    leadingIcon: modelData.icon
                    selected: modelData.connected
                    interactive: !SystemState.bluetoothBusy
                    trailingComponent: Component {
                        RowLayout {
                            spacing: MeoTheme.space4
                            MeoIcon { visible: modelData.connected; icon: "check"; size: 18; fill: true; color: MeoTheme.primary }
                            MeoIconButton {
                                visible: modelData.paired && !modelData.connected
                                type: "standard"
                                size: "s"
                                icon.name: "delete"
                                Accessible.name: MeoI18n.translator.i18n("Forget %1").arg(modelData.name)
                                onClicked: SystemState.forgetBluetoothDevice(modelData.address)
                            }
                        }
                    }
                    onClicked: {
                        if (!modelData.paired) {
                            root.openMeoBluetoothSettings()
                            return
                        }
                        SystemState.toggleBluetoothDevice(modelData.address)
                    }
                }
            }

            PopupEmptyState {
                anchors.fill: parent
                visible: !bluetoothList.visible
                iconName: "bluetooth"
                title: !SystemState.bluetoothAvailable ? MeoI18n.translator.i18n("Bluetooth is unavailable")
                       : (!SystemState.bluetoothEnabled ? MeoI18n.translator.i18n("Bluetooth is turned off") : MeoI18n.translator.i18n("No devices found"))
                description: !SystemState.bluetoothAvailable
                             ? MeoI18n.translator.i18n("Check that a Bluetooth adapter and the BlueZ service are available.")
                             : (!SystemState.bluetoothEnabled
                                ? MeoI18n.translator.i18n("Turn on Bluetooth to connect accessories.")
                                : MeoI18n.translator.i18n("Put the device in pairing mode, then search again."))
                actionText: !SystemState.bluetoothAvailable ? MeoI18n.translator.i18n("Open Bluetooth in Meo Settings")
                            : (!SystemState.bluetoothEnabled ? MeoI18n.translator.i18n("Turn on Bluetooth")
                                                            : (SystemState.bluetoothDiscovering ? "" : MeoI18n.translator.i18n("Find devices")))
                onActionRequested: {
                    if (!SystemState.bluetoothAvailable)
                        root.openMeoBluetoothSettings()
                    else if (!SystemState.bluetoothEnabled)
                        SystemState.bluetoothEnabled = true
                    else
                        SystemState.startBluetoothDiscovery()
                }
            }
        }
    }
}
