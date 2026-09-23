import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    signal detailsRequested()

    property string categoryFilter: "all"
    property bool treeMode: false
    property string sortProperty: "cpuText"
    property bool sortAscending: false
    readonly property real scaleFactor: MeoTheme.globalScale
    readonly property var selectedProcess: MeoSystem.Tasks.selectedProcessDetails

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
        if (rate < 1024)
            return rate.toFixed(0) + " B/s"
        return formatBytes(rate) + "/s"
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

    function categoryLabel(category) {
        if (category === "app")
            return MeoI18n.translator.i18n("App")
        if (category === "system")
            return MeoI18n.translator.i18n("System")
        return MeoI18n.translator.i18n("Background")
    }

    function numericSortRole(role) {
        if (role === "cpuText") return "cpu"
        if (role === "memoryText") return "memoryBytes"
        if (role === "diskText") return "diskTotal"
        if (role === "stateText") return "state"
        return role
    }

    function indentedName(process) {
        const label = process.appName || process.name || ""
        if (!treeMode)
            return label
        const depth = Math.max(0, Math.min(12, Number(process.treeDepth || 0)))
        let prefix = ""
        for (let i = 0; i < depth; ++i)
            prefix += "·· "
        return depth > 0 ? prefix + "↳ " + label : label
    }

    function buildRows() {
        const source = treeMode ? (MeoSystem.Tasks.processTree || [])
                                : (MeoSystem.Tasks.processes || [])
        const query = processSearch.text.trim().toLowerCase()
        const rows = []
        for (let i = 0; i < source.length; ++i) {
            const process = source[i]
            if (categoryFilter !== "all" && process.category !== categoryFilter)
                continue
            const haystack = [
                process.name || "",
                process.appName || "",
                process.command || "",
                process.user || "",
                String(process.pid || "")
            ].join(" ").toLowerCase()
            if (query !== "" && haystack.indexOf(query) === -1)
                continue

            const readRate = Number(process.diskReadBytesPerSecond || 0)
            const writeRate = Number(process.diskWriteBytesPerSecond || 0)
            rows.push({
                pid: Number(process.pid || 0),
                parentPid: Number(process.parentPid || 0),
                name: process.name || "",
                appName: process.appName || process.name || "",
                displayName: indentedName(process),
                command: process.command || "",
                executable: process.executable || "",
                user: process.user || "",
                state: process.state || "",
                stateText: stateLabel(process.state),
                category: process.category || "background",
                categoryText: categoryLabel(process.category),
                threads: Number(process.threads || 0),
                nice: Number(process.nice || 0),
                treeDepth: Number(process.treeDepth || 0),
                cpu: Number(process.cpu || 0),
                cpuText: Number(process.cpu || 0).toFixed(1) + "%",
                memoryBytes: Number(process.memoryBytes || 0),
                memoryText: formatBytes(process.memoryBytes),
                diskReadBytesPerSecond: readRate,
                diskWriteBytesPerSecond: writeRate,
                diskTotal: readRate + writeRate,
                diskText: "R " + formatRate(readRate) + " · W " + formatRate(writeRate),
                canControl: !!process.canControl,
                efficiency: !!process.efficiency,
                selected: Number(process.pid || 0) === MeoSystem.Tasks.selectedPid,
                enabled: true
            })
        }

        if (treeMode)
            return rows

        const role = numericSortRole(sortProperty)
        rows.sort(function(left, right) {
            const a = left[role]
            const b = right[role]
            let result = 0
            if (typeof a === "number" && typeof b === "number")
                result = a < b ? -1 : (a > b ? 1 : 0)
            else
                result = String(a || "").localeCompare(String(b || ""))
            if (result === 0)
                result = Number(left.pid) - Number(right.pid)
            return sortAscending ? result : -result
        })
        return rows
    }

    function tableColumns() {
        const sort = !treeMode
        if (width < 620 * scaleFactor) {
            return [
                { label: MeoI18n.translator.i18n("Name"), property: "displayName", sortable: sort },
                { label: "CPU", property: "cpuText", sortable: sort },
                { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: sort }
            ]
        }
        if (width < 860 * scaleFactor) {
            return [
                { label: MeoI18n.translator.i18n("Name"), property: "displayName", sortable: sort },
                { label: "CPU", property: "cpuText", sortable: sort },
                { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: sort },
                { label: MeoI18n.translator.i18n("Disk"), property: "diskText", sortable: sort }
            ]
        }
        return [
            { label: MeoI18n.translator.i18n("Name"), property: "displayName", sortable: sort },
            { label: "PID", property: "pid", sortable: sort },
            { label: MeoI18n.translator.i18n("Type"), property: "categoryText", sortable: sort },
            { label: "CPU", property: "cpuText", sortable: sort },
            { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: sort },
            { label: MeoI18n.translator.i18n("Disk"), property: "diskText", sortable: sort }
        ]
    }

    readonly property var processRows: buildRows()
    readonly property var columns: tableColumns()

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space8

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoTextField {
                id: processSearch
                Layout.fillWidth: true
                size: "s"
                type: "filled"
                placeholder: MeoI18n.translator.i18n("Search processes")
                leadingIcon: "search"
                showClearButton: true
            }

            MeoText {
                visible: root.width >= 600 * root.scaleFactor
                text: MeoI18n.translator.i18n("%1 shown").arg(root.processRows.length)
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoSegmentedButtons {
                Layout.fillWidth: root.width < 760 * root.scaleFactor
                Layout.maximumWidth: 520 * root.scaleFactor
                size: "s"
                currentIndex: root.categoryFilter === "all" ? 0
                              : root.categoryFilter === "app" ? 1
                              : root.categoryFilter === "background" ? 2 : 3
                model: [
                    { label: MeoI18n.translator.i18n("All"), icon: "apps" },
                    { label: MeoI18n.translator.i18n("Apps"), icon: "window" },
                    { label: MeoI18n.translator.i18n("Background"), icon: "settings" },
                    { label: MeoI18n.translator.i18n("System"), icon: "dns" }
                ]
                onSelected: function(index) {
                    root.categoryFilter = index === 0 ? "all"
                                        : index === 1 ? "app"
                                        : index === 2 ? "background" : "system"
                }
            }

            Item { Layout.fillWidth: root.width >= 760 * root.scaleFactor }

            MeoChip {
                label: MeoI18n.translator.i18n("Process tree")
                leadingIcon: "account_tree"
                type: "filter"
                visualStyle: "outlined"
                shape: "pill"
                selected: root.treeMode
                onClicked: root.treeMode = !root.treeMode
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: MeoSystem.Tasks.actionError !== ""
            text: MeoSystem.Tasks.actionError
            tone: "warning"
            dismissible: true
            onDismissed: MeoSystem.Tasks.clearActionError()
        }

        MeoDataTable {
            id: processTable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220 * root.scaleFactor
            columns: root.columns
            model: root.processRows
            selectable: false
            showDividers: false
            hoverEffect: true
            sortProperty: root.sortProperty
            sortAscending: root.sortAscending
            rowHeight: 48 * root.scaleFactor
            cornerRadius: MeoTheme.shapeLarge

            onSortRequested: function(property, ascending) {
                if (root.treeMode)
                    return
                root.sortProperty = property
                root.sortAscending = ascending
            }
            onRowActivated: function(index, row) {
                if (row)
                    MeoSystem.Tasks.selectProcess(row.pid)
            }
        }

        MeoCard {
            Layout.fillWidth: true
            visible: root.selectedProcess && root.selectedProcess.pid > 0
            type: "filled"
            radius: MeoTheme.shapeLargeIncreased

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space12

                    MeoIcon {
                        icon: root.selectedProcess && root.selectedProcess.category === "app"
                              ? "window" : root.selectedProcess && root.selectedProcess.category === "system"
                                ? "dns" : "settings"
                        size: 28
                        color: MeoTheme.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MeoText {
                            Layout.fillWidth: true
                            text: root.selectedProcess ? (root.selectedProcess.appName || root.selectedProcess.name) : ""
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                            elide: Text.ElideRight
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: root.selectedProcess
                                  ? "PID " + root.selectedProcess.pid
                                    + " · " + root.selectedProcess.user
                                    + " · " + root.stateLabel(root.selectedProcess.state)
                                    + " · " + MeoI18n.translator.i18n("%1 threads").arg(root.selectedProcess.threads)
                                  : ""
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    MeoChip {
                        visible: root.width >= 650 * root.scaleFactor
                        label: root.selectedProcess ? root.categoryLabel(root.selectedProcess.category) : ""
                        leadingIcon: root.selectedProcess && root.selectedProcess.category === "app"
                                     ? "window" : root.selectedProcess && root.selectedProcess.category === "system"
                                       ? "dns" : "settings"
                        type: "assist"
                        shape: "pill"
                        elevated: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space8

                    MeoText {
                        text: root.selectedProcess
                              ? Number(root.selectedProcess.cpu || 0).toFixed(1) + "% CPU"
                              : ""
                        typeRole: "label"
                        typeSize: "small"
                        emphasized: true
                    }
                    MeoText {
                        text: root.selectedProcess ? root.formatBytes(root.selectedProcess.memoryBytes) : ""
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.selectedProcess
                              ? "R " + root.formatRate(root.selectedProcess.diskReadBytesPerSecond)
                                + " · W " + root.formatRate(root.selectedProcess.diskWriteBytesPerSecond)
                              : ""
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space8
                    visible: root.selectedProcess && root.selectedProcess.canControl

                    MeoButton {
                        text: MeoI18n.translator.i18n("Details")
                        type: "text"
                        size: "xs"
                        icon.name: "info"
                        onClicked: root.detailsRequested()
                    }

                    MeoButton {
                        text: root.selectedProcess && root.selectedProcess.efficiency
                              ? MeoI18n.translator.i18n("Efficiency on")
                              : MeoI18n.translator.i18n("Efficiency")
                        type: root.selectedProcess && root.selectedProcess.efficiency ? "tonal" : "outlined"
                        size: "xs"
                        icon.name: "eco"
                        onClicked: if (root.selectedProcess)
                            MeoSystem.Tasks.setProcessEfficiency(
                                root.selectedProcess.pid, !root.selectedProcess.efficiency)
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { label: MeoI18n.translator.i18n("High"), nice: -5 },
                            { label: MeoI18n.translator.i18n("Normal"), nice: 0 },
                            { label: MeoI18n.translator.i18n("Low"), nice: 10 }
                        ]
                        delegate: MeoChip {
                            required property var modelData
                            visible: root.width >= 780 * root.scaleFactor
                            label: modelData.label
                            type: "suggestion"
                            visualStyle: "outlined"
                            shape: "pill"
                            onClicked: if (root.selectedProcess)
                                MeoSystem.Tasks.setProcessPriority(root.selectedProcess.pid, modelData.nice)
                        }
                    }

                    MeoButton {
                        text: MeoI18n.translator.i18n("End task")
                        type: "tonal"
                        size: "xs"
                        icon.name: "stop_circle"
                        onClicked: endDialog.open()
                    }

                    MeoButton {
                        visible: root.width >= 680 * root.scaleFactor
                        text: MeoI18n.translator.i18n("Force stop")
                        type: "text"
                        size: "xs"
                        onClicked: forceDialog.open()
                    }
                }
            }
        }
    }

    MeoDialog {
        id: endDialog
        parent: root
        title: MeoI18n.translator.i18n("End %1?")
               .arg(root.selectedProcess ? (root.selectedProcess.appName || root.selectedProcess.name) : "")
        message: MeoI18n.translator.i18n("The process will be asked to exit. Unsaved work can be lost.")
        icon: "warning"
        confirmText: MeoI18n.translator.i18n("End task")
        cancelText: MeoI18n.translator.i18n("Cancel")
        onConfirmed: if (root.selectedProcess)
            MeoSystem.Tasks.terminateProcess(root.selectedProcess.pid, false)
    }

    MeoDialog {
        id: forceDialog
        parent: root
        title: MeoI18n.translator.i18n("Force stop %1?")
               .arg(root.selectedProcess ? (root.selectedProcess.appName || root.selectedProcess.name) : "")
        message: MeoI18n.translator.i18n("The process will be stopped immediately. Unsaved work can be lost.")
        icon: "warning"
        confirmText: MeoI18n.translator.i18n("Force stop")
        cancelText: MeoI18n.translator.i18n("Cancel")
        onConfirmed: if (root.selectedProcess)
            MeoSystem.Tasks.terminateProcess(root.selectedProcess.pid, true)
    }
}
