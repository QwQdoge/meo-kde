import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

// Task-manager style Performance page: a resource list on the left (CPU,
// memory, every disk, network interface and GPU, each with a live mini
// graph) and the selected resource's large graph and statistics on the right.
// Every value comes from Meo.System Performance; unknown values show "—".
Item {
    id: root

    readonly property real scaleFactor: MeoTheme.globalScale
    readonly property bool wide: width >= 760 * scaleFactor
    property string selectedKey: "cpu"
    property bool cpuShowsLogicalProcessors: false

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

    function formatBits(bytesPerSecond) {
        const bits = Math.max(0, Number(bytesPerSecond) || 0) * 8
        if (bits >= 1e9) return (bits / 1e9).toFixed(1) + " Gbps"
        if (bits >= 1e6) return (bits / 1e6).toFixed(1) + " Mbps"
        if (bits >= 1e3) return Math.round(bits / 1e3) + " Kbps"
        return Math.round(bits) + " bps"
    }

    function formatFrequency(mhz) {
        const value = Number(mhz) || 0
        if (value <= 0)
            return "—"
        return value >= 1000 ? (value / 1000).toFixed(2) + " GHz" : Math.round(value) + " MHz"
    }

    function formatUptime(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const secs = total % 60
        const clock = String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0")
                      + ":" + String(secs).padStart(2, "0")
        return days > 0 ? MeoI18n.translator.i18n("%1 d %2", days, clock) : clock
    }

    function percent(value) {
        const number = Number(value)
        return number >= 0 ? number.toFixed(0) + "%" : "—"
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

    function historySpan(history) {
        const samples = (history || []).length
        const seconds = Math.round(samples * MeoSystem.Performance.refreshInterval / 1000)
        return seconds > 0 ? MeoI18n.translator.i18n("%1 seconds", seconds) : ""
    }

    function networkKindLabel(network) {
        if (network.kind === "wifi") return MeoI18n.translator.i18n("Wi-Fi")
        if (network.kind === "virtual") return MeoI18n.translator.i18n("Virtual")
        return MeoI18n.translator.i18n("Ethernet")
    }

    // One entry per resource, rebuilt from live telemetry.
    readonly property var resources: {
        const rows = [{
            "key": "cpu", "kind": "cpu", "title": "CPU",
            "line": root.percent(MeoSystem.Performance.cpuUsage) + "  "
                    + root.formatFrequency(MeoSystem.Performance.cpuFrequencyMHz),
            "history": MeoSystem.Performance.cpuHistory, "secondary": [],
            "maximum": 100, "color": MeoTheme.primary
        }, {
            "key": "memory", "kind": "memory", "title": MeoI18n.translator.i18n("Memory"),
            "line": root.formatBytes(MeoSystem.Performance.memoryUsedBytes) + " / "
                    + root.formatBytes(MeoSystem.Performance.memoryTotalBytes)
                    + " (" + root.percent(MeoSystem.Performance.memoryUsage) + ")",
            "history": MeoSystem.Performance.memoryHistory, "secondary": [],
            "maximum": 100, "color": MeoTheme.secondary
        }]
        const disks = MeoSystem.Performance.disks
        for (let index = 0; index < disks.length; ++index) {
            const disk = disks[index]
            rows.push({
                "key": "disk:" + (disk.name || index), "kind": "disk", "data": disk,
                "title": MeoI18n.translator.i18n("Disk %1 (%2)", index, disk.name || "?"),
                "line": (disk.type || "") + (disk.type ? "  " : "") + root.percent(disk.usage),
                "history": disk.readHistory || [], "secondary": disk.writeHistory || [],
                "maximum": 0, "color": MeoTheme.tertiary
            })
        }
        const networks = MeoSystem.Performance.networkInterfaces
        for (let index = 0; index < networks.length; ++index) {
            const network = networks[index]
            rows.push({
                "key": "net:" + network.name, "kind": "network", "data": network,
                "title": root.networkKindLabel(network),
                "subtitle": network.name,
                "line": network.up
                        ? MeoI18n.translator.i18n("S: %1  R: %2", root.formatBits(network.txBytesPerSecond),
                                                  root.formatBits(network.rxBytesPerSecond))
                        : MeoI18n.translator.i18n("Not connected"),
                "history": network.rxHistory || [], "secondary": network.txHistory || [],
                "maximum": 0, "color": MeoTheme.primary
            })
        }
        const gpus = MeoSystem.Performance.gpus
        for (let index = 0; index < gpus.length; ++index) {
            const gpu = gpus[index]
            rows.push({
                "key": "gpu:" + index, "kind": "gpu", "data": gpu,
                "title": MeoI18n.translator.i18n("GPU %1", index),
                "subtitle": gpu.name,
                "line": root.percent(gpu.usage)
                        + (gpu.temperature > 0 ? "  (" + Math.round(gpu.temperature) + " °C)" : ""),
                "history": gpu.history || [], "secondary": [],
                "maximum": 100, "color": MeoTheme.tertiary
            })
        }
        return rows
    }

    readonly property var selected: {
        for (let index = 0; index < resources.length; ++index)
            if (resources[index].key === selectedKey)
                return resources[index]
        return resources[0]
    }

    ColumnLayout {
        anchors.fill: parent
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

        // Power mode, like the Windows power-mode control. A Flow wraps on
        // narrow windows instead of forcing the page wider.
        Flow {
            Layout.fillWidth: true
            visible: MeoSystem.Platform.powerProfilesAvailable
            spacing: MeoTheme.space8

            MeoText {
                topPadding: MeoTheme.space4
                text: MeoI18n.translator.i18n("Performance mode")
                typeRole: "label"
                typeSize: "large"
                color: MeoTheme.contentOnSurfaceVariant
            }

            Repeater {
                model: MeoSystem.Platform.powerProfiles
                delegate: MeoButton {
                    required property string modelData
                    text: root.profileLabel(modelData)
                    icon.name: root.profileIcon(modelData)
                    size: "xs"
                    type: MeoSystem.Platform.activePowerProfile === modelData ? "tonal" : "text"
                    onClicked: MeoSystem.Platform.activePowerProfile = modelData
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.wide ? 2 : 1
            columnSpacing: MeoTheme.space12
            rowSpacing: MeoTheme.space12

            // Resource list.
            QQC2.ScrollView {
                id: listScroll
                // In the narrow layout the strip scrolls sideways; it must not
                // widen the column (and with it the detail pane).
                Layout.preferredWidth: root.wide ? 260 * root.scaleFactor : 0
                Layout.fillWidth: !root.wide
                Layout.fillHeight: root.wide
                Layout.preferredHeight: root.wide ? -1 : 76 * root.scaleFactor
                clip: true
                contentWidth: root.wide ? availableWidth : resourceFlow.implicitWidth
                QQC2.ScrollBar.horizontal.policy: root.wide ? QQC2.ScrollBar.AlwaysOff : QQC2.ScrollBar.AsNeeded

                GridLayout {
                    id: resourceFlow
                    width: root.wide ? listScroll.availableWidth : implicitWidth
                    columns: root.wide ? 1 : Math.max(1, root.resources.length)
                    rowSpacing: MeoTheme.space4
                    columnSpacing: MeoTheme.space8

                    Repeater {
                        model: root.resources
                        delegate: ResourceEntry {
                            required property var modelData
                            Layout.fillWidth: root.wide
                            Layout.preferredWidth: root.wide ? -1 : 220 * root.scaleFactor
                            resource: modelData
                            selected: modelData.key === root.selected.key
                            onClicked: root.selectedKey = modelData.key
                        }
                    }
                }
            }

            // Detail pane.
            QQC2.ScrollView {
                id: detailScroll
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                Loader {
                    width: detailScroll.availableWidth
                    sourceComponent: root.selected.kind === "memory" ? memoryDetail
                                     : root.selected.kind === "disk" ? diskDetail
                                     : root.selected.kind === "network" ? networkDetail
                                     : root.selected.kind === "gpu" ? gpuDetail
                                     : cpuDetail
                }
            }
        }
    }

    // ── CPU ─────────────────────────────────────────────────────────────
    Component {
        id: cpuDetail
        ColumnLayout {
            spacing: MeoTheme.space12

            DetailHeader {
                title: "CPU"
                subtitle: MeoSystem.Performance.cpuModel
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8
                MeoText {
                    Layout.fillWidth: true
                    text: root.cpuShowsLogicalProcessors
                          ? MeoI18n.translator.i18n("Utilization per logical processor")
                          : MeoI18n.translator.i18n("% Utilization over %1", root.historySpan(MeoSystem.Performance.cpuHistory))
                    typeRole: "label"; typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }
                MeoChip {
                    label: MeoI18n.translator.i18n("Overall")
                    type: "filter"
                    selected: !root.cpuShowsLogicalProcessors
                    onClicked: root.cpuShowsLogicalProcessors = false
                }
                MeoChip {
                    label: MeoI18n.translator.i18n("Logical processors")
                    type: "filter"
                    selected: root.cpuShowsLogicalProcessors
                    onClicked: root.cpuShowsLogicalProcessors = true
                }
            }

            BigGraph {
                visible: !root.cpuShowsLogicalProcessors
                values: MeoSystem.Performance.cpuHistory
                maximum: 100
                color: MeoTheme.primary
                topRightLabel: "100%"
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.cpuShowsLogicalProcessors
                columns: Math.max(2, Math.min(8, Math.floor(width / (110 * root.scaleFactor))))
                rowSpacing: MeoTheme.space4
                columnSpacing: MeoTheme.space4

                Repeater {
                    model: root.cpuShowsLogicalProcessors ? MeoSystem.Performance.cpuCores : []
                    delegate: MeoCard {
                        id: coreCell
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 78 * root.scaleFactor
                        type: "outlined"
                        radius: MeoTheme.shapeSmall
                        padding: MeoTheme.space4
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2 * root.scaleFactor
                            MeoText {
                                text: (coreCell.modelData.label || ("CPU " + coreCell.modelData.index))
                                      + " · " + Number(coreCell.modelData.usage || 0).toFixed(0) + "%"
                                typeRole: "label"; typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                            PerformanceGraph {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                values: coreCell.modelData.history || []
                                primaryColor: MeoTheme.primary
                                maximum: 100
                            }
                            MeoProgressBar {
                                Layout.fillWidth: true
                                value: Math.max(0, Math.min(100, Number(coreCell.modelData.usage || 0))) / 100
                                wavy: true
                            }
                        }
                    }
                }
            }

            StatGrid {
                primaryStats: [
                    { "label": MeoI18n.translator.i18n("Utilization"), "value": root.percent(MeoSystem.Performance.cpuUsage) },
                    { "label": MeoI18n.translator.i18n("Speed"), "value": root.formatFrequency(MeoSystem.Performance.cpuFrequencyMHz) },
                    { "label": MeoI18n.translator.i18n("Processes"), "value": String(MeoSystem.Performance.processCount) },
                    { "label": MeoI18n.translator.i18n("Up time"), "value": root.formatUptime(MeoSystem.Performance.uptimeSeconds) },
                    { "label": MeoI18n.translator.i18n("Load average"), "value": MeoSystem.Performance.loadAverage1.toFixed(2)
                              + " · " + MeoSystem.Performance.loadAverage5.toFixed(2)
                              + " · " + MeoSystem.Performance.loadAverage15.toFixed(2) },
                    { "label": MeoI18n.translator.i18n("Temperature"), "value": MeoSystem.Performance.cpuTemperature > 0
                              ? Math.round(MeoSystem.Performance.cpuTemperature) + " °C" : "—" }
                ]
                secondaryStats: {
                    const rows = [
                        { "label": MeoI18n.translator.i18n("Maximum speed"), "value": root.formatFrequency(MeoSystem.Performance.cpuMaxFrequencyMHz) },
                        { "label": MeoI18n.translator.i18n("Sockets"), "value": String(MeoSystem.Performance.cpuSockets) },
                        { "label": MeoI18n.translator.i18n("Cores"), "value": String(MeoSystem.Performance.physicalCores) },
                        { "label": MeoI18n.translator.i18n("Logical processors"), "value": String(MeoSystem.Performance.logicalCores) },
                        { "label": MeoI18n.translator.i18n("Architecture"), "value": MeoSystem.Performance.cpuArchitecture || "—" },
                        { "label": MeoI18n.translator.i18n("Virtualization"), "value": MeoSystem.Performance.cpuVirtualizationSupported
                                  ? MeoI18n.translator.i18n("Supported") : MeoI18n.translator.i18n("Not detected") }
                    ]
                    const caches = MeoSystem.Performance.cpuCaches
                    for (let index = 0; index < caches.length; ++index)
                        rows.push({ "label": MeoI18n.translator.i18n("%1 cache", caches[index].label || "L?"),
                                    "value": root.formatBytes(caches[index].sizeBytes) })
                    return rows
                }
            }

            PressureNote {
                text: MeoI18n.translator.i18n("CPU waiting %1% (Linux PSI, last 10 s)",
                                              Number(MeoSystem.Performance.pressure.cpuSomeAvg10 || 0).toFixed(1))
            }
        }
    }

    // ── Memory ──────────────────────────────────────────────────────────
    Component {
        id: memoryDetail
        ColumnLayout {
            id: memoryColumn
            spacing: MeoTheme.space12

            readonly property real total: Math.max(1, MeoSystem.Performance.memoryTotalBytes)
            readonly property real used: MeoSystem.Performance.memoryUsedBytes
            readonly property real cached: MeoSystem.Performance.memoryCachedBytes + MeoSystem.Performance.memoryBuffersBytes
            readonly property real free: Math.max(0, total - used - cached)

            DetailHeader {
                title: MeoI18n.translator.i18n("Memory")
                subtitle: root.formatBytes(MeoSystem.Performance.memoryTotalBytes)
            }

            MeoText {
                text: MeoI18n.translator.i18n("Memory usage over %1", root.historySpan(MeoSystem.Performance.memoryHistory))
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }

            BigGraph {
                values: MeoSystem.Performance.memoryHistory
                maximum: 100
                color: MeoTheme.secondary
                topRightLabel: root.formatBytes(MeoSystem.Performance.memoryTotalBytes)
            }

            MeoText {
                text: MeoI18n.translator.i18n("Memory composition")
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }

            Row {
                id: composition
                Layout.fillWidth: true
                height: 28 * root.scaleFactor
                spacing: 2 * root.scaleFactor
                Repeater {
                    model: [
                        { "bytes": memoryColumn.used, "color": MeoTheme.secondary,
                          "label": MeoI18n.translator.i18n("In use") },
                        { "bytes": memoryColumn.cached, "color": MeoTheme.secondaryContainer,
                          "label": MeoI18n.translator.i18n("Cached") },
                        { "bytes": memoryColumn.free, "color": MeoTheme.surfaceContainerHighest,
                          "label": MeoI18n.translator.i18n("Free") }
                    ]
                    delegate: MeoShape {
                        required property var modelData
                        type: "rect"
                        strokeWidth: 0
                        width: Math.max(2 * root.scaleFactor,
                                        (composition.width - composition.spacing * 2)
                                        * modelData.bytes / Math.max(1, MeoSystem.Performance.memoryTotalBytes))
                        height: composition.height
                        radius: MeoTheme.shapeExtraSmall
                        color: modelData.color
                        Accessible.name: modelData.label + " " + root.formatBytes(modelData.bytes)
                    }
                }
            }

            StatGrid {
                primaryStats: [
                    { "label": MeoI18n.translator.i18n("In use"), "value": root.formatBytes(MeoSystem.Performance.memoryUsedBytes) },
                    { "label": MeoI18n.translator.i18n("Available"), "value": root.formatBytes(MeoSystem.Performance.memoryAvailableBytes) },
                    { "label": MeoI18n.translator.i18n("Cached"), "value": root.formatBytes(MeoSystem.Performance.memoryCachedBytes) },
                    { "label": MeoI18n.translator.i18n("Buffers"), "value": root.formatBytes(MeoSystem.Performance.memoryBuffersBytes) },
                    { "label": MeoI18n.translator.i18n("Shared"), "value": root.formatBytes(MeoSystem.Performance.memorySharedBytes) },
                    { "label": MeoI18n.translator.i18n("Swap"), "value": MeoSystem.Performance.swapTotalBytes > 0
                              ? root.formatBytes(MeoSystem.Performance.swapUsedBytes) + " / " + root.formatBytes(MeoSystem.Performance.swapTotalBytes)
                              : MeoI18n.translator.i18n("None") }
                ]
                secondaryStats: {
                    const rows = []
                    if (MeoSystem.Performance.zramDiskSizeBytes > 0) {
                        rows.push({ "label": MeoI18n.translator.i18n("ZRAM size"), "value": root.formatBytes(MeoSystem.Performance.zramDiskSizeBytes) })
                        rows.push({ "label": MeoI18n.translator.i18n("ZRAM stored"), "value": root.formatBytes(MeoSystem.Performance.zramOriginalBytes) })
                        rows.push({ "label": MeoI18n.translator.i18n("ZRAM compressed"), "value": root.formatBytes(MeoSystem.Performance.zramCompressedBytes) })
                        rows.push({ "label": MeoI18n.translator.i18n("Compression ratio"), "value": MeoSystem.Performance.zramCompressionRatio > 0
                                  ? MeoSystem.Performance.zramCompressionRatio.toFixed(2) + "×" : "—" })
                    }
                    rows.push({ "label": MeoI18n.translator.i18n("Zswap"), "value": MeoSystem.Performance.zswapEnabled
                              ? MeoI18n.translator.i18n("On") : MeoI18n.translator.i18n("Off") })
                    return rows
                }
            }

            PressureNote {
                text: MeoI18n.translator.i18n("Memory waiting %1% · fully stalled %2% (Linux PSI, last 10 s)",
                                              Number(MeoSystem.Performance.pressure.memorySomeAvg10 || 0).toFixed(1),
                                              Number(MeoSystem.Performance.pressure.memoryFullAvg10 || 0).toFixed(1))
            }
        }
    }

    // ── Disk ────────────────────────────────────────────────────────────
    Component {
        id: diskDetail
        ColumnLayout {
            readonly property var disk: root.selected.data || ({})
            spacing: MeoTheme.space12

            DetailHeader {
                title: root.selected.title
                subtitle: (disk.model || disk.name || "") + (Number(disk.sizeBytes || 0) > 0 ? " · " + root.formatBytes(disk.sizeBytes) : "")
            }

            MeoText {
                text: MeoI18n.translator.i18n("Transfer rate over %1 · read and write", root.historySpan(disk.readHistory))
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }

            BigGraph {
                values: disk.readHistory || []
                secondaryValues: disk.writeHistory || []
                maximum: 0
                color: MeoTheme.tertiary
                secondaryColor: MeoTheme.secondary
            }

            StatGrid {
                primaryStats: [
                    { "label": MeoI18n.translator.i18n("Active time"), "value": root.percent(disk.usage) },
                    { "label": MeoI18n.translator.i18n("Average response time"), "value": Number(disk.averageLatencyMs || 0).toFixed(1) + " ms" },
                    { "label": MeoI18n.translator.i18n("Read speed"), "value": root.formatRate(disk.readBytesPerSecond) },
                    { "label": MeoI18n.translator.i18n("Write speed"), "value": root.formatRate(disk.writeBytesPerSecond) },
                    { "label": MeoI18n.translator.i18n("Read operations"), "value": MeoI18n.translator.i18n("%1 IOPS", Number(disk.readIops || 0).toFixed(0)) },
                    { "label": MeoI18n.translator.i18n("Write operations"), "value": MeoI18n.translator.i18n("%1 IOPS", Number(disk.writeIops || 0).toFixed(0)) }
                ]
                secondaryStats: [
                    { "label": MeoI18n.translator.i18n("Capacity"), "value": Number(disk.sizeBytes || 0) > 0 ? root.formatBytes(disk.sizeBytes) : "—" },
                    { "label": MeoI18n.translator.i18n("Type"), "value": disk.type || "—" },
                    { "label": MeoI18n.translator.i18n("Device"), "value": disk.name || "—" },
                    { "label": MeoI18n.translator.i18n("Requests in flight"), "value": String(Number(disk.inFlight || 0)) }
                ]
            }

            PressureNote {
                text: MeoI18n.translator.i18n("I/O waiting %1% · fully stalled %2% (Linux PSI, last 10 s)",
                                              Number(MeoSystem.Performance.pressure.ioSomeAvg10 || 0).toFixed(1),
                                              Number(MeoSystem.Performance.pressure.ioFullAvg10 || 0).toFixed(1))
            }
        }
    }

    // ── Network ─────────────────────────────────────────────────────────
    Component {
        id: networkDetail
        ColumnLayout {
            readonly property var network: root.selected.data || ({})
            spacing: MeoTheme.space12

            DetailHeader {
                title: root.networkKindLabel(network)
                subtitle: network.name || ""
            }

            MeoText {
                text: MeoI18n.translator.i18n("Throughput over %1 · receive and send", root.historySpan(network.rxHistory))
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }

            BigGraph {
                values: network.rxHistory || []
                secondaryValues: network.txHistory || []
                maximum: 0
                color: MeoTheme.primary
                secondaryColor: MeoTheme.tertiary
            }

            StatGrid {
                primaryStats: [
                    { "label": MeoI18n.translator.i18n("Send"), "value": root.formatBits(network.txBytesPerSecond) },
                    { "label": MeoI18n.translator.i18n("Receive"), "value": root.formatBits(network.rxBytesPerSecond) },
                    { "label": MeoI18n.translator.i18n("Status"), "value": network.up
                              ? MeoI18n.translator.i18n("Connected") : MeoI18n.translator.i18n("Not connected") },
                    { "label": MeoI18n.translator.i18n("Link speed"), "value": Number(network.speedMbps || 0) > 0
                              ? MeoI18n.translator.i18n("%1 Mbps", network.speedMbps) : "—" }
                ]
                secondaryStats: [
                    { "label": MeoI18n.translator.i18n("Addresses"), "value": network.addressSummary || "—" },
                    { "label": MeoI18n.translator.i18n("Hardware address"), "value": network.hardwareAddress || "—" },
                    { "label": MeoI18n.translator.i18n("Errors"), "value": MeoI18n.translator.i18n("↓%1 · ↑%2", network.rxErrors || 0, network.txErrors || 0) },
                    { "label": MeoI18n.translator.i18n("Dropped"), "value": MeoI18n.translator.i18n("↓%1 · ↑%2", network.rxDropped || 0, network.txDropped || 0) }
                ]
            }
        }
    }

    // ── GPU ─────────────────────────────────────────────────────────────
    Component {
        id: gpuDetail
        ColumnLayout {
            readonly property var gpu: root.selected.data || ({})
            spacing: MeoTheme.space12

            DetailHeader {
                title: root.selected.title
                subtitle: gpu.name || ""
            }

            MeoText {
                text: MeoI18n.translator.i18n("% Utilization over %1", root.historySpan(gpu.history))
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }

            BigGraph {
                values: gpu.history || []
                maximum: 100
                color: MeoTheme.tertiary
                topRightLabel: "100%"
            }

            MeoText {
                Layout.fillWidth: true
                visible: Number(gpu.memoryTotalBytes || 0) > 0
                text: MeoI18n.translator.i18n("Dedicated memory %1 / %2", root.formatBytes(gpu.memoryUsedBytes), root.formatBytes(gpu.memoryTotalBytes))
                typeRole: "label"; typeSize: "medium"
                color: MeoTheme.contentOnSurfaceVariant
            }
            MeoProgressBar {
                Layout.fillWidth: true
                visible: Number(gpu.memoryTotalBytes || 0) > 0
                value: Number(gpu.memoryUsedBytes || 0) / Math.max(1, Number(gpu.memoryTotalBytes || 0))
                activeColor: MeoTheme.tertiary
                wavy: true
            }

            StatGrid {
                primaryStats: [
                    { "label": MeoI18n.translator.i18n("Utilization"), "value": root.percent(gpu.usage) },
                    { "label": MeoI18n.translator.i18n("Temperature"), "value": gpu.temperature > 0 ? Math.round(gpu.temperature) + " °C" : "—" },
                    { "label": MeoI18n.translator.i18n("Power"), "value": Number(gpu.powerWatts || 0) > 0 ? Number(gpu.powerWatts).toFixed(1) + " W" : "—" },
                    { "label": MeoI18n.translator.i18n("Core clock"), "value": root.formatFrequency(gpu.coreClockMHz) }
                ]
                secondaryStats: [
                    { "label": MeoI18n.translator.i18n("Memory clock"), "value": root.formatFrequency(gpu.memoryClockMHz) },
                    { "label": MeoI18n.translator.i18n("Dedicated memory"), "value": Number(gpu.memoryTotalBytes || 0) > 0
                              ? root.formatBytes(gpu.memoryTotalBytes) : MeoI18n.translator.i18n("Not reported") },
                    { "label": MeoI18n.translator.i18n("Driver"), "value": gpu.driver || "—" }
                ]
            }
        }
    }

    // ── Building blocks ─────────────────────────────────────────────────
    component ResourceEntry: QQC2.AbstractButton {
        id: entry
        property var resource: ({})
        property bool selected: false

        implicitHeight: 64 * root.scaleFactor
        hoverEnabled: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: (resource.title || "") + ", " + (resource.line || "")
        Accessible.checked: selected

        background: MeoShape {
            type: "rect"
            radius: MeoTheme.shapeMedium
            strokeWidth: 0
            color: entry.selected ? MeoTheme.secondaryContainer
                   : (entry.hovered ? MeoTheme.surfaceContainerHigh : "transparent")
        }

        contentItem: RowLayout {
            spacing: MeoTheme.space8

            Item { Layout.preferredWidth: MeoTheme.space4 }

            MeoCard {
                Layout.preferredWidth: 64 * root.scaleFactor
                Layout.preferredHeight: 44 * root.scaleFactor
                type: "outlined"
                radius: MeoTheme.shapeExtraSmall
                padding: 1
                PerformanceGraph {
                    anchors.fill: parent
                    values: entry.resource.history || []
                    secondaryValues: entry.resource.secondary || []
                    primaryColor: entry.resource.color || MeoTheme.primary
                    maximum: entry.resource.maximum || 0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MeoText {
                    Layout.fillWidth: true
                    text: entry.resource.title || ""
                    typeRole: "title"; typeSize: "small"; emphasized: true
                    color: entry.selected ? MeoTheme.contentOnSecondaryContainer : MeoTheme.contentOnSurface
                    elide: Text.ElideRight
                }
                MeoText {
                    Layout.fillWidth: true
                    visible: (entry.resource.subtitle || "") !== ""
                    text: entry.resource.subtitle || ""
                    typeRole: "label"; typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
                MeoText {
                    Layout.fillWidth: true
                    text: entry.resource.line || ""
                    typeRole: "label"; typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    component DetailHeader: RowLayout {
        id: header
        property string title: ""
        property string subtitle: ""
        Layout.fillWidth: true
        spacing: MeoTheme.space12

        MeoText {
            text: header.title
            typeRole: "title"; typeSize: "big"
            color: MeoTheme.contentOnSurface
        }
        MeoText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: header.subtitle
            typeRole: "title"; typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            elide: Text.ElideRight
        }
    }

    component BigGraph: MeoCard {
        id: bigGraph
        property var values: []
        property var secondaryValues: []
        property real maximum: 0
        property color color: MeoTheme.primary
        property color secondaryColor: MeoTheme.tertiary
        property string topRightLabel: ""

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(180 * root.scaleFactor, Math.min(320 * root.scaleFactor, width * 0.42))
        type: "outlined"
        radius: MeoTheme.shapeSmall
        padding: 1

        PerformanceGraph {
            anchors.fill: parent
            values: bigGraph.values
            secondaryValues: bigGraph.secondaryValues
            maximum: bigGraph.maximum
            primaryColor: bigGraph.color
            secondaryColor: bigGraph.secondaryColor
            showGrid: true
        }
        MeoText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: MeoTheme.space4
            visible: bigGraph.topRightLabel !== ""
            text: bigGraph.topRightLabel
            typeRole: "label"; typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
        }
    }

    // Two groups like Windows: large live values, then static facts.
    component StatGrid: GridLayout {
        id: stats
        property var primaryStats: []
        property var secondaryStats: []
        Layout.fillWidth: true
        columns: width >= 560 * root.scaleFactor ? 2 : 1
        columnSpacing: MeoTheme.space24
        rowSpacing: MeoTheme.space8

        GridLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            columns: 2
            columnSpacing: MeoTheme.space16
            rowSpacing: MeoTheme.space8
            Repeater {
                model: stats.primaryStats
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    MeoText {
                        text: modelData.label
                        typeRole: "label"; typeSize: "medium"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: modelData.value
                        typeRole: "title"; typeSize: "medium"; emphasized: true
                        color: MeoTheme.contentOnSurface
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: stats.columns === 1
            Layout.preferredWidth: stats.columns === 1 ? -1 : 300 * root.scaleFactor
            Layout.alignment: Qt.AlignTop
            spacing: MeoTheme.space4
            Repeater {
                model: stats.secondaryStats
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: MeoTheme.space12
                    MeoText {
                        Layout.preferredWidth: 140 * root.scaleFactor
                        text: modelData.label
                        typeRole: "body"; typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: modelData.value
                        typeRole: "body"; typeSize: "small"
                        color: MeoTheme.contentOnSurface
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    component PressureNote: MeoText {
        Layout.fillWidth: true
        visible: !!MeoSystem.Performance.pressure.available
        typeRole: "body"; typeSize: "small"
        color: MeoTheme.contentOnSurfaceVariant
        wrapMode: Text.WordWrap
    }
}
