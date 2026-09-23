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

    function profileIcon(profile) {
        if (profile === "power-saver") return "battery_saver"
        if (profile === "performance") return "speed"
        return "balance"
    }

    function gpuDetail() {
        const parts = []
        if (MeoSystem.Performance.gpuTemperature > 0)
            parts.push(Math.round(MeoSystem.Performance.gpuTemperature) + "°C")
        if (MeoSystem.Performance.gpuMemoryTotalBytes > 0) {
            parts.push(MeoI18n.translator.i18n("VRAM %1 / %2")
                       .arg(formatBytes(MeoSystem.Performance.gpuMemoryUsedBytes))
                       .arg(formatBytes(MeoSystem.Performance.gpuMemoryTotalBytes)))
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
                type: "filled"
                radius: MeoTheme.shapeExtraLarge

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space16
                    spacing: MeoTheme.space16

                    Rectangle {
                        width: 56 * root.scaleFactor
                        height: width
                        radius: 20 * root.scaleFactor
                        color: MeoTheme.primaryContainer

                        MeoIcon {
                            anchors.centerIn: parent
                            icon: "monitoring"
                            size: 30
                            fill: true
                            color: MeoTheme.contentOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MeoText {
                            text: MeoI18n.translator.i18n("Live performance")
                            typeRole: "title"
                            typeSize: "medium"
                            emphasized: true
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoSystem.Performance.systemSummary
                                  + " · " + MeoI18n.translator.i18n("Uptime %1")
                                      .arg(root.formatUptime(MeoSystem.Performance.uptimeSeconds))
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    MeoChip {
                        visible: MeoSystem.Platform.powerProfilesAvailable
                                 && root.width >= 600 * root.scaleFactor
                        label: root.profileLabel(MeoSystem.Platform.activePowerProfile)
                        leadingIcon: root.profileIcon(MeoSystem.Platform.activePowerProfile)
                        type: "assist"
                        shape: "pill"
                        elevated: true
                    }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                visible: MeoSystem.Platform.powerProfilesAvailable
                type: "filled"
                radius: MeoTheme.shapeLargeIncreased

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space8

                    RowLayout {
                        Layout.fillWidth: true
                        MeoIcon { icon: "speed"; size: 20; color: MeoTheme.primary }
                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Performance mode")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }

                        MeoText {
                            text: MeoI18n.translator.i18n("Sampling")
                            typeRole: "label"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }

                        Repeater {
                            model: [1000, 2000, 5000]
                            delegate: MeoChip {
                                required property int modelData
                                label: (modelData / 1000) + "s"
                                type: "assist"
                                shape: "pill"
                                selected: MeoSystem.Performance.refreshInterval === modelData
                                elevated: selected
                                onClicked: MeoSystem.Performance.refreshInterval = modelData
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        Repeater {
                            model: MeoSystem.Platform.powerProfiles
                            delegate: MeoButton {
                                required property string modelData
                                Layout.fillWidth: true
                                text: root.profileLabel(modelData)
                                icon.name: root.profileIcon(modelData)
                                size: "s"
                                type: MeoSystem.Platform.activePowerProfile === modelData ? "tonal" : "outlined"
                                onClicked: MeoSystem.Platform.activePowerProfile = modelData
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 * root.scaleFactor ? 2 : 1
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
                    detail: MeoI18n.translator.i18n("System total")
                    history: MeoSystem.Performance.networkRxHistory
                    secondaryHistory: MeoSystem.Performance.networkTxHistory
                    progressValue: -1
                    accentColor: MeoTheme.primary
                    secondaryAccentColor: MeoTheme.tertiary
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                radius: MeoTheme.shapeLargeIncreased

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space12

                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            width: 40 * root.scaleFactor
                            height: width
                            radius: 14 * root.scaleFactor
                            color: MeoTheme.secondaryContainer

                            MeoIcon {
                                anchors.centerIn: parent
                                icon: "memory_alt"
                                size: 22
                                fill: true
                                color: MeoTheme.contentOnSecondaryContainer
                            }
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Memory details")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }

                        MeoChip {
                            visible: MeoSystem.Performance.swapTotalBytes > 0
                            label: MeoI18n.translator.i18n("Swap %1 / %2")
                                   .arg(root.formatBytes(MeoSystem.Performance.swapUsedBytes))
                                   .arg(root.formatBytes(MeoSystem.Performance.swapTotalBytes))
                            leadingIcon: "swap_vert"
                            type: "assist"
                            shape: "pill"
                            visualStyle: "outlined"
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 720 * root.scaleFactor ? 4 : 2
                        rowSpacing: MeoTheme.space8
                        columnSpacing: MeoTheme.space8

                        MemoryStat {
                            label: MeoI18n.translator.i18n("Available")
                            value: root.formatBytes(MeoSystem.Performance.memoryAvailableBytes)
                        }
                        MemoryStat {
                            label: MeoI18n.translator.i18n("Cached")
                            value: root.formatBytes(MeoSystem.Performance.memoryCachedBytes)
                        }
                        MemoryStat {
                            label: MeoI18n.translator.i18n("Buffers")
                            value: root.formatBytes(MeoSystem.Performance.memoryBuffersBytes)
                        }
                        MemoryStat {
                            label: MeoI18n.translator.i18n("Shared")
                            value: root.formatBytes(MeoSystem.Performance.memorySharedBytes)
                        }
                    }
                }
            }

            PopupSectionLabel {
                sectionText: MeoI18n.translator.i18n("Storage devices")
            }

            PopupEmptyState {
                Layout.fillWidth: true
                Layout.preferredHeight: 150 * root.scaleFactor
                visible: MeoSystem.Performance.disks.length === 0
                iconName: "hard_drive"
                title: MeoI18n.translator.i18n("No disk telemetry")
                description: MeoI18n.translator.i18n("Physical block-device activity will appear here when available.")
            }

            GridLayout {
                Layout.fillWidth: true
                visible: MeoSystem.Performance.disks.length > 0
                columns: width >= 760 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space12
                columnSpacing: MeoTheme.space12

                Repeater {
                    model: MeoSystem.Performance.disks

                    delegate: DiskTile {
                        required property var modelData
                        Layout.fillWidth: true
                        disk: modelData
                    }
                }
            }

            PopupSectionLabel {
                sectionText: MeoI18n.translator.i18n("Network interfaces")
            }

            PopupEmptyState {
                Layout.fillWidth: true
                Layout.preferredHeight: 150 * root.scaleFactor
                visible: MeoSystem.Performance.networkInterfaces.length === 0
                iconName: "lan"
                title: MeoI18n.translator.i18n("No network telemetry")
                description: MeoI18n.translator.i18n("Active network interfaces will appear here.")
            }

            GridLayout {
                Layout.fillWidth: true
                visible: MeoSystem.Performance.networkInterfaces.length > 0
                columns: width >= 760 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space12
                columnSpacing: MeoTheme.space12

                Repeater {
                    model: MeoSystem.Performance.networkInterfaces

                    delegate: NetworkTile {
                        required property var modelData
                        Layout.fillWidth: true
                        network: modelData
                    }
                }
            }

            PopupSectionLabel {
                sectionText: MeoI18n.translator.i18n("CPU cores")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 900 * root.scaleFactor ? 4
                         : width >= 620 * root.scaleFactor ? 3
                         : width >= 400 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space8
                columnSpacing: MeoTheme.space8

                Repeater {
                    model: MeoSystem.Performance.cpuCores

                    delegate: CoreTile {
                        required property var modelData
                        Layout.fillWidth: true
                        core: modelData
                    }
                }
            }

            PopupSectionLabel {
                sectionText: MeoI18n.translator.i18n("Graphics")
            }

            PopupEmptyState {
                Layout.fillWidth: true
                Layout.preferredHeight: 180 * root.scaleFactor
                visible: MeoSystem.Performance.gpus.length === 0
                iconName: "developer_board"
                title: MeoI18n.translator.i18n("No GPU telemetry")
                description: MeoI18n.translator.i18n("The graphics driver does not expose supported telemetry.")
            }

            GridLayout {
                Layout.fillWidth: true
                visible: MeoSystem.Performance.gpus.length > 0
                columns: width >= 760 * root.scaleFactor ? 2 : 1
                rowSpacing: MeoTheme.space12
                columnSpacing: MeoTheme.space12

                Repeater {
                    model: MeoSystem.Performance.gpus

                    delegate: GpuTile {
                        required property var modelData
                        Layout.fillWidth: true
                        gpu: modelData
                    }
                }
            }

            MeoCard {
                Layout.fillWidth: true
                type: "filled"
                radius: MeoTheme.shapeLargeIncreased

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space12
                    spacing: MeoTheme.space12

                    MeoIcon {
                        icon: "monitor_heart"
                        size: 24
                        color: MeoTheme.tertiary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MeoText {
                            text: MeoI18n.translator.i18n("System load")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                        }

                        MeoText {
                            text: MeoI18n.translator.i18n("%1 processes · %2 logical CPUs")
                                  .arg(MeoSystem.Performance.processCount)
                                  .arg(MeoSystem.Performance.logicalCores)
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }

                    MeoChip {
                        label: MeoSystem.Performance.loadAverage1.toFixed(2)
                               + " · " + MeoSystem.Performance.loadAverage5.toFixed(2)
                               + " · " + MeoSystem.Performance.loadAverage15.toFixed(2)
                        leadingIcon: "timeline"
                        type: "assist"
                        shape: "pill"
                        elevated: true
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: MeoTheme.space8 }
        }
    }

    component CoreTile: MeoCard {
        id: coreTile
        property var core: ({})

        implicitHeight: 132 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space12
            spacing: MeoTheme.space8

            RowLayout {
                Layout.fillWidth: true

                MeoText {
                    Layout.fillWidth: true
                    text: coreTile.core.label || ("CPU " + coreTile.core.index)
                    typeRole: "label"
                    typeSize: "large"
                    emphasized: true
                }

                MeoText {
                    text: Number(coreTile.core.usage || 0).toFixed(0) + "%"
                    typeRole: "title"
                    typeSize: "small"
                    emphasized: true
                }
            }

            PerformanceGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 38 * root.scaleFactor
                values: coreTile.core.history || []
                primaryColor: MeoTheme.primary
                maximum: 100
            }

            RowLayout {
                Layout.fillWidth: true
                MeoProgressBar {
                    Layout.fillWidth: true
                    value: Math.max(0, Math.min(100, Number(coreTile.core.usage || 0))) / 100
                    wavy: true
                }

                MeoText {
                    visible: Number(coreTile.core.frequencyMHz || 0) > 0
                    text: Math.round(Number(coreTile.core.frequencyMHz || 0)) + " MHz"
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }
        }
    }

    component MemoryStat: MeoCard {
        id: memoryStat
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        implicitHeight: 74 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeMedium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space8
            spacing: 0

            MeoText {
                text: memoryStat.value
                typeRole: "title"
                typeSize: "small"
                emphasized: true
            }

            MeoText {
                text: memoryStat.label
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }
    }

    component DiskTile: MeoCard {
        id: diskTile
        property var disk: ({})

        implicitHeight: 194 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeLargeIncreased

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space12
            spacing: MeoTheme.space8

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                Rectangle {
                    width: 40 * root.scaleFactor
                    height: width
                    radius: 14 * root.scaleFactor
                    color: MeoTheme.secondaryContainer

                    MeoIcon {
                        anchors.centerIn: parent
                        icon: "hard_drive"
                        size: 22
                        fill: true
                        color: MeoTheme.contentOnSecondaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    MeoText {
                        Layout.fillWidth: true
                        text: diskTile.disk.model || diskTile.disk.name || MeoI18n.translator.i18n("Disk")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        elide: Text.ElideRight
                    }

                    MeoText {
                        text: (diskTile.disk.name || "")
                              + " · " + (diskTile.disk.type || "")
                              + (Number(diskTile.disk.sizeBytes || 0) > 0
                                 ? " · " + root.formatBytes(diskTile.disk.sizeBytes) : "")
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }

                MeoText {
                    text: Number(diskTile.disk.usage || 0).toFixed(0) + "%"
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                }
            }

            PerformanceGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 42 * root.scaleFactor
                values: diskTile.disk.readHistory || []
                secondaryValues: diskTile.disk.writeHistory || []
                primaryColor: MeoTheme.secondary
                secondaryColor: MeoTheme.tertiary
                maximum: 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                MeoProgressBar {
                    Layout.fillWidth: true
                    value: Math.max(0, Math.min(100, Number(diskTile.disk.usage || 0))) / 100
                    activeColor: MeoTheme.secondary
                    wavy: true
                }

                MeoText {
                    text: "R " + root.formatRate(diskTile.disk.readBytesPerSecond)
                          + " · W " + root.formatRate(diskTile.disk.writeBytesPerSecond)
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }
        }
    }

    component NetworkTile: MeoCard {
        id: networkTile
        property var network: ({})

        implicitHeight: 182 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeLargeIncreased

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space12
            spacing: MeoTheme.space8

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                Rectangle {
                    width: 40 * root.scaleFactor
                    height: width
                    radius: 14 * root.scaleFactor
                    color: networkTile.network.up
                           ? MeoTheme.primaryContainer
                           : MeoTheme.surfaceContainerHighest

                    MeoIcon {
                        anchors.centerIn: parent
                        icon: networkTile.network.wireless ? "wifi" : "lan"
                        size: 22
                        fill: networkTile.network.up
                        color: networkTile.network.up
                               ? MeoTheme.contentOnPrimaryContainer
                               : MeoTheme.contentOnSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    MeoText {
                        text: networkTile.network.name || MeoI18n.translator.i18n("Network")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                    }

                    MeoText {
                        text: networkTile.network.up
                              ? (Number(networkTile.network.speedMbps || 0) > 0
                                 ? MeoI18n.translator.i18n("Connected · %1 Mbps")
                                     .arg(networkTile.network.speedMbps)
                                 : MeoI18n.translator.i18n("Connected"))
                              : MeoI18n.translator.i18n("Inactive")
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }

                MeoChip {
                    label: networkTile.network.wireless
                           ? MeoI18n.translator.i18n("Wi-Fi")
                           : MeoI18n.translator.i18n("Wired")
                    leadingIcon: networkTile.network.wireless ? "wifi" : "lan"
                    type: "assist"
                    shape: "pill"
                    visualStyle: "outlined"
                }
            }

            PerformanceGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 42 * root.scaleFactor
                values: networkTile.network.rxHistory || []
                secondaryValues: networkTile.network.txHistory || []
                primaryColor: MeoTheme.primary
                secondaryColor: MeoTheme.tertiary
                maximum: 0
            }

            RowLayout {
                Layout.fillWidth: true

                MeoText {
                    Layout.fillWidth: true
                    text: "↓ " + root.formatRate(networkTile.network.rxBytesPerSecond)
                    typeRole: "label"
                    typeSize: "small"
                    emphasized: true
                }

                MeoText {
                    text: "↑ " + root.formatRate(networkTile.network.txBytesPerSecond)
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }
        }
    }

    component GpuTile: MeoCard {
        id: gpuTile
        property var gpu: ({})

        implicitHeight: 252 * root.scaleFactor
        type: "filled"
        radius: MeoTheme.shapeLargeIncreased

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space12
            spacing: MeoTheme.space8

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                Rectangle {
                    width: 40 * root.scaleFactor
                    height: width
                    radius: 14 * root.scaleFactor
                    color: MeoTheme.tertiaryContainer

                    MeoIcon {
                        anchors.centerIn: parent
                        icon: "developer_board"
                        size: 22
                        fill: true
                        color: MeoTheme.contentOnTertiaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    MeoText {
                        Layout.fillWidth: true
                        text: gpuTile.gpu.name || MeoI18n.translator.i18n("GPU")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        elide: Text.ElideRight
                    }

                    MeoText {
                        text: (gpuTile.gpu.driver || "")
                              + (gpuTile.gpu.temperature > 0
                                 ? " · " + Math.round(gpuTile.gpu.temperature) + "°C" : "")
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }

                MeoText {
                    text: Number(gpuTile.gpu.usage) >= 0
                          ? Number(gpuTile.gpu.usage).toFixed(0) + "%" : "—"
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                }
            }

            PerformanceGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 44 * root.scaleFactor
                values: gpuTile.gpu.history || []
                primaryColor: MeoTheme.tertiary
                maximum: 100
            }

            MeoProgressBar {
                Layout.fillWidth: true
                visible: Number(gpuTile.gpu.usage) >= 0
                value: Math.max(0, Math.min(100, Number(gpuTile.gpu.usage))) / 100
                activeColor: MeoTheme.tertiary
                wavy: true
            }

            MeoText {
                Layout.fillWidth: true
                text: Number(gpuTile.gpu.memoryTotalBytes || 0) > 0
                      ? MeoI18n.translator.i18n("VRAM %1 / %2")
                          .arg(root.formatBytes(gpuTile.gpu.memoryUsedBytes))
                          .arg(root.formatBytes(gpuTile.gpu.memoryTotalBytes))
                      : MeoI18n.translator.i18n("VRAM telemetry unavailable")
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                MeoChip {
                    visible: Number(gpuTile.gpu.powerWatts || 0) > 0
                    label: Number(gpuTile.gpu.powerWatts || 0).toFixed(1) + " W"
                    leadingIcon: "bolt"
                    type: "assist"
                    shape: "pill"
                    visualStyle: "outlined"
                }

                MeoChip {
                    visible: Number(gpuTile.gpu.coreClockMHz || 0) > 0
                    label: Math.round(Number(gpuTile.gpu.coreClockMHz || 0)) + " MHz"
                    leadingIcon: "speed"
                    type: "assist"
                    shape: "pill"
                    visualStyle: "outlined"
                }

                MeoChip {
                    visible: Number(gpuTile.gpu.memoryClockMHz || 0) > 0
                    label: MeoI18n.translator.i18n("Memory %1 MHz")
                           .arg(Math.round(Number(gpuTile.gpu.memoryClockMHz || 0)))
                    leadingIcon: "memory_alt"
                    type: "assist"
                    shape: "pill"
                    visualStyle: "outlined"
                }
            }
        }
    }
}
