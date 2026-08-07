import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.sessions 2.0 as Sessions
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.Popup {
    id: quickSettingsPopup

    y: ShellMetrics.topBarHeight
    x: parent.width - width - ShellMetrics.screenMargin
    width: Math.min(ShellMetrics.quickSettingsWidth, Screen.width - 2 * ShellMetrics.screenMargin)
    height: Math.min(contentLayout.implicitHeight + 40 * MeoTheme.globalScale,
                     Screen.height - ShellMetrics.topBarHeight - 2 * ShellMetrics.screenMargin)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape

    transformOrigin: Item.TopRight

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.985; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.985; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
    }

    background: FrostedSurface {}

    Sessions.SessionManagement {
        id: sessionManagement
    }

    contentItem: ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 20 * MeoTheme.globalScale
        spacing: MeoTheme.space16

        // 1. Header (Time & Date)
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: MeoTheme.space2
                Text {
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    font.family: MeoTheme.fontFamilyBrand
                    font.pixelSize: 22 * MeoTheme.globalScale * MeoTheme.fontScale
                    font.weight: Font.Medium
                    color: MeoTheme.onSurface
                }
                Text {
                    text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                    font.family: MeoTheme.fontFamily
                    font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                    color: MeoTheme.onSurfaceVariant
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 2. Signal-driven connectivity state from NetworkManagerQt + BluezQt.
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: MeoTheme.space12
            rowSpacing: MeoTheme.space12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64 * MeoTheme.globalScale
                radius: ShellMetrics.radiusMedium
                visible: SystemState.networkAvailable
                color: SystemState.wirelessEnabled ? MeoTheme.primaryContainer
                                                   : MeoTheme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space8
                    MeoIcon {
                        icon: SystemState.networkConnected ? "wifi" : "wifi_off"
                        size: ShellMetrics.statusIconSize
                        color: MeoTheme.onSurface
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Wi-Fi"
                            color: MeoTheme.onSurface
                            font.family: MeoTheme.fontFamily
                            font.pixelSize: 13 * MeoTheme.globalScale * MeoTheme.fontScale
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: SystemState.networkName !== "" ? SystemState.networkName
                                                                  : SystemState.networkStatus
                            color: MeoTheme.onSurfaceVariant
                            font.family: MeoTheme.fontFamily
                            font.pixelSize: 10 * MeoTheme.globalScale * MeoTheme.fontScale
                            elide: Text.ElideRight
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: SystemState.wirelessEnabled = !SystemState.wirelessEnabled
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64 * MeoTheme.globalScale
                radius: ShellMetrics.radiusMedium
                visible: SystemState.bluetoothAvailable
                color: SystemState.bluetoothEnabled ? MeoTheme.primaryContainer
                                                    : MeoTheme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space8
                    MeoIcon {
                        icon: "bluetooth"
                        size: ShellMetrics.statusIconSize
                        color: MeoTheme.onSurface
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Bluetooth"
                            color: MeoTheme.onSurface
                            font.family: MeoTheme.fontFamily
                            font.pixelSize: 13 * MeoTheme.globalScale * MeoTheme.fontScale
                            font.weight: Font.Medium
                        }
                        Text {
                            text: SystemState.bluetoothEnabled ? "On" : "Off"
                            color: MeoTheme.onSurfaceVariant
                            font.family: MeoTheme.fontFamily
                            font.pixelSize: 10 * MeoTheme.globalScale * MeoTheme.fontScale
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: SystemState.bluetoothEnabled = !SystemState.bluetoothEnabled
                }
            }
        }

        // 3. Audio state from PulseAudioQt (PipeWire/PulseAudio backend).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space12
            visible: SystemState.audioAvailable

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space12

                MeoIcon {
                    icon: SystemState.audioMuted ? "volume_off" : "volume_up"
                    size: MeoTheme.iconSizeM
                    color: MeoTheme.onSurfaceVariant

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            SystemState.audioMuted = !SystemState.audioMuted
                        }
                    }
                }

                MeoSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    value: SystemState.volumePercent
                    from: 0
                    to: 100
                    onMoved: {
                        SystemState.volumePercent = Math.round(value)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: MeoTheme.iconSizeM + MeoTheme.space12
                text: SystemState.audioDevice
                visible: text !== ""
                color: MeoTheme.onSurfaceVariant
                font.family: MeoTheme.fontFamily
                font.pixelSize: 11 * MeoTheme.globalScale * MeoTheme.fontScale
                elide: Text.ElideRight
            }
        }

        // 4. Footer (Settings & real session actions)
        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space12

            Item { Layout.fillWidth: true }

            // Settings Action
            MeoIconButton {
                icon.name: "settings"
                onClicked: {
                    Qt.openUrlExternally("systemsettings:")
                    quickSettingsPopup.close()
                }
            }

            // Power Action (capabilities come from KDE SessionManagement)
            MeoIconButton {
                icon.name: "power_settings_new"
                enabled: sessionManagement.canLogout || sessionManagement.canShutdown || sessionManagement.canReboot
                onClicked: {
                    powerMenu.popup()
                }
            }
        }
    }

    // Power Menu Popup (Sleep, Restart, Shut down, Sign out)
    QQC2.Menu {
        id: powerMenu

        background: Rectangle {
            color: MeoTheme.surfaceContainerHighest
            radius: ShellMetrics.radiusMedium
            border.color: MeoTheme.outlineVariant
            border.width: ShellMetrics.panelOutlineWidth
        }

        QQC2.MenuItem {
            text: "Sleep"
            visible: sessionManagement.canSuspend
            onTriggered: {
                sessionManagement.suspend()
                quickSettingsPopup.close()
            }
        }
        QQC2.MenuItem {
            text: "Restart"
            visible: sessionManagement.canReboot
            onTriggered: {
                sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt)
                quickSettingsPopup.close()
            }
        }
        QQC2.MenuItem {
            text: "Shut down"
            visible: sessionManagement.canShutdown
            onTriggered: {
                sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt)
                quickSettingsPopup.close()
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: "Sign out"
            visible: sessionManagement.canLogout
            onTriggered: {
                sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt)
                quickSettingsPopup.close()
            }
        }
    }
}
