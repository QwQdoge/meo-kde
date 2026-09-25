import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    readonly property real stripPadding: MeoTheme.space4
    // Keep the active-application title close to a macOS-style menu-bar item:
    // compact for short names, bounded for long names, and never a task icon.
    readonly property real appExtent: Math.max(72 * MeoTheme.globalScale,
                                               Math.min(196 * MeoTheme.globalScale,
                                                        (32 + visibleApplicationName.length * 8)
                                                        * MeoTheme.globalScale))
    readonly property real compactWidth: appExtent + 2 * stripPadding
    property int taskRevision: 0

    readonly property var activeTaskIndex: {
        taskRevision
        return tasksModel.activeTask
    }
    readonly property string activeApplicationId: {
        taskRevision
        return tasksModel.data(activeTaskIndex,
                               TaskManager.AbstractTasksModel.AppId) || ""
    }
    readonly property string activeApplicationName: {
        taskRevision
        const name = tasksModel.data(activeTaskIndex,
                                     TaskManager.AbstractTasksModel.AppName)
        return name || tasksModel.data(activeTaskIndex, 0) || ""
    }
    readonly property bool activeApplicationAvailable: activeApplicationName !== ""
    readonly property string visibleApplicationName: activeApplicationAvailable
                                                     ? activeApplicationName
                                                     : MeoI18n.translator.i18n("Desktop")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Active application")
    toolTipMainText: visibleApplicationName
    toolTipSubText: activeApplicationAvailable
                    ? MeoI18n.translator.i18n("Open this application's configuration menu")
                    : MeoI18n.translator.i18n("No application window is active")
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: compactWidth
    Layout.preferredWidth: compactWidth
    Layout.maximumWidth: compactWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight
    Layout.preferredHeight: ShellMetrics.topBarHeight
    Layout.maximumHeight: ShellMetrics.topBarHeight

    Component.onCompleted: MeoShellTheme.sync()

    // KDE is the source of truth for application identity. The separate
    // org.kde.plasma.appmenu applet placed immediately after this widget owns
    // File/Edit/View/etc and renders only menus exported by the application.
    // This surface deliberately does not invent or mirror application menus.
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    function applicationConfigDeepLink() {
        if (!activeApplicationAvailable)
            return ""
        const query = []
        if (/^[A-Za-z0-9][A-Za-z0-9._+@-]{0,255}$/.test(activeApplicationId))
            query.push("appId=" + encodeURIComponent(activeApplicationId))
        query.push("appName=" + encodeURIComponent(activeApplicationName))
        query.push("section=config")
        return "meosettings://applications?" + query.join("&")
    }

    function openApplicationConfiguration() {
        const url = applicationConfigDeepLink()
        if (url !== "")
            Qt.openUrlExternally(url)
    }

    compactRepresentation: Item {
        id: compactRoot
        implicitWidth: root.compactWidth
        implicitHeight: ShellMetrics.topBarHeight

        QQC2.AbstractButton {
            id: activeAppButton
            anchors.centerIn: parent
            width: root.appExtent
            height: 30 * MeoTheme.globalScale
            hoverEnabled: true
            enabled: root.activeApplicationAvailable
            Accessible.name: root.visibleApplicationName
            Accessible.description: root.activeApplicationAvailable
                                    ? MeoI18n.translator.i18n("Open application settings menu")
                                    : MeoI18n.translator.i18n("No application window is active")
            onClicked: appMenu.openAt(activeAppButton, 0,
                                      activeAppButton.height + MeoTheme.space4)

            background: MeoShape {
                type: "rounded"
                radius: MeoTheme.shapeMedium
                color: appMenu.opened
                       ? MeoTheme.surfaceContainerHighest
                       : (activeAppButton.hovered || activeAppButton.down
                          ? MeoTheme.surfaceContainerHigh
                          : "transparent")
            }

            contentItem: RowLayout {
                spacing: 0

                MeoText {
                    Layout.fillWidth: true
                    text: root.visibleApplicationName
                    typeRole: "label"
                    typeSize: "large"
                    emphasized: root.activeApplicationAvailable
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: root.activeApplicationAvailable
                           ? MeoTheme.contentOnSurface
                           : MeoTheme.contentOnSurfaceVariant
                }
            }

            MeoTooltip {
                visible: activeAppButton.hovered
                         && root.activeApplicationAvailable
                text: root.activeApplicationName
                delay: MeoTheme.motionDurationLong1
            }
        }

        // This is the shell-owned application-name menu, analogous to the
        // application-name menu on macOS. Only generic Meo integration lives
        // here. The application's actual menus remain the KDE Global Menu
        // applet beside this widget.
        MeoMenu {
            id: appMenu
            parent: compactRoot
            preferredMenuWidth: 260 * MeoTheme.globalScale
            model: [
                {
                    "label": MeoI18n.translator.i18n("Settings…"),
                    "icon": "settings",
                    "supportingText": MeoI18n.translator.i18n("Open verified .config and app configuration"),
                    "action": function() { root.openApplicationConfiguration() }
                }
            ]
        }
    }

    Connections {
        target: tasksModel
        function onActiveTaskChanged() {
            root.taskRevision++
            if (appMenu.opened)
                appMenu.close()
        }
        function onDataChanged() { root.taskRevision++ }
        function onModelReset() { root.taskRevision++ }
        function onRowsInserted() { root.taskRevision++ }
        function onRowsRemoved() { root.taskRevision++ }
    }
}
