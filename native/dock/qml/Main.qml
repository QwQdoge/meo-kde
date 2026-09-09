import QtQuick
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
    property bool launchPending: false
    property string pendingApplicationId: ""
    property string pendingApplicationName: ""
    property var pendingApplicationIcon
    property var pendingGeometry: ({})
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

    function normalizedApplicationId(value) {
        let result = String(value || "")
        if (result.startsWith("applications:"))
            result = result.substring(13)
        const slash = result.lastIndexOf("/")
        if (slash >= 0)
            result = result.substring(slash + 1)
        if (result.endsWith(".desktop"))
            result = result.substring(0, result.length - 8)
        return result.toLowerCase()
    }

    function beginLaunch(applicationId, applicationName, applicationIcon) {
        pendingApplicationId = normalizedApplicationId(applicationId)
        pendingApplicationName = applicationName
        pendingApplicationIcon = applicationIcon
        pendingGeometry = DockConfig.launchGeometryFor(pendingApplicationId)
        launchPending = true
        launchSurfaceDelay.restart()
        DockConfig.beginLaunchBoost(pendingApplicationId)
    }

    function finishLaunch() {
        if (!launchPending)
            return
        launchPending = false
        launchSurfaceDelay.stop()
        launchSurface.dismiss()
        DockConfig.endLaunchBoost()
    }

    function scanTaskState() {
        for (let row = 0; row < tasksModel.count; ++row) {
            const index = tasksModel.index(row, 0)
            const isWindow = tasksModel.data(index, TaskManager.AbstractTasksModel.IsWindow) || false
            const appId = normalizedApplicationId(
                        tasksModel.data(index, TaskManager.AbstractTasksModel.AppId))
            if (isWindow && tasksModel.data(index, TaskManager.AbstractTasksModel.IsActive)) {
                const pid = Number(tasksModel.data(index, TaskManager.AbstractTasksModel.AppPid) || 0)
                if (pid > 0)
                    DockConfig.setForegroundProcess(pid)
                const geometry = tasksModel.data(index, TaskManager.AbstractTasksModel.Geometry)
                if (geometry && appId.length > 0)
                    DockConfig.rememberLaunchGeometry(appId, geometry)
            }
            if (launchPending && isWindow && appId === pendingApplicationId) {
                finishLaunch()
            }
        }
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
        function refresh() { root.taskRevision++; Qt.callLater(root.scanTaskState) }
        function onDataChanged() { refresh() }
        function onModelReset() { refresh() }
        function onRowsInserted() { refresh() }
        function onRowsRemoved() { refresh() }
    }

    Timer {
        id: launchSurfaceDelay
        // Fast launches get only the immediate icon/ripple response. The
        // larger surface is reserved for work that is still pending.
        interval: 220
        onTriggered: {
            if (root.launchPending) {
                launchSurface.showFor(root.pendingApplicationId,
                                      root.pendingApplicationName,
                                      root.pendingApplicationIcon,
                                      root.pendingGeometry)
            }
        }
    }

    LaunchSurfaceWindow {
        id: launchSurface
        onHidden: {
            root.launchPending = false
            root.pendingApplicationId = ""
            root.pendingApplicationName = ""
            root.pendingApplicationIcon = undefined
            root.pendingGeometry = ({})
            DockConfig.endLaunchBoost()
        }
    }

    ListModel {
        id: previewTasks

        ListElement { title: "Chrome"; iconName: "google-chrome"; mode: "original"; active: true }
        ListElement { title: "Files"; iconName: "system-file-manager"; mode: "tonal"; active: false }
        ListElement { title: "Terminal"; iconName: "utilities-terminal"; mode: "mono"; active: false }
        ListElement { title: "Settings"; iconName: "meoarch-logo"; mode: "tonal"; active: false }
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

                MeoSpringValue {
                    id: launcherPressSpring
                    value: 1
                    targetValue: launcherTap.pressed ? 0.92 : 1
                    spring: MeoMotion.fastSpatial
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 50 * MeoTheme.globalScale
                    height: width
                    radius: width / 2
                    scale: launcherPressSpring.value
                    color: launcherHover.hovered
                           ? MeoTheme.secondaryContainer
                           : MeoTheme.surfaceContainerHigh
                    border.width: MeoTheme.strokeWidthThin
                    border.color: MeoTheme.outlineVariant

                    Behavior on color {
                        ColorAnimation {
                            duration: MeoTheme.motionDurationEffectDefault
                            easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard
                        }
                    }

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
                TapHandler {
                    id: launcherTap
                    onTapped: DockConfig.activateLauncherMenu()
                }
                MeoTooltip {
                    visible: launcherHover.hovered
                    text: qsTr("Applications")
                    delay: MeoTheme.motionDurationLong1
                }
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
                            onLaunchRequested: (applicationId, applicationName, applicationIcon) =>
                                               root.beginLaunch(applicationId,
                                                                applicationName,
                                                                applicationIcon)
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
