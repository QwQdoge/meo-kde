import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: root

    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    width: Math.max(116 * MeoTheme.globalScale,
                    dockContent.implicitWidth + 28 * MeoTheme.globalScale)
    height: 108 * MeoTheme.globalScale
    title: qsTr("Meo Dock")

    property real pointerX: -1
    property int taskRevision: 0
    property bool launchersInitialized: false
    readonly property var unifiedTasksModel: tasksModel

    Component.onCompleted: {
        MeoShellTheme.sync()
        updateBlurRegion()
    }

    function updateBlurRegion() {
        DockWindowController.updateSurfaceRegion(
            dockSurface.x, dockSurface.y, dockSurface.width,
            dockSurface.height, dockSurface.radius)
    }

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        Component.onCompleted: {
            launcherList = DockConfig.launcherList
            root.launchersInitialized = true
        }
        onLauncherListChanged: {
            if (root.launchersInitialized)
                DockConfig.launcherList = launcherList
        }
    }

    Connections {
        target: tasksModel
        function onDataChanged() { root.taskRevision++ }
        function onModelReset() { root.taskRevision++ }
        function onRowsInserted() { root.taskRevision++ }
        function onRowsRemoved() { root.taskRevision++ }
    }

    ListModel {
        id: previewTasks

        ListElement { title: "Chrome"; iconName: "google-chrome"; mode: "original"; active: true }
        ListElement { title: "Files"; iconName: "system-file-manager"; mode: "tonal"; active: false }
        ListElement { title: "Terminal"; iconName: "utilities-terminal"; mode: "mono"; active: false }
        ListElement { title: "Settings"; iconName: "systemsettings"; mode: "tonal"; active: false }
        ListElement { title: "Steam"; iconName: "steam"; mode: "original"; active: false }
    }

    Connections {
        target: DockConfig
        function onIconOverridesChanged() { root.taskRevision++ }
        function onLauncherListChanged() {
            if (tasksModel.launcherList.toString() !== DockConfig.launcherList.toString())
                tasksModel.launcherList = DockConfig.launcherList
        }
    }

    // One continuous pointer surface covers icons and every gap. TapHandlers
    // in the delegates remain responsible for buttons and context actions.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => root.pointerX = mouse.x
        onExited: root.pointerX = -1
    }

    Rectangle {
        id: dockSurface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.width
        height: 76 * MeoTheme.globalScale
        radius: 24 * MeoTheme.globalScale
        color: Qt.rgba(MeoTheme.surfaceContainer.r,
                       MeoTheme.surfaceContainer.g,
                       MeoTheme.surfaceContainer.b,
                       MeoTheme.transparencyEnabled ? 0.76 : 1.0)
        border.width: MeoTheme.strokeWidthThin
        border.color: MeoTheme.outlineVariant

        onXChanged: root.updateBlurRegion()
        onYChanged: root.updateBlurRegion()
        onWidthChanged: root.updateBlurRegion()
        onHeightChanged: root.updateBlurRegion()
        onRadiusChanged: root.updateBlurRegion()

        Row {
            id: dockContent
            anchors.centerIn: parent
            spacing: 4 * MeoTheme.globalScale

            Item {
                width: 56 * MeoTheme.globalScale
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: 50 * MeoTheme.globalScale
                    height: width
                    radius: width / 2
                    color: launcherHover.hovered
                           ? MeoTheme.secondaryContainer
                           : MeoTheme.surfaceContainerHigh
                    border.width: MeoTheme.strokeWidthThin
                    border.color: MeoTheme.outlineVariant

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 30 * MeoTheme.globalScale
                        height: width
                        source: "view-app-grid-symbolic"
                        color: launcherHover.hovered
                               ? MeoTheme.onSecondaryContainer
                               : MeoTheme.onSurfaceVariant
                    }
                }

                HoverHandler { id: launcherHover }
                TapHandler { onTapped: DockConfig.activateLauncherMenu() }
                QQC2.ToolTip.visible: launcherHover.hovered
                QQC2.ToolTip.text: qsTr("Applications")
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: MeoTheme.strokeWidthThin
                height: 30 * MeoTheme.globalScale
                color: MeoTheme.outlineVariant
            }

            Repeater {
                model: DockPreviewMode ? previewTasks : tasksModel

                delegate: Loader {
                    required property int index
                    required property var model
                    width: 56 * MeoTheme.globalScale
                    height: width
                    sourceComponent: DockPreviewMode ? previewDelegate : taskDelegate

                    Component {
                        id: taskDelegate

                        DockIconDelegate {
                            taskRow: index
                            tasksModel: root.unifiedTasksModel
                            pointerX: root.pointerX
                        }
                    }

                    Component {
                        id: previewDelegate

                        DockPreviewIcon {
                            title: model.title
                            iconSource: model.iconName
                            iconMode: model.mode
                            isActive: model.active
                        }
                    }
                }
            }
        }
    }
}
