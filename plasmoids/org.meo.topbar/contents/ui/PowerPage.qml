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
        if (profile === "performance") return MeoI18n.translator.i18n("Performance")
        if (profile === "power-saver") return MeoI18n.translator.i18n("Power saver")
        return MeoI18n.translator.i18n("Balanced")
    }

    function profileDescription(profile) {
        if (profile === "performance") return MeoI18n.translator.i18n("Prioritise speed and responsiveness")
        if (profile === "power-saver") return MeoI18n.translator.i18n("Reduce energy use and background activity")
        return MeoI18n.translator.i18n("Balance performance and battery life")
    }

    ColumnLayout {
        id: pageContent
        width: root.availableWidth
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: MeoI18n.translator.i18n("Power")
            subtitle: Platform.powerProfilesAvailable
                      ? root.profileTitle(Platform.activePowerProfile) : MeoI18n.translator.i18n("Session and display controls")
            onBackRequested: root.backRequested()
            trailingContent: Component {
                MeoIconButton {
                    type: "standard"
                    size: "m"
                    icon.name: "settings"
                    Accessible.name: MeoI18n.translator.i18n("Open Power in Meo Settings")
                    onClicked: Qt.openUrlExternally("applications:org.meo.settings.power.desktop")
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
            sectionText: MeoI18n.translator.i18n("Power mode")
        }

        MeoMotionSurface {
            Layout.fillWidth: true
            implicitHeight: profileColumn.implicitHeight
            radius: ShellMetrics.radiusLarge
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
            text: MeoI18n.translator.i18n("Power profiles are not provided by this system. Session controls remain available below.")
            tone: "info"
        }

        PopupSectionLabel { sectionText: MeoI18n.translator.i18n("Session") }

        MeoMotionSurface {
            Layout.fillWidth: true
            implicitHeight: sessionColumn.implicitHeight
            radius: ShellMetrics.radiusLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0

            ColumnLayout {
                id: sessionColumn
                width: parent.width - MeoTheme.space8
                spacing: 0

                MeoListItem {
                    Layout.fillWidth: true
                    isDense: true
                    headline: MeoI18n.translator.i18n("Keep awake")
                    supportingText: Platform.keepAwake
                                    ? MeoI18n.translator.i18n("Sleep and screen locking are paused")
                                    : MeoI18n.translator.i18n("Use the normal sleep and screen-lock timers")
                    leadingIcon: "coffee"
                    selected: Platform.keepAwake
                    trailingComponent: Component {
                        MeoSwitch {
                            size: "s"
                            checked: Platform.keepAwake
                            Accessible.name: MeoI18n.translator.i18n("Keep awake")
                            onToggled: function(checked) { Platform.keepAwake = checked }
                        }
                    }
                    onClicked: Platform.keepAwake = !Platform.keepAwake
                }

                MeoListItem {
                    Layout.fillWidth: true
                    isDense: true
                    headline: MeoI18n.translator.i18n("Automatic sleep")
                    supportingText: MeoI18n.translator.i18n("Power Management sets the schedule. Applications can temporarily delay sleep when they request it.")
                    leadingIcon: "bedtime"
                    trailingComponent: Component {
                        MeoIcon { icon: "open_in_new"; size: 18; color: MeoTheme.onSurfaceVariant }
                    }
                    Accessible.description: MeoI18n.translator.i18n("Open Power in Meo Settings. This does not force or stop any system service.")
                    onClicked: Qt.openUrlExternally("applications:org.meo.settings.power.desktop")
                }

                MeoListItem {
                    Layout.fillWidth: true
                    isDense: true
                    headline: MeoI18n.translator.i18n("Lock screen")
                    supportingText: MeoI18n.translator.i18n("Lock without closing applications")
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
