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
    readonly property int taskLimit: {
        const configured = Number(Plasmoid.configuration.taskLimit)
        return Number.isFinite(configured)
               ? Math.max(1, Math.min(12, Math.round(configured)))
               : 8
    }
    // Plasma evaluates a compact applet's width before TaskManager has
    // populated. Reserve the configured number of slots so the panel does
    // not freeze this applet at zero width for the whole session.
    readonly property real compactWidth: taskLimit * taskExtent + 2 * stripPadding
    // TasksModel is a C++ QAbstractItemModel. Make role lookups explicitly
    // depend on its row/data signals so icons and active state refresh after
    // the compact applet has been constructed.
    property int taskRevision: 0

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: qsTr("Open applications")
    toolTipMainText: qsTr("Open applications")
    toolTipSubText: qsTr("KDE window controls in a compact Meo strip")
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

    // KDE remains the source of truth for the open-window list, grouping and
    // activation.  The Meo layer below only renders a compact, monochrome UI.
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        // Match Plasma's own panel model: omit windows that explicitly ask to
        // stay out of task bars, while retaining ordinary minimized windows.
        // `true` means "filter hidden tasks", not "show only hidden tasks".
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    compactRepresentation: Item {
        id: compactRoot
        implicitWidth: root.compactWidth
        implicitHeight: ShellMetrics.topBarHeight

        Row {
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                // Bind the repeater directly to KDE's QAbstractItemModel.
                // Using an integer snapshot of TasksModel.count leaves an
                // otherwise non-zero applet blank if the model populates
                // after Plasma has created this compact representation.
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

                    visible: index < root.taskLimit
                    width: visible ? root.taskExtent : 0
                    height: root.taskExtent
                    Accessible.name: taskTitle
                    Accessible.description: active
                                            ? qsTr("Active application")
                                            : qsTr("Activate application")
                    onClicked: {
                        if (active)
                            tasksModel.requestToggleMinimized(taskIndex)
                        else
                            tasksModel.requestActivate(taskIndex)
                    }

                    background: MeoShape {
                        id: taskSurface
                        type: "pill"
                        radius: Math.min(width, height) / 2
                        color: taskButton.active
                               ? MeoTheme.primaryContainer
                               : (taskButton.hovered || taskButton.down
                                  ? MeoTheme.surfaceContainerHighest
                                  : MeoTheme.surfaceContainer)

                    }

                    contentItem: Item {
                        Kirigami.Icon {
                            id: taskIconItem
                            anchors.centerIn: parent
                            width: 18 * MeoTheme.globalScale
                            height: width
                            source: taskButton.taskIcon

                            // Qt's colorization effect gives application
                            // identities one Meo color without replacing KDE's
                            // real icon and task data with a fake symbol.
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: taskButton.active
                                                   ? MeoTheme.onPrimaryContainer
                                                   : MeoTheme.onSurface
                            }
                        }
                    }

                    QQC2.ToolTip.visible: hovered && taskTitle !== ""
                    QQC2.ToolTip.text: taskTitle
                    QQC2.ToolTip.delay: 450
                }
            }
        }
    }

    Connections {
        target: tasksModel
        function onDataChanged() { root.taskRevision++ }
        function onModelReset() { root.taskRevision++ }
        function onRowsInserted() { root.taskRevision++ }
        function onRowsRemoved() { root.taskRevision++ }
    }
}
