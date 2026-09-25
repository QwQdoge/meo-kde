import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    readonly property real appExtent: 148 * MeoTheme.globalScale
    readonly property real stripPadding: MeoTheme.space4
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
    readonly property var activeApplicationIcon: {
        taskRevision
        return tasksModel.data(activeTaskIndex, 1)
    }
    readonly property bool activeApplicationAvailable: activeApplicationName !== ""
    readonly property string visibleApplicationName: activeApplicationAvailable
                                                     ? activeApplicationName
                                                     : MeoI18n.translator.i18n("Desktop")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Active application")
    toolTipMainText: visibleApplicationName
    toolTipSubText: activeApplicationAvailable
                    ? MeoI18n.translator.i18n("Application settings and information")
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

    // KDE is the source of truth. AppId is the KService desktop storage id
    // and AppName is the application name; Meo does not scan processes or
    // infer identity from executable names or window-title strings.
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    function applicationDeepLink(section) {
        if (!activeApplicationAvailable)
            return ""
        const query = []
        if (/^[A-Za-z0-9][A-Za-z0-9._+@-]{0,255}$/.test(activeApplicationId))
            query.push("appId=" + encodeURIComponent(activeApplicationId))
        query.push("appName=" + encodeURIComponent(activeApplicationName))
        query.push("section=" + encodeURIComponent(section))
        return "meosettings://applications?" + query.join("&")
    }

    function openApplicationManagement(section) {
        const url = applicationDeepLink(section)
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
                                    ? MeoI18n.translator.i18n("Open application menu")
                                    : MeoI18n.translator.i18n("No application window is active")
            onClicked: appMenu.openAt(activeAppButton, 0,
                                      activeAppButton.height + MeoTheme.space4)

            background: MeoShape {
                type: "pill"
                radius: height / 2
                color: appMenu.opened
                       ? MeoTheme.primaryContainer
                       : (activeAppButton.hovered || activeAppButton.down
                          ? MeoTheme.surfaceContainerHighest
                          : "transparent")
            }

            contentItem: RowLayout {
                spacing: MeoTheme.space8

                Kirigami.Icon {
                    Layout.preferredWidth: 18 * MeoTheme.globalScale
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.activeApplicationAvailable
                            ? root.activeApplicationIcon
                            : "desktop"
                    layer.enabled: root.activeApplicationAvailable
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: appMenu.opened
                                           ? MeoTheme.onPrimaryContainer
                                           : MeoTheme.onSurface
                    }
                }

                MeoText {
                    Layout.fillWidth: true
                    text: root.visibleApplicationName
                    typeRole: "label"
                    typeSize: "large"
                    emphasized: root.activeApplicationAvailable
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: appMenu.opened
                           ? MeoTheme.onPrimaryContainer
                           : root.activeApplicationAvailable
                             ? MeoTheme.contentOnSurface
                             : MeoTheme.contentOnSurfaceVariant
                }

                MeoIcon {
                    visible: root.activeApplicationAvailable
                    icon: "expand_more"
                    size: 16
                    color: appMenu.opened
                           ? MeoTheme.onPrimaryContainer
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

        MeoMenu {
            id: appMenu
            parent: compactRoot
            preferredMenuWidth: 244 * MeoTheme.globalScale
            model: [
                {
                    "label": MeoI18n.translator.i18n("App settings"),
                    "icon": "settings",
                    "supportingText": MeoI18n.translator.i18n("Open configuration for this application"),
                    "action": function() { root.openApplicationManagement("settings") }
                },
                {
                    "label": MeoI18n.translator.i18n("App info"),
                    "icon": "info",
                    "supportingText": MeoI18n.translator.i18n("Storage, cache, data and uninstall"),
                    "action": function() { root.openApplicationManagement("info") }
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
