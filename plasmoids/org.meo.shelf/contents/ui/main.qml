import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property bool showLauncherButton: Plasmoid.configuration.showLauncherButton
    readonly property bool filterTasksByVirtualDesktop: Plasmoid.configuration.filterTasksByVirtualDesktop
    readonly property bool showRunningIndicators: Plasmoid.configuration.showRunningIndicators
    readonly property bool showTooltips: Plasmoid.configuration.showTooltips
    readonly property string launcherDefaultPage: Plasmoid.configuration.launcherDefaultPage || "home"
    readonly property string launcherWidth: Plasmoid.configuration.launcherWidth || "standard"
    readonly property bool launcherShowFavorites: Plasmoid.configuration.launcherShowFavorites
    readonly property bool launcherShowRecents: Plasmoid.configuration.launcherShowRecents
    readonly property real launcherContribution: showLauncherButton
                                                 ? ShellMetrics.shelfItemSize + MeoTheme.space8
                                                 : 0

    implicitHeight: ShellMetrics.shelfPanelHeight
    implicitWidth: Math.max(72 * MeoTheme.globalScale,
                            Math.min(shelfContent.implicitWidth + 20 * MeoTheme.globalScale,
                                     Screen.width * 0.70))

    Component.onCompleted: MeoShellTheme.sync()

    // Shelf Visibility States
    readonly property int stateVisible: 0
    readonly property int stateDodgeHidden: 1
    readonly property int stateFullscreenHidden: 2
    readonly property int stateRevealed: 3

    property int currentShelfState: root.stateVisible
    property int taskRevision: 0
    property bool isEdgeHovered: edgeMouseArea.containsMouse || surfaceContainerMouse.containsMouse

    // Edge Reveal Handle (48x4, radius 2, opacity 0.35 -> hover 64x4, opacity 0.7)
    Rectangle {
        id: edgeHandle
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: edgeMouseArea.containsMouse ? ShellMetrics.shelfSurfaceHeight : ShellMetrics.shelfItemSize
        height: MeoTheme.space4
        radius: MeoTheme.shapeFull

        color: MeoTheme.onSurfaceVariant
        opacity: edgeMouseArea.containsMouse ? 0.7 : 0.35
        visible: root.currentShelfState !== root.stateVisible

        Behavior on width { NumberAnimation { duration: MeoMotion.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate } }
        Behavior on opacity { NumberAnimation { duration: MeoMotion.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate } }
    }

    // Touch/Hover Edge Area at bottom of screen
    MouseArea {
        id: edgeMouseArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: MeoTheme.space8
        hoverEnabled: true

        onEntered: {
            if (root.currentShelfState === root.stateDodgeHidden || root.currentShelfState === root.stateFullscreenHidden) {
                root.currentShelfState = root.stateRevealed
            }
        }
    }

    // Root Material 3 content-sized tonal surface.  Like current Pixel
    // surfaces, it has no permanent outline: hierarchy comes from the dynamic
    // surface role while task items provide feedback only when interacted with.
    Rectangle {
        id: surfaceContainer

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ShellMetrics.shelfBottomMargin

        width: Math.min(root.width - 2 * MeoTheme.space8,
                        Math.max(72 * MeoTheme.globalScale,
                                 shelfContent.implicitWidth + MeoTheme.space24))
        height: ShellMetrics.shelfSurfaceHeight
        radius: height / 2

        color: MeoTheme.surfaceContainer
        border.width: 0

        transform: Translate {
            y: (root.currentShelfState === root.stateDodgeHidden || root.currentShelfState === root.stateFullscreenHidden) ? ShellMetrics.shelfPanelHeight : 0
            Behavior on y {
                NumberAnimation {
                    duration: root.currentShelfState === root.stateRevealed ? MeoMotion.shelfReveal : MeoMotion.shelfHide
                    easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                }
            }
        }

        opacity: (root.currentShelfState === root.stateDodgeHidden || root.currentShelfState === root.stateFullscreenHidden) ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: MeoMotion.shelfReveal; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
        }

        MouseArea {
            id: surfaceContainerMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        // Inner Content Layout
        RowLayout {
            id: shelfContent
            anchors.centerIn: parent
            spacing: MeoTheme.space2

            // 1. Launcher Button
            ShelfItem {
                id: launcherButton
                visible: root.showLauncherButton
                isLauncher: true
                title: MeoI18n.translator.i18n("Application Launcher")
                isActive: launcherPopup.visible

                onClicked: {
                    launcherPopup.visible = !launcherPopup.visible
                }
            }

            // Preserve a breathable launcher-to-task gap without turning it
            // into a permanent visual divider.
            Item {
                visible: root.showLauncherButton
                Layout.preferredWidth: visible ? MeoTheme.space8 : 0
                Layout.preferredHeight: MeoTheme.space24
                Layout.alignment: Qt.AlignVCenter
            }

            // 2. Tasks Model Repeater (Pinned + Running Apps merged)
            Repeater {
                id: tasksRepeater
                model: TaskManager.TasksModel {
                    id: tasksModel
                    filterByVirtualDesktop: root.filterTasksByVirtualDesktop
                    filterByActivity: false
                    filterByScreen: false
                    groupMode: TaskManager.TasksModel.GroupApplications
                    sortMode: TaskManager.TasksModel.SortAlpha
                }

                delegate: ShelfItem {
                    required property int index
                    readonly property var taskIndex: tasksModel.index(index, 0)
                    readonly property int revision: root.taskRevision

                    title: {
                        revision
                        return tasksModel.data(taskIndex, 0) || ""
                    }
                    iconSource: {
                        revision
                        return tasksModel.data(taskIndex, 1)
                    }
                    isActive: {
                        revision
                        return tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsActive) || false
                    }
                    isRunning: true
                    winCount: {
                        revision
                        return Math.max(1, tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.ChildCount) || 1)
                    }
                    isPinned: {
                        revision
                        return tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsLauncher) || false
                    }
                    showRunningIndicator: root.showRunningIndicators
                    showTooltip: root.showTooltips

                    onClicked: (mouse) => {
                        var modelIndex = tasksModel.index(index, 0)
                        if (winCount > 1 && isActive) {
                            // Multiple windows & currently active -> open window selector popup
                            windowSelectorMenu.targetIndex = index
                            windowSelectorMenu.open()
                        } else if (isActive) {
                            tasksModel.requestToggleMinimized(modelIndex)
                        } else {
                            tasksModel.requestActivate(modelIndex)
                        }
                    }

                    onRightClicked: (mouse) => {
                        taskContextMenu.targetIndex = index
                        taskContextMenu.open()
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
    }

    // Window Selector Menu for Multi-window grouped tasks
    MeoMenu {
        id: windowSelectorMenu
        property int targetIndex: -1
        model: {
            root.taskRevision
            if (targetIndex < 0)
                return []
            const taskIndex = tasksModel.index(targetIndex, 0)
            const children = tasksModel.data(taskIndex, TaskManager.TasksModel.ChildList) || []
            const entries = []
            for (let index = 0; index < children.length; ++index) {
                const child = children[index]
                entries.push({
                    "label": child.display || MeoI18n.translator.i18n("Window"),
                    "icon": "web_asset",
                    "action": function() { tasksModel.requestActivate(taskIndex) }
                })
            }
            return entries
        }
    }

    // Context Menu for Tasks (M3 Style without Plasma internal jargon)
    MeoMenu {
        id: taskContextMenu
        property int targetIndex: -1
        model: {
            root.taskRevision
            if (targetIndex < 0)
                return []
            const taskIndex = tasksModel.index(targetIndex, 0)
            const pinned = tasksModel.data(taskIndex, TaskManager.TasksModel.IsPinned) || false
            return [
                {
                    "label": MeoI18n.translator.i18n("Open new window"),
                    "icon": "add_box",
                    "action": function() { tasksModel.requestNewInstance(taskIndex) }
                },
                {
                    "label": pinned ? MeoI18n.translator.i18n("Unpin from Shelf") : MeoI18n.translator.i18n("Pin to Shelf"),
                    "icon": pinned ? "keep_off" : "keep",
                    "action": function() { tasksModel.requestToggleIsPinned(taskIndex) }
                },
                { "type": "separator" },
                {
                    "label": MeoI18n.translator.i18n("Close window"),
                    "icon": "close",
                    "action": function() { tasksModel.requestClose(taskIndex) }
                }
            ]
        }
    }

    // Launcher Popup Surface
    LauncherPopup {
        id: launcherPopup
        shellApplet: root
        defaultPage: root.launcherDefaultPage
        widthPreset: root.launcherWidth
        showFavoritesSection: root.launcherShowFavorites
        showRecentSection: root.launcherShowRecents
    }
}
