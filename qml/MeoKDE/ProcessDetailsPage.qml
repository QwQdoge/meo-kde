import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    readonly property real scaleFactor: MeoTheme.globalScale
    readonly property var process: MeoSystem.Tasks.selectedProcessDetails

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

    function stateLabel(state) {
        switch (String(state || "")) {
        case "R": return MeoI18n.translator.i18n("Running")
        case "S": return MeoI18n.translator.i18n("Sleeping")
        case "D": return MeoI18n.translator.i18n("Waiting")
        case "T":
        case "t": return MeoI18n.translator.i18n("Stopped")
        case "Z": return MeoI18n.translator.i18n("Zombie")
        case "I": return MeoI18n.translator.i18n("Idle")
        default: return String(state || "—")
        }
    }

    PopupEmptyState {
        anchors.fill: parent
        visible: !root.process || !root.process.pid
        iconName: "ads_click"
        title: MeoI18n.translator.i18n("Select a process")
        description: MeoI18n.translator.i18n("Choose a process on the Processes page to inspect its resources and controls.")
    }

    QQC2.ScrollView {
        anchors.fill: parent
        visible: root.process && root.process.pid > 0
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: MeoTheme.space12

            PopupInlineMessage {
                Layout.fillWidth: true
                visible: MeoSystem.Tasks.actionError !== ""
                text: MeoSystem.Tasks.actionError
                tone: "warning"
                dismissible: true
                onDismissed: MeoSystem.Tasks.clearActionError()
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                radius: MeoTheme.shapeExtraLarge

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space16
                    spacing: MeoTheme.space16

                    Rectangle {
                        width: 64 * root.scaleFactor
                        height: width
                        radius: 22 * root.scaleFactor
                        color: MeoTheme.primaryContainer

                        MeoIcon {
                            anchors.centerIn: parent
                            icon: root.process.category === "app" ? "window"
                                  : root.process.category === "system" ? "dns" : "settings"
                            size: 32
                            color: MeoTheme.contentOnPrimaryContainer
                            fill: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space4

                        MeoText {
                            Layout.fillWidth: true
                            text: root.process.appName || root.process.name || ""
                            typeRole: "headline"
                            typeSize: "small"
                            emphasized: true
                            elide: Text.ElideRight
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: "PID " + root.process.pid
                                  + " · " + (root.process.user || "")
                                  + " · " + root.stateLabel(root.process.state)
                            typeRole: "body"
                            typeSize: "medium"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: root.process.command || ""
                            typeRole: "label"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideMiddle
                        }
                    }

                    MeoChip {
                        visible: root.width >= 640 * root.scaleFactor
                        label: root.process.efficiency
                               ? MeoI18n.translator.i18n("Efficiency on")
                               : MeoI18n.translator.i18n("Normal scheduling")
                        leadingIcon: root.process.efficiency ? "eco" : "speed"
                        type: "assist"
                        shape: "pill"
                        elevated: root.process.efficiency
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 * root.scaleFactor ? 3 : width >= 480 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space8
                columnSpacing: MeoTheme.space8

                ResourceTile {
                    title: "CPU"
                    iconName: "memory"
                    valueText: Number(root.process.cpu || 0).toFixed(1) + "%"
                    supportingText: MeoI18n.translator.i18n("%1 threads · nice %2")
                                    .arg(root.process.threads || 0).arg(root.process.nice || 0)
                    progress: Math.min(100, Number(root.process.cpu || 0))
                }

                ResourceTile {
                    title: MeoI18n.translator.i18n("Memory")
                    iconName: "memory_alt"
                    valueText: root.formatBytes(root.process.memoryBytes)
                    supportingText: root.process.executable || ""
                    progress: -1
                }

                ResourceTile {
                    title: MeoI18n.translator.i18n("Disk")
                    iconName: "hard_drive"
                    valueText: "R " + root.formatRate(root.process.diskReadBytesPerSecond)
                    supportingText: "W " + root.formatRate(root.process.diskWriteBytesPerSecond)
                    progress: -1
                }

                ResourceTile {
                    title: MeoI18n.translator.i18n("GPU")
                    iconName: "developer_board"
                    valueText: root.process.gpuAvailable && Number(root.process.gpuUsage) >= 0
                               ? Number(root.process.gpuUsage).toFixed(1) + "%" : "—"
                    supportingText: root.process.gpuAvailable
                                    ? MeoI18n.translator.i18n("Graphics memory %1").arg(root.formatBytes(root.process.gpuMemoryBytes))
                                    : MeoI18n.translator.i18n("No DRM fdinfo telemetry for this process")
                    progress: root.process.gpuAvailable && Number(root.process.gpuUsage) >= 0
                              ? Number(root.process.gpuUsage) : -1
                }

                ResourceTile {
                    title: MeoI18n.translator.i18n("Network")
                    iconName: "lan"
                    valueText: MeoI18n.translator.i18n("%1 sockets").arg(root.process.socketCount || 0)
                    supportingText: MeoI18n.translator.i18n("Per-process throughput is unavailable without kernel accounting")
                    progress: -1
                }

                ResourceTile {
                    title: MeoI18n.translator.i18n("Process")
                    iconName: "account_tree"
                    valueText: MeoI18n.translator.i18n("Parent %1").arg(root.process.parentPid || 0)
                    supportingText: root.process.category === "app"
                                    ? MeoI18n.translator.i18n("Application")
                                    : root.process.category === "system"
                                      ? MeoI18n.translator.i18n("System process")
                                      : MeoI18n.translator.i18n("Background process")
                    progress: -1
                }
            }

            PopupInlineMessage {
                Layout.fillWidth: true
                visible: root.process && !root.process.networkThroughputAvailable
                tone: "info"
                text: MeoI18n.translator.i18n("Network shows real socket count only. Linux does not provide generic per-process byte throughput in /proc, so Meo does not invent a bandwidth value.")
            }

            MeoCard {
                Layout.fillWidth: true
                visible: root.process && root.process.canControl
                type: "filled"
                radius: MeoTheme.shapeLargeIncreased

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space16
                    spacing: MeoTheme.space12

                    RowLayout {
                        Layout.fillWidth: true
                        MeoIcon { icon: "tune"; size: 22; color: MeoTheme.primary }
                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Scheduling")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        MeoButton {
                            text: root.process.efficiency
                                  ? MeoI18n.translator.i18n("Disable efficiency")
                                  : MeoI18n.translator.i18n("Efficiency mode")
                            type: root.process.efficiency ? "tonal" : "outlined"
                            size: "s"
                            icon.name: "eco"
                            onClicked: MeoSystem.Tasks.setProcessEfficiency(
                                           root.process.pid, !root.process.efficiency)
                        }

                        MeoText {
                            Layout.fillWidth: true
                            visible: root.width >= 680 * root.scaleFactor
                            text: MeoI18n.translator.i18n("Efficiency mode lowers CPU scheduling priority. Restoring priority can require extra permission on Linux.")
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                    }

                    PopupSectionLabel { sectionText: MeoI18n.translator.i18n("Priority") }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        Repeater {
                            model: [
                                { label: MeoI18n.translator.i18n("High"), nice: -5 },
                                { label: MeoI18n.translator.i18n("Normal"), nice: 0 },
                                { label: MeoI18n.translator.i18n("Low"), nice: 10 },
                                { label: MeoI18n.translator.i18n("Very low"), nice: 15 }
                            ]

                            delegate: MeoChip {
                                required property var modelData
                                label: modelData.label
                                type: "assist"
                                shape: "pill"
                                selected: Number(root.process.nice || 0) === modelData.nice
                                elevated: selected
                                onClicked: MeoSystem.Tasks.setProcessPriority(root.process.pid, modelData.nice)
                            }
                        }
                    }

                    MeoDivider { Layout.fillWidth: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        Item { Layout.fillWidth: true }

                        MeoButton {
                            text: MeoI18n.translator.i18n("End task")
                            type: "tonal"
                            size: "s"
                            icon.name: "stop_circle"
                            onClicked: endDialog.open()
                        }

                        MeoButton {
                            text: MeoI18n.translator.i18n("Force stop")
                            type: "text"
                            size: "s"
                            onClicked: forceDialog.open()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: MeoTheme.space8 }
        }
    }

    MeoDialog {
        id: endDialog
        parent: root
        title: MeoI18n.translator.i18n("End %1?").arg(root.process ? (root.process.appName || root.process.name) : "")
        message: MeoI18n.translator.i18n("The process will be asked to exit. Unsaved work can be lost.")
        icon: "warning"
        confirmText: MeoI18n.translator.i18n("End task")
        cancelText: MeoI18n.translator.i18n("Cancel")
        onConfirmed: if (root.process) MeoSystem.Tasks.terminateProcess(root.process.pid, false)
    }

    MeoDialog {
        id: forceDialog
        parent: root
        title: MeoI18n.translator.i18n("Force stop %1?").arg(root.process ? (root.process.appName || root.process.name) : "")
        message: MeoI18n.translator.i18n("The process will be stopped immediately. Unsaved work can be lost.")
        icon: "warning"
        confirmText: MeoI18n.translator.i18n("Force stop")
        cancelText: MeoI18n.translator.i18n("Cancel")
        onConfirmed: if (root.process) MeoSystem.Tasks.terminateProcess(root.process.pid, true)
    }

    component ResourceTile: MeoCard {
        id: tile
        property string title: ""
        property string iconName: "monitoring"
        property string valueText: ""
        property string supportingText: ""
        property real progress: -1

        Layout.fillWidth: true
        implicitHeight: 132 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space12
            spacing: MeoTheme.space8

            RowLayout {
                Layout.fillWidth: true
                MeoIcon { icon: tile.iconName; size: 20; color: MeoTheme.primary }
                MeoText {
                    Layout.fillWidth: true
                    text: tile.title
                    typeRole: "label"
                    typeSize: "large"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }

            MeoText {
                Layout.fillWidth: true
                text: tile.valueText
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                elide: Text.ElideRight
            }

            MeoProgressBar {
                Layout.fillWidth: true
                visible: tile.progress >= 0
                value: Math.max(0, Math.min(100, tile.progress)) / 100
            }

            MeoText {
                Layout.fillWidth: true
                text: tile.supportingText
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
