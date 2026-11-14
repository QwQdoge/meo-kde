import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    signal closeRequested()

    property int initialPage: 0
    // Embedded (Quick Settings) hosts navigate back; the standalone window
    // has its own window controls.
    property bool showBackButton: true
    property int currentPage: initialPage
    property string navigationSearchText: ""
    readonly property string performanceClientId: "system-monitor-performance-" + root.toString()
    readonly property string tasksClientId: "system-monitor-tasks-" + root.toString()
    readonly property real scaleFactor: MeoTheme.globalScale
    readonly property bool useNavigationRail: width >= 760 * scaleFactor
    readonly property bool expandedRail: width >= 1080 * scaleFactor
    readonly property string selectedNavigationRoute: navigationModel[currentPage]
                                                      ? String(navigationModel[currentPage].id) : ""
    readonly property var navigationGroups: [{ "title": "", "rows": navigationModel.map(function(item) {
        return { "route": String(item.id), "title": item.label, "leadingIcon": item.icon }
    }) }]
    readonly property var navigationSearchResults: {
        const query = navigationSearchText.trim().toLocaleLowerCase()
        if (!query)
            return []
        return navigationGroups[0].rows.filter(function(row) {
            return row.title.toLocaleLowerCase().includes(query)
        })
    }
    readonly property bool updatesPaused: MeoSystem.Tasks.paused
                                          || MeoSystem.Performance.paused
    // Pages are created the first time they are shown and then kept, so the
    // monitor opens quickly and switching back keeps scroll and selection.
    property var visitedPages: ({})
    readonly property var updateSpeeds: [500, 1000, 2000, 5000, 10000]
    readonly property int refreshInterval: MeoSystem.Performance.refreshInterval

    function intervalLabel(interval) {
        return interval < 1000
                ? MeoI18n.translator.i18n("%1 s", (interval / 1000).toFixed(1))
                : MeoI18n.translator.i18n("%1 s", Math.round(interval / 1000))
    }

    function setUpdateSpeed(interval) {
        MeoSystem.Performance.refreshInterval = interval
        MeoSystem.Tasks.refreshInterval = interval
        setPaused(false)
    }

    function setPaused(paused) {
        MeoSystem.Tasks.paused = paused
        MeoSystem.Performance.paused = paused
    }

    function markVisited(index) {
        if (visitedPages[index])
            return
        const next = Object.assign({}, visitedPages)
        next[index] = true
        visitedPages = next
    }

    function openUpdateSpeedMenu(anchor) {
        const rows = root.updateSpeeds.map(function(interval) {
            return {
                "label": root.intervalLabel(interval),
                "checked": !root.updatesPaused && root.refreshInterval === interval,
                "action": function() { root.setUpdateSpeed(interval) }
            }
        })
        rows.push({ "type": "separator" })
        rows.push({
            "label": root.updatesPaused ? MeoI18n.translator.i18n("Resume updates")
                                        : MeoI18n.translator.i18n("Pause updates"),
            "icon": root.updatesPaused ? "play_arrow" : "pause",
            "action": function() { root.setPaused(!root.updatesPaused) }
        })
        updateSpeedMenu.model = rows
        updateSpeedMenu.openAtPoint(anchor, anchor.width / 2, anchor.height)
    }

    readonly property var navigationModel: [
        { id: "processes", label: MeoI18n.translator.i18n("Processes"), icon: "apps" },
        { id: "performance", label: MeoI18n.translator.i18n("Performance"), icon: "monitoring" },
        { id: "startup", label: MeoI18n.translator.i18n("Startup"), icon: "rocket_launch" },
        { id: "services", label: MeoI18n.translator.i18n("Services"), icon: "dns" },
        { id: "users", label: MeoI18n.translator.i18n("Users"), icon: "group" },
        { id: "details", label: MeoI18n.translator.i18n("Details"), icon: "info" }
    ]

    function currentSubtitle() {
        const text = pageSubtitle()
        return updatesPaused && currentPage !== 2 && currentPage !== 3
                ? MeoI18n.translator.i18n("%1 · Updates paused", text) : text
    }

    function pageSubtitle() {
        if (currentPage === 0)
            return MeoI18n.translator.i18n("%1 processes", MeoSystem.Tasks.processes.length)
        if (currentPage === 1)
            return MeoSystem.Performance.systemSummary
        if (currentPage === 2)
            return MeoI18n.translator.i18n("%1 startup entries", MeoSystem.Tasks.startupApps.length)
        if (currentPage === 3)
            return MeoI18n.translator.i18n("%1 user services", MeoSystem.Tasks.services.length)
        if (currentPage === 4)
            return MeoI18n.translator.i18n("%1 users with running processes", MeoSystem.Tasks.userSummaries.length)
        const process = MeoSystem.Tasks.selectedProcessDetails
        return process && process.pid
               ? (process.appName || process.name || ("PID " + process.pid))
               : MeoI18n.translator.i18n("Select a process to inspect")
    }

    function selectNavigationRoute(route) {
        for (let index = 0; index < navigationModel.length; ++index) {
            if (String(navigationModel[index].id) === String(route)) {
                currentPage = index
                return
            }
        }
    }

    function syncSubscription() {
        MeoSystem.Performance.unsubscribe(performanceClientId)
        MeoSystem.Tasks.unsubscribe(tasksClientId)

        if (!visible)
            return

        if (currentPage === 0) {
            MeoSystem.Tasks.subscribe(tasksClientId, ["processes"])
            MeoSystem.Performance.subscribe(performanceClientId,
                ["cpu", "memory", "network", "disk"])
        } else if (currentPage === 1) {
            MeoSystem.Performance.subscribe(performanceClientId,
                ["cpu", "memory", "network", "disk", "gpu", "system"])
        } else if (currentPage === 2) {
            MeoSystem.Tasks.subscribe(tasksClientId, ["startup"])
        } else if (currentPage === 3) {
            MeoSystem.Tasks.subscribe(tasksClientId, ["services"])
        } else if (currentPage === 4) {
            MeoSystem.Tasks.subscribe(tasksClientId, ["users"])
        } else if (currentPage === 5) {
            MeoSystem.Tasks.subscribe(tasksClientId, ["details"])
        }
    }

    function refreshCurrentPage() {
        if (currentPage === 0) {
            MeoSystem.Tasks.refreshNow()
            MeoSystem.Performance.refreshNow()
        } else if (currentPage === 1) {
            MeoSystem.Performance.refreshNow()
        } else {
            MeoSystem.Tasks.refreshNow()
        }
    }

    Shortcut {
        sequence: "F5"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.refreshCurrentPage()
    }

    // Ctrl+1 … Ctrl+6 jump straight to a page, like browser tabs.
    Repeater {
        model: root.navigationModel.length
        delegate: Item {
            required property int index
            Shortcut {
                sequence: "Ctrl+" + (parent.index + 1)
                context: Qt.WindowShortcut
                enabled: root.visible
                onActivated: root.currentPage = parent.index
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.currentPage = (root.currentPage + 1) % root.navigationModel.length
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.currentPage = (root.currentPage + root.navigationModel.length - 1)
                                        % root.navigationModel.length
    }

    Component.onCompleted: {
        markVisited(currentPage)
        syncSubscription()
    }
    Component.onDestruction: {
        MeoSystem.Performance.unsubscribe(performanceClientId)
        MeoSystem.Tasks.unsubscribe(tasksClientId)
    }
    onVisibleChanged: syncSubscription()
    onCurrentPageChanged: {
        markVisited(currentPage)
        syncSubscription()
        if (navigationRail && navigationRail.currentIndex !== currentPage)
            navigationRail.currentIndex = currentPage
        if (compactTabs && compactTabs.currentIndex !== currentPage)
            compactTabs.currentIndex = currentPage
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoButton {
                visible: root.showBackButton
                text: MeoI18n.translator.i18n("Back")
                type: "text"
                size: "xs"
                icon.name: "arrow_back"
                onClicked: root.closeRequested()
            }

            MeoIconButton {
                visible: root.useNavigationRail && !root.expandedRail
                icon.name: "menu"
                Accessible.name: MeoI18n.translator.i18n("Open navigation")
                onClicked: navigationSidebarModal.openForNavigation()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    text: MeoI18n.translator.i18n("System monitor")
                    typeRole: "title"
                    typeSize: "large"
                    emphasized: true
                }

                MeoText {
                    Layout.fillWidth: true
                    text: root.currentSubtitle()
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            MeoButton {
                id: updateSpeedButton
                visible: root.currentPage === 0 || root.currentPage === 1
                         || root.currentPage === 4 || root.currentPage === 5
                text: root.updatesPaused
                      ? MeoI18n.translator.i18n("Paused")
                      : MeoI18n.translator.i18n("Every %1", root.intervalLabel(root.refreshInterval))
                type: root.updatesPaused ? "tonal" : "text"
                size: "xs"
                icon.name: root.updatesPaused ? "pause" : "update"
                Accessible.name: MeoI18n.translator.i18n("Update speed")
                onClicked: root.openUpdateSpeedMenu(updateSpeedButton)
            }

            MeoButton {
                text: MeoI18n.translator.i18n("Refresh")
                type: "tonal"
                size: "xs"
                icon.name: "refresh"
                onClicked: root.refreshCurrentPage()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.expandedRail ? MeoTheme.space12 : 0

            MeoNavigationRail {
                id: navigationRail
                Layout.fillHeight: true
                Layout.preferredWidth: 96 * root.scaleFactor
                visible: root.useNavigationRail && !root.expandedRail
                model: root.navigationModel
                currentIndex: root.currentPage
                onClicked: function(index) {
                    root.currentPage = index
                }
            }

            MeoSidebar {
                id: navigationSidebar
                Layout.fillHeight: true
                Layout.preferredWidth: 280 * root.scaleFactor
                visible: root.expandedRail
                groups: root.navigationGroups
                title: MeoI18n.translator.i18n("System monitor")
                searchText: root.navigationSearchText
                searchResults: root.navigationSearchResults
                selectedRoute: root.selectedNavigationRoute
                onSearchTextChanged: root.navigationSearchText = searchText
                onRouteActivated: (route, row) => {
                    root.selectNavigationRoute(route)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: MeoTheme.space12

                MeoTabs {
                    id: compactTabs
                    Layout.fillWidth: true
                    visible: !root.useNavigationRail
                    type: "secondary"
                    style: "standard"
                    isScrollable: true
                    currentIndex: root.currentPage
                    model: root.navigationModel
                    onClicked: function(index) {
                        root.currentPage = index
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentPage

                    Loader {
                        id: processLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[0] === true
                        sourceComponent: ProcessTable {
                            onDetailsRequested: root.currentPage = 5
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[1] === true
                        sourceComponent: PerformanceDashboard {}
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[2] === true
                        sourceComponent: StartupAppsPage {}
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[3] === true
                        sourceComponent: ServicesPage {}
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[4] === true
                        sourceComponent: UsersPage {
                            onProcessesRequested: function(user) {
                                root.markVisited(0)
                                const processPage = processLoader.item
                                if (processPage) {
                                    processPage.userFilter = user
                                    processPage.groupMode = false
                                    processPage.treeMode = false
                                }
                                root.currentPage = 0
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.visitedPages[5] === true
                        sourceComponent: ProcessDetailsPage {}
                    }
                }
            }
        }
    }

    MeoSidebarModal {
        id: navigationSidebarModal
        groups: root.navigationGroups
        title: MeoI18n.translator.i18n("System monitor")
        selectedRoute: root.selectedNavigationRoute
        searchText: root.navigationSearchText
        searchResults: root.navigationSearchResults
        onSearchTextChanged: root.navigationSearchText = searchText
        onRouteActivated: (route, row) => root.selectNavigationRoute(route)
    }

    MeoContextMenu {
        id: updateSpeedMenu
        parent: root
        z: 100
    }
}
