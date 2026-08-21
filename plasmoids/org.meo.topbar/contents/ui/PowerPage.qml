import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.ScrollView {
    id: root
    signal backRequested()
    implicitWidth: ShellMetrics.quickSettingsWidth
    implicitHeight: ShellMetrics.quickSettingsHeight
    contentWidth: availableWidth
    contentHeight: pageContent.implicitHeight
    clip: true
    QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

    function profileTitle(profile) {
        if (profile === "performance") return qsTr("Performance")
        if (profile === "power-saver") return qsTr("Power saver")
        return qsTr("Balanced")
    }

    function profileDescription(profile) {
        if (profile === "performance") return qsTr("Prioritise speed and responsiveness")
        if (profile === "power-saver") return qsTr("Reduce energy use and background activity")
        return qsTr("Balance performance and battery life")
    }

    ColumnLayout {
        id: pageContent
        width: root.availableWidth
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: qsTr("Power")
            subtitle: Platform.powerProfilesAvailable
                      ? root.profileTitle(Platform.activePowerProfile) : qsTr("Session and display controls")
            onBackRequested: root.backRequested()
            trailingContent: Component {
                MeoIconButton {
                    type: "standard"
                    size: "m"
                    icon.name: "settings"
                    Accessible.name: qsTr("Open Power Management Settings")
                    onClicked: Qt.openUrlExternally("systemsettings:kcm_powerdevilprofilesconfig")
                }
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: Platform.lastError
            dismissible: true
            onDismissed: Platform.clearError()
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: Platform.powerProfileDegradedReason !== ""
            text: Platform.powerProfileDegradedReason
            tone: "warning"
        }

        PopupSectionLabel {
            visible: Platform.powerProfilesAvailable
            sectionText: qsTr("Power mode")
        }

        MeoMotionSurface {
            Layout.fillWidth: true
            implicitHeight: profileColumn.implicitHeight
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0

            ColumnLayout {
                id: profileColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: Platform.powerProfiles
                    delegate: MeoListItem {
                        required property string modelData
                        Layout.fillWidth: true
                        isDense: true
                        headline: root.profileTitle(modelData)
                        supportingText: root.profileDescription(modelData)
                        selected: Platform.activePowerProfile === modelData
                        leadingIcon: modelData === "performance" ? "speed"
                                     : (modelData === "power-saver" ? "battery_saver" : "balance")
                        trailingComponent: Component {
                            MeoIcon {
                                visible: Platform.activePowerProfile === modelData
                                icon: "check"
                                size: 18
                                fill: true
                                color: MeoTheme.primary
                            }
                        }
                        onClicked: Platform.activePowerProfile = modelData
                    }
                }
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: !Platform.powerProfilesAvailable
            text: qsTr("Power profiles are not provided by this system. Session controls remain available below.")
            tone: "info"
        }

        PopupSectionLabel { sectionText: qsTr("Session") }

        MeoMotionSurface {
            Layout.fillWidth: true
            implicitHeight: sessionColumn.implicitHeight
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0

            ColumnLayout {
                id: sessionColumn
                width: parent.width - MeoTheme.space8
                spacing: 0

                MeoListItem {
                    Layout.fillWidth: true
                    isDense: true
                    headline: qsTr("Keep awake")
                    supportingText: Platform.keepAwake
                                    ? qsTr("Sleep and screen locking are paused")
                                    : qsTr("Use the normal sleep and screen-lock timers")
                    leadingIcon: "coffee"
                    selected: Platform.keepAwake
                    trailingComponent: Component {
                        MeoSwitch {
                            size: "s"
                            checked: Platform.keepAwake
                            Accessible.name: qsTr("Keep awake")
                            onToggled: function(checked) { Platform.keepAwake = checked }
                        }
                    }
                    onClicked: Platform.keepAwake = !Platform.keepAwake
                }

                MeoListItem {
                    Layout.fillWidth: true
                    isDense: true
                    headline: qsTr("Lock screen")
                    supportingText: qsTr("Lock without closing applications")
                    leadingIcon: "lock"
                    trailingComponent: Component {
                        MeoIcon { icon: "chevron_right"; size: 18; color: MeoTheme.onSurfaceVariant }
                    }
                    onClicked: Platform.lockScreen()
                }
            }
        }

        Item { Layout.preferredHeight: MeoTheme.space8 }
    }
}
