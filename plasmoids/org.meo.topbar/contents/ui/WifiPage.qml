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
            title: MeoI18n.translator.i18n("Wi-Fi")
            subtitle: SystemState.networkConnected ? SystemState.networkName
                      : (SystemState.wirelessEnabled ? MeoI18n.translator.i18n("Choose a network") : MeoI18n.translator.i18n("Wireless is off"))
            onBackRequested: root.backRequested()
            trailingContent: Component {
                RowLayout {
                    spacing: MeoTheme.space4
                    MeoSwitch {
                        size: "s"
                        checked: SystemState.wirelessEnabled
                        enabled: SystemState.networkAvailable && !SystemState.networkBusy
                        Accessible.name: MeoI18n.translator.i18n("Wi-Fi")
                        onToggled: function(checked) { SystemState.wirelessEnabled = checked }
                    }
                    MeoIconButton {
                        type: "standard"
                        size: "m"
                        icon.name: "refresh"
                        enabled: SystemState.wirelessEnabled && !SystemState.wifiScanning && !SystemState.networkBusy
                        Accessible.name: MeoI18n.translator.i18n("Scan for Wi-Fi networks")
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
                text: MeoI18n.translator.i18n("Scanning for nearby networks…")
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
                    supportingText: modelData.connected ? MeoI18n.translator.i18n("Connected")
                                  : (modelData.connecting ? MeoI18n.translator.i18n("Connecting…") : modelData.securityLabel)
                    leadingIcon: root.signalIcon(modelData.strength)
                    selected: modelData.connected
                    interactive: !SystemState.networkBusy
                    trailingComponent: Component {
                        RowLayout {
                            spacing: MeoTheme.space4
                            MeoIconButton {
                                visible: modelData.saved && !modelData.connected
                                icon.name: "delete"
                                type: "standard"
                                size: "s"
                                enabled: !SystemState.networkBusy
                                Accessible.name: MeoI18n.translator.i18n("Forget %1").arg(modelData.ssid)
                                onClicked: {
                                    SystemState.clearOperationError()
                                    forgetDialog.ssid = modelData.ssid
                                    forgetDialog.open()
                                }
                            }
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
                title: !SystemState.networkAvailable ? MeoI18n.translator.i18n("Wi-Fi is unavailable")
                       : (!SystemState.wirelessEnabled ? MeoI18n.translator.i18n("Wi-Fi is turned off") : MeoI18n.translator.i18n("No networks found"))
                description: !SystemState.networkAvailable
                             ? MeoI18n.translator.i18n("Open Network Settings to check the adapter and connection service.")
                             : (!SystemState.wirelessEnabled
                                ? MeoI18n.translator.i18n("Turn on Wi-Fi to discover nearby networks.")
                                : MeoI18n.translator.i18n("Scan again or move closer to an access point."))
                actionText: !SystemState.networkAvailable ? MeoI18n.translator.i18n("Network Settings")
                            : (!SystemState.wirelessEnabled ? MeoI18n.translator.i18n("Turn on Wi-Fi")
                                                           : (SystemState.wifiScanning ? "" : MeoI18n.translator.i18n("Scan again")))
                onActionRequested: {
                    if (!SystemState.networkAvailable)
                        Qt.openUrlExternally("applications:org.meo.settings.wifi.desktop")
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
        busy: SystemState.networkBusy
        errorText: SystemState.operationError
        connected: SystemState.networkConnected && SystemState.networkName === ssid
        onAccepted: function(password) {
            SystemState.clearOperationError()
            SystemState.connectWifi(ssid, password)
        }
    }

    MeoMotionPopup {
        id: forgetDialog
        property string ssid: ""
        parent: root
        presentation: MeoMotionPopup.Dialog
        width: Math.min(root.width - 2 * MeoTheme.space16, 360 * MeoTheme.globalScale)
        x: (root.width - width) / 2
        y: Math.max(MeoTheme.space16, (root.height - height) / 2)
        padding: 20 * MeoTheme.globalScale

        contentItem: ColumnLayout {
            spacing: MeoTheme.space16
            MeoText {
                Layout.fillWidth: true
                text: MeoI18n.translator.i18n("Forget this network?")
                typeRole: "title"
                typeSize: "small"
                emphasized: true
                wrapMode: Text.WordWrap
            }
            MeoText {
                Layout.fillWidth: true
                text: MeoI18n.translator.i18n("NetworkManager will remove the saved profile and credentials for %1.").arg(forgetDialog.ssid)
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.onSurfaceVariant
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8
                Item { Layout.fillWidth: true }
                MeoButton {
                    text: MeoI18n.translator.i18n("Cancel")
                    type: "text"
                    onClicked: forgetDialog.close()
                }
                MeoButton {
                    text: MeoI18n.translator.i18n("Forget")
                    type: "filled"
                    onClicked: {
                        SystemState.forgetWifi(forgetDialog.ssid)
                        forgetDialog.close()
                    }
                }
            }
        }
    }
}
