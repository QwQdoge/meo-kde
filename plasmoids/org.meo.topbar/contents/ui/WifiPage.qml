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

    function signalIcon(strength) {
        if (strength >= 70) return "signal_wifi_4_bar"
        if (strength >= 40) return "network_wifi_3_bar"
        if (strength >= 20) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: qsTr("Wi-Fi")
            subtitle: SystemState.networkConnected ? SystemState.networkName
                      : (SystemState.wirelessEnabled ? qsTr("Choose a network") : qsTr("Wireless is off"))
            onBackRequested: root.backRequested()
            trailingContent: Component {
                RowLayout {
                    spacing: MeoTheme.space4
                    MeoSwitch {
                        size: "s"
                        checked: SystemState.wirelessEnabled
                        enabled: SystemState.networkAvailable && !SystemState.networkBusy
                        Accessible.name: qsTr("Wi-Fi")
                        onToggled: function(checked) { SystemState.wirelessEnabled = checked }
                    }
                    MeoIconButton {
                        type: "standard"
                        size: "m"
                        icon.name: "refresh"
                        enabled: SystemState.wirelessEnabled && !SystemState.wifiScanning && !SystemState.networkBusy
                        Accessible.name: qsTr("Scan for Wi-Fi networks")
                        onClicked: SystemState.requestWifiScan()
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
            visible: SystemState.wifiScanning
            spacing: MeoTheme.space8
            MeoLoadingIndicator { indeterminate: true; width: 20 * MeoTheme.globalScale; height: width }
            MeoText {
                text: qsTr("Scanning for nearby networks…")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.onSurfaceVariant
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: networkList
                anchors.fill: parent
                visible: SystemState.networkAvailable && SystemState.wirelessEnabled
                         && SystemState.wifiNetworks.length > 0
                clip: true
                spacing: MeoTheme.space4
                model: SystemState.wifiNetworks
                delegate: MeoListItem {
                    required property var modelData
                    width: networkList.width
                    isDense: true
                    isSegmented: true
                    roundingStrategy: "all"
                    headline: modelData.ssid
                    supportingText: modelData.connected ? qsTr("Connected")
                                  : (modelData.connecting ? qsTr("Connecting…") : modelData.securityLabel)
                    leadingIcon: root.signalIcon(modelData.strength)
                    selected: modelData.connected
                    interactive: !SystemState.networkBusy
                    trailingComponent: Component {
                        RowLayout {
                            spacing: MeoTheme.space4
                            MeoIcon { visible: modelData.secured; icon: "lock"; size: 18; color: MeoTheme.onSurfaceVariant }
                            MeoIcon { visible: modelData.connected; icon: "check"; size: 18; fill: true; color: MeoTheme.primary }
                        }
                    }
                    onClicked: {
                        SystemState.clearOperationError()
                        if (modelData.connected)
                            SystemState.disconnectWifi()
                        else if (modelData.saved || !modelData.secured)
                            SystemState.connectWifi(modelData.ssid, "")
                        else {
                            passwordDialog.ssid = modelData.ssid
                            passwordDialog.open()
                        }
                    }
                }
            }

            PopupEmptyState {
                anchors.fill: parent
                visible: !networkList.visible
                iconName: !SystemState.networkAvailable ? "wifi_off"
                          : (!SystemState.wirelessEnabled ? "wifi_off" : "wifi_find")
                title: !SystemState.networkAvailable ? qsTr("Wi-Fi is unavailable")
                       : (!SystemState.wirelessEnabled ? qsTr("Wi-Fi is turned off") : qsTr("No networks found"))
                description: !SystemState.networkAvailable
                             ? qsTr("Open Network Settings to check the adapter and connection service.")
                             : (!SystemState.wirelessEnabled
                                ? qsTr("Turn on Wi-Fi to discover nearby networks.")
                                : qsTr("Scan again or move closer to an access point."))
                actionText: !SystemState.networkAvailable ? qsTr("Network Settings")
                            : (!SystemState.wirelessEnabled ? qsTr("Turn on Wi-Fi")
                                                           : (SystemState.wifiScanning ? "" : qsTr("Scan again")))
                onActionRequested: {
                    if (!SystemState.networkAvailable)
                        Qt.openUrlExternally("systemsettings:kcm_networkmanagement")
                    else if (!SystemState.wirelessEnabled)
                        SystemState.wirelessEnabled = true
                    else
                        SystemState.requestWifiScan()
                }
            }
        }
    }

    WifiPasswordDialog {
        id: passwordDialog
        parent: root
        onAccepted: function(password) { SystemState.connectWifi(ssid, password) }
    }
}
