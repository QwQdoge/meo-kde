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

    readonly property real taskExtent: 30 * MeoTheme.globalScale
    readonly property real stripPadding: MeoTheme.space4
    readonly property real activeLabelExtent: activeApplicationAvailable
                                                ? 148 * MeoTheme.globalScale : 0
    readonly property int taskLimit: {
        const configured = Number(Plasmoid.configuration.taskLimit)
        return Number.isFinite(configured)
               ? Math.max(1, Math.min(12, Math.round(configured)))
               : 8
    }
    // TasksModel is a C++ QAbstractItemModel. Make every active-app lookup
    // explicitly depend on its row/data signals so identity updates after
    // Plasma has constructed the panel applet.
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
    // Keep the task strip's original reserved width so Plasma never freezes
    // this compact applet too narrow while TasksModel is still populating.
    // The named active-app pill is an additional leading surface.
    readonly property real compactWidth: activeLabelExtent
                                         + taskLimit * taskExtent
                                         + 2 * stripPadding

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Open applications")
    toolTipMainText: activeApplicationAvailable
                     ? activeApplicationName
                     : MeoI18n.translator.i18n("Open applications")
    toolTipSubText: activeApplicationAvailable
                    ? MeoI18n.translator.i18n("Current application and open applications")
                    : MeoI18n.translator.i18n("KDE window controls in a compact Meo strip")
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

    // KDE remains the source of truth for application identity, open windows,
    // grouping and activation. AppId is the KService desktop storage id and
    // AppName is KDE's application name; Meo never scans processes to guess it.
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

        Row {
            anchors.centerIn: parent
            spacing: 0

            QQC2.AbstractButton {
                id: activeAppButton
                visible: root.activeApplicationAvailable
                width: visible ? root.activeLabelExtent : 0
                height: root.taskExtent
                hoverEnabled: true
                Accessible.name: root.activeApplicationName
                Accessible.description: MeoI18n.translator.i18n("Open application menu")
                onClicked: appMenu.openAt(activeAppButton, 0,
                                          activeAppButton.height + MeoTheme.space4)

                background: MeoShape {
                    type: "pill"
                    radius: height / 2
                    color: appMenu.opened
                           ? MeoTheme.primaryContainer
                           : (activeAppButton.hovered || activeAppButton.down
                              ? MeoTheme.surfaceContainerHighest
                              : MeoTheme.surfaceContainer)
                }

                contentItem: RowLayout {
                    spacing: MeoTheme.space8

                    Kirigami.Icon {
                        Layout.preferredWidth: 18 * MeoTheme.globalScale
                        Layout.preferredHeight: Layout.preferredWidth
                        source: root.activeApplicationIcon
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: appMenu.opened
                                               ? MeoTheme.onPrimaryContainer
                                               : MeoTheme.onSurface
                        }
                    }

                    MeoText {
                        Layout.fillWidth: true
                        text: root.activeApplicationName
                        typeRole: "label"
                        typeSize: "large"
                        emphasized: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: appMenu.opened
                               ? MeoTheme.onPrimaryContainer
                               : MeoTheme.contentOnSurface
                    }

                    MeoIcon {
                        icon: "expand_more"
                        size: 16
                        color: appMenu.opened
                               ? MeoTheme.onPrimaryContainer
                               : MeoTheme.contentOnSurfaceVariant
                    }
                }

                MeoTooltip {
                    visible: activeAppButton.hovered
                             && root.activeApplicationName !== ""
                    text: root.activeApplicationName
                    delay: MeoTheme.motionDurationLong1
                }
            }

            Repeater {
                model: tasksModel

                delegate: QQC2.AbstractButton {
                    id: taskButton

                    required property int index
                    readonly property var taskIndex: tasksModel.index(index, 0)
                    readonly property bool active: {
                        root.taskRevision
                        return tasksModel.data(taskIndex,
                            TaskManager.AbstractTasksModel.IsActive) || false
                    }
                    readonly property string taskTitle: {
                        root.taskRevision
                        return tasksModel.data(taskIndex, 0) || ""
                    }
                    readonly property var taskIcon: {
                        root.taskRevision
                        return tasksModel.data(taskIndex, 1)
                    }
                    // The active task is represented by the named application
                    // pill at the left. Keep the remaining task strip compact.
                    readonly property bool withinLimit: index < root.taskLimit
                    visible: withinLimit && !(root.activeApplicationAvailable && active)
                    width: visible ? root.taskExtent : 0
                    height: root.taskExtent
                    Accessible.name: taskTitle
                    Accessible.description: MeoI18n.translator.i18n("Activate application")
                    onClicked: tasksModel.requestActivate(taskIndex)

                    background: MeoShape {
                        type: "pill"
                        radius: Math.min(width, height) / 2
                        color: taskButton.hovered || taskButton.down
                               ? MeoTheme.surfaceContainerHighest
                               : MeoTheme.surfaceContainer
                    }

                    contentItem: Item {
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 18 * MeoTheme.globalScale
                            height: width
                            source: taskButton.taskIcon
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: MeoTheme.onSurface
                            }
                        }
                    }

                    MeoTooltip {
                        visible: taskButton.hovered && taskButton.taskTitle !== ""
                        text: taskButton.taskTitle
                        delay: MeoTheme.motionDurationLong1
                    }
                }
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
        function onActiveTaskChanged() { root.taskRevision++ }
        function onDataChanged() { root.taskRevision++ }
        function onModelReset() { root.taskRevision++ }
        function onRowsInserted() { root.taskRevision++ }
        function onRowsRemoved() { root.taskRevision++ }
    }
}
