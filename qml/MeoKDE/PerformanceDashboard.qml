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
        return formatBytes(value) + "/s"
    }

    function formatUptime(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (days > 0)
            return MeoI18n.translator.i18n("%1d %2h").arg(days).arg(hours)
        if (hours > 0)
            return MeoI18n.translator.i18n("%1h %2m").arg(hours).arg(minutes)
        return MeoI18n.translator.i18n("%1m").arg(minutes)
    }

    function profileLabel(profile) {
        if (profile === "power-saver")
            return MeoI18n.translator.i18n("Power saver")
        if (profile === "performance")
            return MeoI18n.translator.i18n("Performance")
        return MeoI18n.translator.i18n("Balanced")
    }

    function gpuDetail() {
        const parts = []
        if (MeoSystem.Performance.gpuTemperature > 0)
            parts.push(Math.round(MeoSystem.Performance.gpuTemperature) + "°C")
        if (MeoSystem.Performance.gpuMemoryTotalBytes > 0) {
            parts.push(MeoI18n.translator.i18n("VRAM %1 / %2")
                       .arg(formatBytes(MeoSystem.Performance.gpuMemoryUsedBytes))
                       .arg(formatBytes(MeoSystem.Performance.gpuMemoryTotalBytes)))
        } else if (MeoSystem.Performance.gpus.length > 1) {
            parts.push(MeoI18n.translator.i18n("%1 GPUs").arg(MeoSystem.Performance.gpus.length))
        }
        return parts.join(" · ")
    }

    QQC2.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: MeoTheme.space12

            PopupInlineMessage {
                Layout.fillWidth: true
                visible: MeoSystem.Platform.lastError !== ""
                text: MeoSystem.Platform.lastError
                dismissible: true
                onDismissed: MeoSystem.Platform.clearError()
            }

            PopupInlineMessage {
                Layout.fillWidth: true
                visible: MeoSystem.Platform.powerProfileDegradedReason !== ""
                text: MeoSystem.Platform.powerProfileDegradedReason
                tone: "warning"
            }

            MeoCard {
                Layout.fillWidth: true
                visible: MeoSystem.Platform.powerProfilesAvailable
                         || MeoSystem.Performance.available
                type: "filled"
                radius: MeoTheme.cardRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        MeoIcon {
                            icon: "speed"
                            size: 20
                            color: MeoTheme.primary
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Performance controls")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }

                        MeoText {
                            text: MeoI18n.translator.i18n("Uptime %1").arg(root.formatUptime(MeoSystem.Performance.uptimeSeconds))
                            typeRole: "label"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: MeoSystem.Platform.powerProfilesAvailable
                        spacing: MeoTheme.space8

                        MeoText {
                            text: MeoI18n.translator.i18n("Power mode")
                            typeRole: "label"
                            typeSize: "medium"
                            color: MeoTheme.contentOnSurfaceVariant
                        }

                        Repeater {
                            model: MeoSystem.Platform.powerProfiles
                            delegate: MeoButton {
                                required property string modelData
                                text: root.profileLabel(modelData)
                                size: "xs"
                                type: MeoSystem.Platform.activePowerProfile === modelData ? "tonal" : "outlined"
                                onClicked: MeoSystem.Platform.activePowerProfile = modelData
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        MeoText {
                            text: MeoI18n.translator.i18n("Sampling")
                            typeRole: "label"
                            typeSize: "medium"
                            color: MeoTheme.contentOnSurfaceVariant
                        }

                        Repeater {
                            model: [1000, 2000, 5000]
                            delegate: MeoButton {
                                required property int modelData
                                text: modelData < 1000 ? modelData + " ms" : (modelData / 1000) + " s"
                                size: "xs"
                                type: MeoSystem.Performance.refreshInterval === modelData ? "tonal" : "outlined"
                                onClicked: MeoSystem.Performance.refreshInterval = modelData
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: metricGrid
                Layout.fillWidth: true
                columns: width >= 720 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space12
                columnSpacing: MeoTheme.space12

                MetricCard {
                    Layout.fillWidth: true
                    title: "CPU"
                    iconName: "memory"
                    valueText: MeoSystem.Performance.cpuUsage.toFixed(1) + "%"
                    subtitle: MeoSystem.Performance.cpuModel
                    detail: (MeoSystem.Performance.cpuFrequencyMHz > 0
                             ? Math.round(MeoSystem.Performance.cpuFrequencyMHz) + " MHz"
                             : "") + (MeoSystem.Performance.cpuTemperature > 0
                                      ? " · " + Math.round(MeoSystem.Performance.cpuTemperature) + "°C"
                                      : "")
                    progressValue: MeoSystem.Performance.cpuUsage
                    history: MeoSystem.Performance.cpuHistory
                    accentColor: MeoTheme.primary
                }

                MetricCard {
                    Layout.fillWidth: true
                    title: MeoI18n.translator.i18n("Memory")
                    iconName: "memory_alt"
                    valueText: MeoSystem.Performance.memoryUsage.toFixed(1) + "%"
                    subtitle: root.formatBytes(MeoSystem.Performance.memoryUsedBytes)
                              + " / " + root.formatBytes(MeoSystem.Performance.memoryTotalBytes)
                    detail: MeoSystem.Performance.swapTotalBytes > 0
                            ? MeoI18n.translator.i18n("Swap %1").arg(root.formatBytes(MeoSystem.Performance.swapUsedBytes))
                            : ""
                    progressValue: MeoSystem.Performance.memoryUsage
                    history: MeoSystem.Performance.memoryHistory
                    accentColor: MeoTheme.secondary
                }

                MetricCard {
                    Layout.fillWidth: true
                    title: MeoI18n.translator.i18n("GPU")
                    iconName: "developer_board"
                    valueText: MeoSystem.Performance.gpuUsage >= 0
                               ? MeoSystem.Performance.gpuUsage.toFixed(0) + "%"
                               : "—"
                    subtitle: MeoSystem.Performance.gpuName.length > 0
                              ? MeoSystem.Performance.gpuName
                              : MeoI18n.translator.i18n("No supported GPU telemetry")
                    detail: root.gpuDetail()
                    progressValue: MeoSystem.Performance.gpuUsage
                    history: MeoSystem.Performance.gpuHistory
                    accentColor: MeoTheme.tertiary
                }

                MetricCard {
                    Layout.fillWidth: true
                    title: MeoI18n.translator.i18n("Storage")
                    iconName: "hard_drive"
                    valueText: MeoSystem.Performance.storageUsage.toFixed(0) + "%"
                    subtitle: root.formatBytes(MeoSystem.Performance.storageUsedBytes)
                              + " / " + root.formatBytes(MeoSystem.Performance.storageTotalBytes)
                    detail: "R " + root.formatRate(MeoSystem.Performance.diskReadBytesPerSecond)
                            + " · W " + root.formatRate(MeoSystem.Performance.diskWriteBytesPerSecond)
                    progressValue: MeoSystem.Performance.storageUsage
                    history: MeoSystem.Performance.diskReadHistory
                    secondaryHistory: MeoSystem.Performance.diskWriteHistory
                    accentColor: MeoTheme.secondary
                    secondaryAccentColor: MeoTheme.tertiary
                }

                MetricCard {
                    Layout.fillWidth: true
                    title: MeoI18n.translator.i18n("Network")
                    iconName: "swap_horiz"
                    valueText: "↓ " + root.formatRate(MeoSystem.Performance.networkRxBytesPerSecond)
                    subtitle: "↑ " + root.formatRate(MeoSystem.Performance.networkTxBytesPerSecond)
                    detail: ""
                    history: MeoSystem.Performance.networkRxHistory
                    secondaryHistory: MeoSystem.Performance.networkTxHistory
                    progressValue: -1
                    accentColor: MeoTheme.primary
                    secondaryAccentColor: MeoTheme.tertiary
                }

                MetricCard {
                    Layout.fillWidth: true
                    title: MeoI18n.translator.i18n("System load")
                    iconName: "monitor_heart"
                    valueText: MeoSystem.Performance.loadAverage1.toFixed(2)
                    subtitle: MeoI18n.translator.i18n("%1 processes · %2 logical CPUs")
                              .arg(MeoSystem.Performance.processCount)
                              .arg(MeoSystem.Performance.logicalCores)
                    detail: MeoSystem.Performance.loadAverage5.toFixed(2)
                            + " / " + MeoSystem.Performance.loadAverage15.toFixed(2)
                    progressValue: Math.min(100,
                        MeoSystem.Performance.logicalCores > 0
                        ? MeoSystem.Performance.loadAverage1 / MeoSystem.Performance.logicalCores * 100
                        : 0)
                    history: []
                    accentColor: MeoTheme.secondary
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: MeoTheme.space8
            }
        }
    }
}
