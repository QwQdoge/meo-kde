import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    property string selectedUnit: ""
    property string selectedScope: ""
    property string stateFilter: "all"
    property string scopeFilter: "all"
    property string sortProperty: "unit"
    property bool sortAscending: true
    readonly property real scaleFactor: MeoTheme.globalScale
    readonly property var serviceDetails: {
        const details = MeoSystem.Tasks.selectedServiceDetails || ({})
        if ((details.unit || "") !== selectedUnit
                || (details.scope || "") !== selectedScope)
            return ({})
        return details
    }

    function formatBytes(value) {
        const bytes = Number(value)
        if (!isFinite(bytes) || bytes < 0)
            return "—"
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let size = bytes
        let unit = 0
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024
            ++unit
        }
        return (unit >= 3 ? size.toFixed(1) : size.toFixed(unit === 0 ? 0 : 1))
               + " " + units[unit]
    }

    function formatDuration(value) {
        const seconds = Number(value)
        if (!isFinite(seconds) || seconds < 0)
            return "—"
        if (seconds >= 3600)
            return (seconds / 3600).toFixed(1) + " h"
        if (seconds >= 60)
            return (seconds / 60).toFixed(1) + " min"
        return seconds.toFixed(seconds >= 10 ? 0 : 1) + " s"
    }

    function buildRows() {
        const source = MeoSystem.Tasks.services || []
        const query = search.text.trim().toLowerCase()
        const rows = []
        for (let i = 0; i < source.length; ++i) {
            const service = source[i]
            const active = String(service.activeState || "")
            const scope = String(service.scope || "user")
            if (scopeFilter !== "all" && scope !== scopeFilter)
                continue
            if (stateFilter === "running" && active !== "active")
                continue
            if (stateFilter === "failed" && active !== "failed")
                continue
            const haystack = [
                service.unit || "",
                service.description || "",
                service.activeState || "",
                service.subState || "",
                service.enabledState || ""
            ].join(" ").toLowerCase()
            if (query !== "" && haystack.indexOf(query) === -1)
                continue
            rows.push({
                unit: service.unit || "",
                description: service.description || "",
                loadState: service.loadState || "",
                activeState: active,
                subState: service.subState || "",
                enabledState: service.enabledState || "",
                scope: scope,
                scopeText: scope === "system"
                           ? MeoI18n.translator.i18n("System")
                           : MeoI18n.translator.i18n("User"),
                actionable: service.actionable !== false,
                stateText: active === "active"
                           ? MeoI18n.translator.i18n("Running")
                           : active === "failed"
                             ? MeoI18n.translator.i18n("Failed")
                             : MeoI18n.translator.i18n("Stopped"),
                startupText: service.enabledState || "—",
                selected: (service.unit || "") === root.selectedUnit
                          && scope === root.selectedScope,
                enabled: true
            })
        }

        const role = root.sortProperty
        rows.sort(function(left, right) {
            const a = String(left[role] || "")
            const b = String(right[role] || "")
            const result = a.localeCompare(b)
            return root.sortAscending ? result : -result
        })
        return rows
    }

    function selectedService() {
        const source = MeoSystem.Tasks.services || []
        for (let i = 0; i < source.length; ++i) {
            if (source[i].unit === selectedUnit
                    && String(source[i].scope || "user") === selectedScope)
                return source[i]
        }
        return null
    }

    readonly property var rows: buildRows()
    readonly property var currentService: selectedService()

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoTextField {
                id: search
                Layout.fillWidth: true
                size: "s"
                type: "filled"
                placeholder: MeoI18n.translator.i18n("Search services")
                leadingIcon: "search"
                showClearButton: true
            }

            MeoButton {
                text: MeoI18n.translator.i18n("Refresh")
                type: "text"
                size: "xs"
                icon.name: "refresh"
                onClicked: MeoSystem.Tasks.refreshServices()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 760 * root.scaleFactor ? 2 : 1
            rowSpacing: MeoTheme.space8
            columnSpacing: MeoTheme.space8

            MeoSegmentedButtons {
                Layout.fillWidth: true
                Layout.maximumWidth: 430 * root.scaleFactor
                size: "s"
                currentIndex: root.stateFilter === "all" ? 0
                              : root.stateFilter === "running" ? 1 : 2
                model: [
                    { label: MeoI18n.translator.i18n("All"), icon: "dns" },
                    { label: MeoI18n.translator.i18n("Running"), icon: "play_circle" },
                    { label: MeoI18n.translator.i18n("Failed"), icon: "error" }
                ]
                onSelected: function(index) {
                    root.stateFilter = index === 0 ? "all" : index === 1 ? "running" : "failed"
                }
            }

            MeoSegmentedButtons {
                Layout.fillWidth: true
                Layout.maximumWidth: 360 * root.scaleFactor
                size: "s"
                currentIndex: root.scopeFilter === "all" ? 0
                              : root.scopeFilter === "user" ? 1 : 2
                model: [
                    { label: MeoI18n.translator.i18n("All scopes"), icon: "dns" },
                    { label: MeoI18n.translator.i18n("User"), icon: "person" },
                    { label: MeoI18n.translator.i18n("System"), icon: "computer" }
                ]
                onSelected: function(index) {
                    root.scopeFilter = index === 0 ? "all" : index === 1 ? "user" : "system"
                }
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PopupEmptyState {
                anchors.fill: parent
                visible: !MeoSystem.Tasks.serviceQuerying
                         && (!MeoSystem.Tasks.servicesAvailable || root.rows.length === 0)
                iconName: "dns"
                title: !MeoSystem.Tasks.servicesAvailable
                       ? MeoI18n.translator.i18n("Services unavailable")
                       : MeoI18n.translator.i18n("No matching services")
                description: !MeoSystem.Tasks.servicesAvailable
                             ? MeoI18n.translator.i18n("Meo could not query systemd services. System service controls remain read-only and Meo does not request administrator access.")
                             : MeoI18n.translator.i18n("Try a different search or state filter.")
                actionText: !MeoSystem.Tasks.servicesAvailable
                            ? MeoI18n.translator.i18n("Try again") : ""
                onActionRequested: MeoSystem.Tasks.refreshServices()
            }

            ColumnLayout {
                anchors.fill: parent
                visible: root.rows.length > 0
                spacing: MeoTheme.space8

                MeoDataTable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: root.width >= 780 * root.scaleFactor
                             ? [
                                   { label: MeoI18n.translator.i18n("Service"), property: "unit", sortable: true },
                                   { label: MeoI18n.translator.i18n("Description"), property: "description", sortable: true },
                                   { label: MeoI18n.translator.i18n("State"), property: "stateText", sortable: true },
                                   { label: MeoI18n.translator.i18n("Scope"), property: "scopeText", sortable: true },
                                   { label: MeoI18n.translator.i18n("Startup"), property: "startupText", sortable: true }
                               ]
                             : [
                                   { label: MeoI18n.translator.i18n("Service"), property: "unit", sortable: true },
                                   { label: MeoI18n.translator.i18n("State"), property: "stateText", sortable: true },
                                   { label: MeoI18n.translator.i18n("Startup"), property: "startupText", sortable: true }
                               ]
                    model: root.rows
                    selectable: false
                    showDividers: false
                    rowHeight: 48 * root.scaleFactor
                    cornerRadius: MeoTheme.shapeLarge
                    sortProperty: root.sortProperty
                    sortAscending: root.sortAscending
                    onSortRequested: function(property, ascending) {
                        root.sortProperty = property
                        root.sortAscending = ascending
                    }
                    onRowActivated: function(index, row) {
                        if (row) {
                            root.selectedUnit = row.unit
                            root.selectedScope = row.scope
                            MeoSystem.Tasks.selectService(row.unit, row.scope)
                        }
                    }
                }

                MeoCard {
                    Layout.fillWidth: true
                    visible: root.currentService !== null
                    type: "filled"
                    radius: MeoTheme.shapeLargeIncreased

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: MeoTheme.space12
                        spacing: MeoTheme.space8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: MeoTheme.space12

                            Rectangle {
                                width: 44 * root.scaleFactor
                                height: width
                                radius: 15 * root.scaleFactor
                                color: root.currentService && root.currentService.activeState === "active"
                                       ? MeoTheme.primaryContainer : MeoTheme.surfaceContainerHighest

                                MeoIcon {
                                    anchors.centerIn: parent
                                    icon: root.currentService && root.currentService.activeState === "active"
                                          ? "play_circle" : "dns"
                                    size: 24
                                    fill: true
                                    color: root.currentService && root.currentService.activeState === "active"
                                           ? MeoTheme.contentOnPrimaryContainer
                                           : MeoTheme.contentOnSurfaceVariant
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                MeoText {
                                    Layout.fillWidth: true
                                    text: root.currentService ? root.currentService.unit : ""
                                    typeRole: "title"
                                    typeSize: "small"
                                    emphasized: true
                                    elide: Text.ElideRight
                                }

                                MeoText {
                                    Layout.fillWidth: true
                                    text: root.currentService ? root.currentService.description : ""
                                    typeRole: "body"
                                    typeSize: "small"
                                    color: MeoTheme.contentOnSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }

                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: MeoTheme.space8

                            MeoChip {
                                label: root.currentService && root.currentService.scope === "system"
                                       ? MeoI18n.translator.i18n("System")
                                       : MeoI18n.translator.i18n("User")
                                leadingIcon: root.currentService && root.currentService.scope === "system"
                                             ? "computer" : "person"
                                type: "assist"
                                shape: "pill"
                                visualStyle: "outlined"
                            }

                            MeoChip {
                                label: root.currentService && root.currentService.activeState === "active"
                                       ? MeoI18n.translator.i18n("Running")
                                       : root.currentService && root.currentService.activeState === "failed"
                                         ? MeoI18n.translator.i18n("Failed")
                                         : MeoI18n.translator.i18n("Stopped")
                                leadingIcon: root.currentService && root.currentService.activeState === "active"
                                             ? "check_circle"
                                             : root.currentService && root.currentService.activeState === "failed"
                                               ? "error" : "pause_circle"
                                type: "assist"
                                shape: "pill"
                                elevated: root.currentService && root.currentService.activeState === "active"
                            }
                        }

                        PopupInlineMessage {
                            Layout.fillWidth: true
                            visible: root.currentService && root.currentService.scope === "system"
                            tone: "info"
                            text: MeoI18n.translator.i18n("System services are shown read-only. Meo does not request administrator access from the task manager.")
                        }

                        MeoLoadingFeedback {
                            Layout.alignment: Qt.AlignHCenter
                            visible: active
                            Layout.preferredWidth: 56 * root.scaleFactor
                            Layout.preferredHeight: 56 * root.scaleFactor
                            active: MeoSystem.Tasks.serviceDetailsQuerying
                                    && root.selectedUnit !== ""
                            accessibleName: MeoI18n.translator.i18n("Loading service details")
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            visible: !!root.serviceDetails.available
                            columns: root.width >= 760 * root.scaleFactor ? 5 : 2
                            rowSpacing: MeoTheme.space8
                            columnSpacing: MeoTheme.space8

                            ServiceStat {
                                label: "Main PID"
                                value: Number(root.serviceDetails.mainPid || 0) > 0
                                       ? String(root.serviceDetails.mainPid) : "—"
                            }

                            ServiceStat {
                                label: MeoI18n.translator.i18n("Tasks")
                                value: Number(root.serviceDetails.tasksCurrent) >= 0
                                       ? String(root.serviceDetails.tasksCurrent) : "—"
                            }

                            ServiceStat {
                                label: MeoI18n.translator.i18n("Memory")
                                value: root.formatBytes(root.serviceDetails.memoryCurrentBytes)
                            }

                            ServiceStat {
                                label: MeoI18n.translator.i18n("CPU time")
                                value: root.formatDuration(root.serviceDetails.cpuUsageSeconds)
                            }

                            ServiceStat {
                                label: MeoI18n.translator.i18n("Restarts")
                                value: Number(root.serviceDetails.restartCount) >= 0
                                       ? String(root.serviceDetails.restartCount) : "—"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: !!root.serviceDetails.available
                                     && ((root.serviceDetails.controlGroup || "") !== ""
                                         || (root.serviceDetails.fragmentPath || "") !== "")
                            spacing: MeoTheme.space4

                            MeoText {
                                Layout.fillWidth: true
                                visible: (root.serviceDetails.controlGroup || "") !== ""
                                text: MeoI18n.translator.i18n("CGroup: %1")
                                      .arg(root.serviceDetails.controlGroup || "")
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                                elide: Text.ElideMiddle
                            }

                            MeoText {
                                Layout.fillWidth: true
                                visible: (root.serviceDetails.fragmentPath || "") !== ""
                                text: MeoI18n.translator.i18n("Unit file: %1")
                                      .arg(root.serviceDetails.fragmentPath || "")
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                                elide: Text.ElideMiddle
                            }
                        }

                        PopupInlineMessage {
                            Layout.fillWidth: true
                            visible: (root.serviceDetails.error || "") !== ""
                            tone: "info"
                            text: root.serviceDetails.error || ""
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: root.currentService && root.currentService.actionable !== false
                            spacing: MeoTheme.space8

                            MeoButton {
                                text: root.currentService && root.currentService.activeState === "active"
                                      ? MeoI18n.translator.i18n("Stop")
                                      : MeoI18n.translator.i18n("Start")
                                type: "tonal"
                                size: "xs"
                                icon.name: root.currentService && root.currentService.activeState === "active"
                                           ? "stop" : "play_arrow"
                                onClicked: if (root.currentService)
                                    MeoSystem.Tasks.serviceAction(
                                        root.currentService.unit,
                                        root.currentService.activeState === "active" ? "stop" : "start")
                            }

                            MeoButton {
                                text: MeoI18n.translator.i18n("Restart")
                                type: "outlined"
                                size: "xs"
                                icon.name: "restart_alt"
                                onClicked: if (root.currentService)
                                    MeoSystem.Tasks.serviceAction(root.currentService.unit, "restart")
                            }

                            MeoButton {
                                visible: root.currentService
                                         && (root.currentService.enabledState === "enabled"
                                             || root.currentService.enabledState === "disabled")
                                text: root.currentService && root.currentService.enabledState === "enabled"
                                      ? MeoI18n.translator.i18n("Disable at sign in")
                                      : MeoI18n.translator.i18n("Enable at sign in")
                                type: "text"
                                size: "xs"
                                onClicked: if (root.currentService)
                                    MeoSystem.Tasks.serviceAction(
                                        root.currentService.unit,
                                        root.currentService.enabledState === "enabled" ? "disable" : "enable")
                            }
                        }
                    }
                }
            }

            MeoLoadingFeedback {
                anchors.centerIn: parent
                width: 96 * root.scaleFactor
                height: width
                active: MeoSystem.Tasks.serviceQuerying
                accessibleName: MeoI18n.translator.i18n("Loading services")
            }
        }
    }

    component ServiceStat: MeoCard {
        id: serviceStat
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        implicitHeight: 68 * root.scaleFactor
        type: "outlined"
        radius: MeoTheme.shapeMedium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space8
            spacing: 0

            MeoText {
                text: serviceStat.value
                typeRole: "title"
                typeSize: "small"
                emphasized: true
            }

            MeoText {
                text: serviceStat.label
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }
    }
}
