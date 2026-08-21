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

    ColumnLayout {
        anchors.fill: parent
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: qsTr("Bluetooth")
            subtitle: SystemState.bluetoothEnabled ? qsTr("Connect and manage devices") : qsTr("Bluetooth is off")
            onBackRequested: root.backRequested()
            trailingContent: Component {
                RowLayout {
                    spacing: MeoTheme.space4
                    MeoSwitch {
                        size: "s"
                        checked: SystemState.bluetoothEnabled
                        enabled: SystemState.bluetoothAvailable && !SystemState.bluetoothBusy
                        Accessible.name: qsTr("Bluetooth")
                        onToggled: function(checked) { SystemState.bluetoothEnabled = checked }
                    }
                    MeoIconButton {
                        type: "standard"
                        size: "m"
                        icon.name: SystemState.bluetoothDiscovering ? "stop" : "refresh"
                        enabled: SystemState.bluetoothEnabled && !SystemState.bluetoothBusy
                        Accessible.name: SystemState.bluetoothDiscovering
                                         ? qsTr("Stop Bluetooth discovery") : qsTr("Discover Bluetooth devices")
                        onClicked: {
                            if (SystemState.bluetoothDiscovering) SystemState.stopBluetoothDiscovery()
                            else SystemState.startBluetoothDiscovery()
                        }
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
                text: qsTr("Looking for nearby devices…")
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
                                       ? qsTr("Connected · %1%").arg(modelData.batteryPercent) : qsTr("Connected"))
                                    : (modelData.paired ? qsTr("Paired") : qsTr("Available"))
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
                                Accessible.name: qsTr("Forget %1").arg(modelData.name)
                                onClicked: SystemState.forgetBluetoothDevice(modelData.address)
                            }
                        }
                    }
                    onClicked: SystemState.toggleBluetoothDevice(modelData.address)
                }
            }

            PopupEmptyState {
                anchors.fill: parent
                visible: !bluetoothList.visible
                iconName: "bluetooth"
                title: !SystemState.bluetoothAvailable ? qsTr("Bluetooth is unavailable")
                       : (!SystemState.bluetoothEnabled ? qsTr("Bluetooth is turned off") : qsTr("No devices found"))
                description: !SystemState.bluetoothAvailable
                             ? qsTr("Check that a Bluetooth adapter and the BlueZ service are available.")
                             : (!SystemState.bluetoothEnabled
                                ? qsTr("Turn on Bluetooth to connect accessories.")
                                : qsTr("Put the device in pairing mode, then search again."))
                actionText: !SystemState.bluetoothAvailable ? qsTr("Bluetooth Settings")
                            : (!SystemState.bluetoothEnabled ? qsTr("Turn on Bluetooth")
                                                            : (SystemState.bluetoothDiscovering ? "" : qsTr("Find devices")))
                onActionRequested: {
                    if (!SystemState.bluetoothAvailable)
                        Qt.openUrlExternally("systemsettings:kcm_bluetooth")
                    else if (!SystemState.bluetoothEnabled)
                        SystemState.bluetoothEnabled = true
                    else
                        SystemState.startBluetoothDiscovery()
                }
            }
        }
    }
}
