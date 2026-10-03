import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    signal closeRequested()

    property int initialPage: 0
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

    readonly property var navigationModel: [
        { id: "processes", label: MeoI18n.translator.i18n("Processes"), icon: "apps" },
        { id: "performance", label: MeoI18n.translator.i18n("Performance"), icon: "monitoring" },
        { id: "startup", label: MeoI18n.translator.i18n("Startup"), icon: "rocket_launch" },
        { id: "services", label: MeoI18n.translator.i18n("Services"), icon: "dns" },
        { id: "users", label: MeoI18n.translator.i18n("Users"), icon: "group" },
        { id: "details", label: MeoI18n.translator.i18n("Details"), icon: "info" }
    ]

    function currentSubtitle() {
        if (currentPage === 0)
            return MeoI18n.translator.i18n("%1 processes").arg(MeoSystem.Tasks.processes.length)
        if (currentPage === 1)
            return MeoSystem.Performance.systemSummary
        if (currentPage === 2)
            return MeoI18n.translator.i18n("%1 startup entries").arg(MeoSystem.Tasks.startupApps.length)
        if (currentPage === 3)
            return MeoI18n.translator.i18n("%1 user services").arg(MeoSystem.Tasks.services.length)
        if (currentPage === 4)
            return MeoI18n.translator.i18n("%1 users with running processes").arg(MeoSystem.Tasks.userSummaries.length)
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

    Component.onCompleted: syncSubscription()
    Component.onDestruction: {
        MeoSystem.Performance.unsubscribe(performanceClientId)
        MeoSystem.Tasks.unsubscribe(tasksClientId)
    }
    onVisibleChanged: syncSubscription()
    onCurrentPageChanged: {
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
                visible: root.currentPage === 0 || root.currentPage === 1
                         || root.currentPage === 4 || root.currentPage === 5
                text: root.updatesPaused
                      ? MeoI18n.translator.i18n("Resume")
                      : MeoI18n.translator.i18n("Pause")
                type: root.updatesPaused ? "tonal" : "text"
                size: "xs"
                icon.name: root.updatesPaused ? "play_arrow" : "pause"
                onClicked: {
                    const nextPaused = !root.updatesPaused
                    MeoSystem.Tasks.paused = nextPaused
                    MeoSystem.Performance.paused = nextPaused
                }
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
                title: MeoI18n.translator.i18n("Performance")
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

                    ProcessTable {
                        id: processPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onDetailsRequested: root.currentPage = 5
                    }

                    PerformanceDashboard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    StartupAppsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    ServicesPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    UsersPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onProcessesRequested: function(user) {
                            processPage.userFilter = user
                            processPage.groupMode = false
                            processPage.treeMode = false
                            root.currentPage = 0
                        }
                    }

                    ProcessDetailsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }

    MeoSidebarModal {
        id: navigationSidebarModal
        groups: root.navigationGroups
        title: MeoI18n.translator.i18n("Performance")
        selectedRoute: root.selectedNavigationRoute
        searchText: root.navigationSearchText
        searchResults: root.navigationSearchResults
        onSearchTextChanged: root.navigationSearchText = searchText
        onRouteActivated: (route, row) => root.selectNavigationRoute(route)
    }
}
