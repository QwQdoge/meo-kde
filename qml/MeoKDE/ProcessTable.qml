import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    property qint64 selectedPid: -1
    property var selectedProcess: null
    property string sortProperty: "cpuText"
    property bool sortAscending: false
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

    function numericSortRole(role) {
        if (role === "cpuText") return "cpu"
        if (role === "memoryText") return "memoryBytes"
        if (role === "stateText") return "state"
        return role
    }

    function buildRows() {
        const source = MeoSystem.Performance.processes || []
        const query = processSearch.text.trim().toLowerCase()
        const rows = []
        for (let i = 0; i < source.length; ++i) {
            const process = source[i]
            const haystack = [
                process.name || "",
                process.command || "",
                process.user || "",
                String(process.pid || "")
            ].join(" ").toLowerCase()
            if (query !== "" && haystack.indexOf(query) === -1)
                continue

            rows.push({
                pid: Number(process.pid || 0),
                parentPid: Number(process.parentPid || 0),
                name: process.name || "",
                command: process.command || "",
                user: process.user || "",
                uid: Number(process.uid || -1),
                state: process.state || "",
                stateText: root.stateLabel(process.state),
                threads: Number(process.threads || 0),
                nice: Number(process.nice || 0),
                cpu: Number(process.cpu || 0),
                cpuText: Number(process.cpu || 0).toFixed(1) + "%",
                memoryBytes: Number(process.memoryBytes || 0),
                memoryText: root.formatBytes(process.memoryBytes),
                canControl: !!process.canControl,
                selected: Number(process.pid || 0) === root.selectedPid,
                enabled: true
            })
        }

        const role = root.numericSortRole(root.sortProperty)
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
            return root.sortAscending ? result : -result
        })
        return rows
    }

    function tableColumns() {
        if (width < 620 * scaleFactor) {
            return [
                { label: MeoI18n.translator.i18n("Name"), property: "name", sortable: true },
                { label: "CPU", property: "cpuText", sortable: true },
                { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: true }
            ]
        }
        if (width < 820 * scaleFactor) {
            return [
                { label: MeoI18n.translator.i18n("Name"), property: "name", sortable: true },
                { label: "PID", property: "pid", sortable: true },
                { label: "CPU", property: "cpuText", sortable: true },
                { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: true },
                { label: MeoI18n.translator.i18n("User"), property: "user", sortable: true }
            ]
        }
        return [
            { label: MeoI18n.translator.i18n("Name"), property: "name", sortable: true },
            { label: "PID", property: "pid", sortable: true },
            { label: "CPU", property: "cpuText", sortable: true },
            { label: MeoI18n.translator.i18n("Memory"), property: "memoryText", sortable: true },
            { label: MeoI18n.translator.i18n("Threads"), property: "threads", sortable: true },
            { label: MeoI18n.translator.i18n("User"), property: "user", sortable: true }
        ]
    }

    readonly property var processRows: buildRows()
    readonly property var columns: tableColumns()

    function selectProcess(row) {
        if (!row)
            return
        selectedPid = Number(row.pid)
        selectedProcess = row
    }

    function reconcileSelection() {
        if (selectedPid <= 0)
            return
        const source = MeoSystem.Performance.processes || []
        for (let i = 0; i < source.length; ++i) {
            if (Number(source[i].pid) === selectedPid) {
                const process = source[i]
                selectedProcess = {
                    pid: Number(process.pid || 0),
                    parentPid: Number(process.parentPid || 0),
                    name: process.name || "",
                    command: process.command || "",
                    user: process.user || "",
                    state: process.state || "",
                    stateText: stateLabel(process.state),
                    threads: Number(process.threads || 0),
                    nice: Number(process.nice || 0),
                    cpu: Number(process.cpu || 0),
                    memoryBytes: Number(process.memoryBytes || 0),
                    canControl: !!process.canControl
                }
                return
            }
        }
        selectedPid = -1
        selectedProcess = null
    }

    function requestEnd(force) {
        if (!selectedProcess || !selectedProcess.canControl)
            return
        endDialog.forceAction = !!force
        endDialog.open()
    }

    Connections {
        target: MeoSystem.Performance
        function onMetricsChanged() { root.reconcileSelection() }
        function onProcessActionCompleted(pid, action) {
            if (Number(pid) === root.selectedPid
                    && (action === "terminate" || action === "force-stop")) {
                root.selectedPid = -1
                root.selectedProcess = null
            }
        }
    }

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
                text: MeoI18n.translator.i18n("%1 processes").arg(root.processRows.length)
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }

            MeoButton {
                text: MeoI18n.translator.i18n("Refresh")
                type: "text"
                size: "xs"
                icon.name: "refresh"
                onClicked: MeoSystem.Performance.refreshNow()
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: MeoSystem.Performance.processActionError !== ""
            text: MeoSystem.Performance.processActionError
            tone: "warning"
            dismissible: true
            onDismissed: MeoSystem.Performance.clearProcessActionError()
        }

        MeoDataTable {
            id: processTable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220 * root.scaleFactor
            columns: root.columns
            model: root.processRows
            selectable: false
            showDividers: true
            hoverEffect: true
            sortProperty: root.sortProperty
            sortAscending: root.sortAscending
            rowHeight: 46 * root.scaleFactor

            onSortRequested: function(property, ascending) {
                root.sortProperty = property
                root.sortAscending = ascending
            }
            onRowActivated: function(index, row) {
                root.selectProcess(row)
            }
        }

        MeoCard {
            Layout.fillWidth: true
            visible: root.selectedProcess !== null
            type: "filled"
            radius: MeoTheme.cardRadius

            RowLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space12

                MeoIcon {
                    icon: "memory"
                    size: 24
                    color: MeoTheme.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        MeoText {
                            Layout.fillWidth: true
                            text: root.selectedProcess ? root.selectedProcess.name : ""
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                            elide: Text.ElideRight
                        }
                        MeoText {
                            text: root.selectedProcess
                                  ? "PID " + root.selectedProcess.pid
                                    + " · " + Number(root.selectedProcess.cpu).toFixed(1) + "%"
                                    + " · " + root.formatBytes(root.selectedProcess.memoryBytes)
                                  : ""
                            typeRole: "label"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                        }
                    }

                    MeoText {
                        Layout.fillWidth: true
                        text: root.selectedProcess
                              ? root.selectedProcess.user
                                + " · " + root.stateLabel(root.selectedProcess.state)
                                + " · " + MeoI18n.translator.i18n("%1 threads").arg(root.selectedProcess.threads)
                                + " · nice " + root.selectedProcess.nice
                              : ""
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideRight
                    }

                    MeoText {
                        Layout.fillWidth: true
                        visible: root.selectedProcess && root.selectedProcess.command !== root.selectedProcess.name
                        text: root.selectedProcess ? root.selectedProcess.command : ""
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideMiddle
                    }
                }

                ColumnLayout {
                    visible: root.selectedProcess && root.selectedProcess.canControl
                    spacing: MeoTheme.space4

                    MeoButton {
                        text: MeoI18n.translator.i18n("End task")
                        type: "tonal"
                        size: "xs"
                        icon.name: "stop_circle"
                        onClicked: root.requestEnd(false)
                    }

                    MeoButton {
                        text: MeoI18n.translator.i18n("Force stop")
                        type: "text"
                        size: "xs"
                        onClicked: root.requestEnd(true)
                    }
                }
            }
        }
    }

    MeoDialog {
        id: endDialog
        parent: root
        property bool forceAction: false
        title: forceAction
               ? MeoI18n.translator.i18n("Force stop %1?").arg(root.selectedProcess ? root.selectedProcess.name : "")
               : MeoI18n.translator.i18n("End %1?").arg(root.selectedProcess ? root.selectedProcess.name : "")
        message: forceAction
                 ? MeoI18n.translator.i18n("The process will be stopped immediately. Unsaved work can be lost.")
                 : MeoI18n.translator.i18n("The process will be asked to exit. Unsaved work can be lost.")
        icon: "warning"
        confirmText: forceAction
                     ? MeoI18n.translator.i18n("Force stop")
                     : MeoI18n.translator.i18n("End task")
        cancelText: MeoI18n.translator.i18n("Cancel")
        onConfirmed: {
            if (root.selectedProcess)
                MeoSystem.Performance.terminateProcess(root.selectedProcess.pid, forceAction)
        }
    }
}
