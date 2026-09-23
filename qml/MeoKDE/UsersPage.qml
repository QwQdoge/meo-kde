import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    readonly property real scaleFactor: MeoTheme.globalScale

    function formatBytes(value) {
        const bytes = Math.max(0, Number(value) || 0)
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let size = bytes
        let unit = 0
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024
            ++unit
        }
        return (unit >= 3 ? size.toFixed(1) : size.toFixed(unit === 0 ? 0 : 1)) + " " + units[unit]
    }

    function formatRate(value) {
        const rate = Number(value || 0)
        return rate < 1024 ? rate.toFixed(0) + " B/s" : formatBytes(rate) + "/s"
    }

    readonly property var users: MeoSystem.Tasks.userSummaries || []

    PopupEmptyState {
        anchors.fill: parent
        visible: root.users.length === 0
        iconName: "group"
        title: MeoI18n.translator.i18n("No users to show")
        description: MeoI18n.translator.i18n("User resource totals appear while process monitoring is active.")
    }

    QQC2.ScrollView {
        anchors.fill: parent
        visible: root.users.length > 0
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: MeoTheme.space12

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                radius: MeoTheme.shapeLargeIncreased

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space12

                    Rectangle {
                        width: 48 * root.scaleFactor
                        height: width
                        radius: width / 2
                        color: MeoTheme.secondaryContainer

                        MeoIcon {
                            anchors.centerIn: parent
                            icon: "group"
                            fill: true
                            size: 26
                            color: MeoTheme.contentOnSecondaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MeoText {
                            text: MeoI18n.translator.i18n("Users")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }

                        MeoText {
                            text: MeoI18n.translator.i18n("%1 accounts with running processes").arg(root.users.length)
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 820 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space12
                columnSpacing: MeoTheme.space12

                Repeater {
                    model: root.users

                    delegate: MeoCard {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 210 * root.scaleFactor
                        type: "filled"
                        radius: MeoTheme.shapeLargeIncreased

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: MeoTheme.space16
                            spacing: MeoTheme.space12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: MeoTheme.space12

                                Rectangle {
                                    width: 52 * root.scaleFactor
                                    height: width
                                    radius: width / 2
                                    color: modelData.currentUser
                                           ? MeoTheme.primaryContainer
                                           : MeoTheme.surfaceContainerHighest

                                    MeoIcon {
                                        anchors.centerIn: parent
                                        icon: "person"
                                        fill: true
                                        size: 28
                                        color: modelData.currentUser
                                               ? MeoTheme.contentOnPrimaryContainer
                                               : MeoTheme.contentOnSurfaceVariant
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    MeoText {
                                        Layout.fillWidth: true
                                        text: modelData.user || ("UID " + modelData.uid)
                                        typeRole: "title"
                                        typeSize: "medium"
                                        emphasized: true
                                        elide: Text.ElideRight
                                    }

                                    MeoText {
                                        text: modelData.currentUser
                                              ? MeoI18n.translator.i18n("You")
                                              : modelData.sessionActive
                                                ? MeoI18n.translator.i18n("Active session")
                                                : "UID " + modelData.uid
                                        typeRole: "label"
                                        typeSize: "small"
                                        color: MeoTheme.contentOnSurfaceVariant
                                    }
                                }

                                MeoChip {
                                    label: modelData.sessionActive
                                           ? MeoI18n.translator.i18n("Signed in")
                                           : MeoI18n.translator.i18n("Processes only")
                                    leadingIcon: modelData.sessionActive ? "check_circle" : "schedule"
                                    type: "assist"
                                    shape: "pill"
                                    elevated: modelData.sessionActive
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: MeoTheme.space16

                                Stat {
                                    title: "CPU"
                                    value: Number(modelData.cpu || 0).toFixed(1) + "%"
                                }

                                Stat {
                                    title: MeoI18n.translator.i18n("Memory")
                                    value: root.formatBytes(modelData.memoryBytes)
                                }

                                Stat {
                                    title: MeoI18n.translator.i18n("Processes")
                                    value: String(modelData.processCount || 0)
                                }
                            }

                            MeoProgressBar {
                                Layout.fillWidth: true
                                value: Math.max(0, Math.min(100, Number(modelData.cpu || 0))) / 100
                            }

                            MeoText {
                                Layout.fillWidth: true
                                text: MeoI18n.translator.i18n("Disk R %1 · W %2")
                                      .arg(root.formatRate(modelData.diskReadBytesPerSecond))
                                      .arg(root.formatRate(modelData.diskWriteBytesPerSecond))
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: MeoTheme.space8 }
        }
    }

    component Stat: ColumnLayout {
        property string title: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 0

        MeoText {
            text: parent.value
            typeRole: "title"
            typeSize: "small"
            emphasized: true
        }

        MeoText {
            text: parent.title
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
        }
    }
}
