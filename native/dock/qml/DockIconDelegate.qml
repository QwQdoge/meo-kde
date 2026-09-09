import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import MeoUI 1.0

Item {
    id: root

    required property int taskRow
    required property var tasksModel
    required property real pointerX

    signal launchRequested(string applicationId, string applicationName,
                           var applicationIcon)

    readonly property var taskIndex: tasksModel.index(taskRow, 0)
    readonly property string title: tasksModel.data(taskIndex, Qt.DisplayRole) || ""
    readonly property var iconSource: tasksModel.data(taskIndex, Qt.DecorationRole)
    readonly property string appId: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppId) || ""
    readonly property url launcherUrl: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.LauncherUrl) || ""
    readonly property bool isActive: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsActive) || false
    readonly property bool isWindow: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsWindow) || false
    readonly property bool isStartup: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsStartup) || false
    readonly property bool isLauncher: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsLauncher) || false
    readonly property bool hasLauncher: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.HasLauncher) || false
    readonly property bool isMinimized: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsMinimized) || false
    readonly property bool demandsAttention: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsDemandingAttention) || false
    readonly property bool canClose: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsClosable) || false
    readonly property bool canLaunchNew: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.CanLaunchNewInstance) || false
    readonly property int childCount: Math.max(1, tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.ChildCount) || 1)
    readonly property string iconMode: DockConfig.iconModeFor(appId, launcherUrl)
    readonly property real centerInWindow: mapToItem(null, width / 2, 0).x
    readonly property real pointerDistance: Math.abs(centerInWindow - pointerX)
    readonly property real desiredMagnification: pointerX < 0
                                                  ? 1.0
                                                  : 1.0 + 0.34 * Math.exp(
                                                        -Math.pow(pointerDistance / (72 * MeoTheme.globalScale), 2))
    property bool launchFeedbackActive: false

    MeoSpringValue {
        id: magnificationSpring
        value: 1
        targetValue: root.desiredMagnification
        spring: MeoMotion.fastSpatial
        enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
    }

    MeoSpringValue {
        id: pressSpring
        value: 1
        targetValue: primaryTap.pressed ? 0.92 : 1
        spring: MeoMotion.fastSpatial
        enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
    }

    Timer {
        id: localLaunchDeadline
        interval: 1800
        onTriggered: root.launchFeedbackActive = false
    }

    onIsWindowChanged: {
        if (isWindow) {
            launchFeedbackActive = false
            localLaunchDeadline.stop()
        }
    }

    width: 56 * MeoTheme.globalScale
    height: width
    z: Math.round(magnificationSpring.value * 100)
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height
        xScale: magnificationSpring.value * pressSpring.value
        yScale: magnificationSpring.value * pressSpring.value
    }

    Rectangle {
        id: iconContainer
        anchors.centerIn: parent
        width: 50 * MeoTheme.globalScale
        height: width
        radius: width / 2
        // Application artwork already owns its selected Pixel/circle/squircle
        // silhouette.  Keep the Dock hit/state layer transparent so generated
        // icons never get a second opaque plate behind them.
        color: root.demandsAttention
               ? Qt.rgba(MeoTheme.tertiaryContainer.r,
                         MeoTheme.tertiaryContainer.g,
                         MeoTheme.tertiaryContainer.b, 0.32)
               : root.isActive
                 ? Qt.rgba(MeoTheme.primaryContainer.r,
                           MeoTheme.primaryContainer.g,
                           MeoTheme.primaryContainer.b, 0.22)
                 : "transparent"
        border.width: 0

        MeoStateLayer {
            anchors.fill: parent
            hovered: hover.hovered
            pressed: primaryTap.pressed
            shape: "circle"
            color: MeoTheme.onSurface
            z: 2
        }

        Behavior on color {
            enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
            ColorAnimation { duration: MeoMotion.stateChange; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
        }

        Kirigami.Icon {
            id: appIcon
            anchors.centerIn: parent
            width: 44 * MeoTheme.globalScale
            height: width
            source: root.iconSource
            active: root.isActive
            z: 1
        }

        // Pixel monochrome mode is a real app-mark treatment, not only a
        // different circle behind the unchanged full-colour icon.
        MultiEffect {
            anchors.fill: appIcon
            source: appIcon
            visible: root.iconMode === "mono"
            colorization: 1.0
            colorizationColor: MeoTheme.onSurface
            z: 1
        }

        MeoLoadingIndicator {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20 * MeoTheme.globalScale
            height: width
            variant: "contained"
            running: visible
            visible: root.isStartup || root.launchFeedbackActive
            z: 4
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 3 * MeoTheme.globalScale
            width: root.isActive ? 22 * MeoTheme.globalScale : 6 * MeoTheme.globalScale
            height: 3 * MeoTheme.globalScale
            radius: height / 2
            visible: root.hasLauncher || !root.isLauncher
            color: root.demandsAttention ? MeoTheme.tertiary : MeoTheme.primary
            opacity: root.isMinimized ? 0.55 : 1.0

            Behavior on width {
                enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1 * MeoTheme.globalScale
            width: 16 * MeoTheme.globalScale
            height: width
            radius: width / 2
            visible: root.childCount > 1
            color: MeoTheme.primary

            MeoText {
                anchors.centerIn: parent
                text: String(root.childCount)
                typeRole: "label"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.onPrimary
            }
        }
    }

    MeoTooltip {
        visible: hover.hovered && !contextMenu.visible
        text: root.title
        delay: MeoTheme.motionDurationLong1
    }

    HoverHandler { id: hover }

    TapHandler {
        id: primaryTap
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (root.isLauncher && !root.isWindow) {
                root.launchFeedbackActive = true
                localLaunchDeadline.restart()
                root.launchRequested(root.appId || root.launcherUrl.toString(),
                                     root.title, root.iconSource)
            }
            if (root.isActive && !root.isLauncher)
                root.tasksModel.requestToggleMinimized(root.taskIndex)
            else
                root.tasksModel.requestActivate(root.taskIndex)
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.tasksModel.requestNewInstance(root.taskIndex)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: contextMenu.open()
    }

    MeoMenu {
        id: contextMenu
        model: [
            {
                "label": qsTr("Open new window"),
                "icon": "add_box",
                "enabled": root.canLaunchNew,
                "action": function() { root.tasksModel.requestNewInstance(root.taskIndex) }
            },
            {
                "label": root.hasLauncher || root.isLauncher ? qsTr("Unpin from Dock") : qsTr("Pin to Dock"),
                "icon": root.hasLauncher || root.isLauncher ? "keep_off" : "keep",
                "action": function() {
                    if (root.hasLauncher || root.isLauncher)
                        root.tasksModel.requestRemoveLauncher(root.launcherUrl)
                    else
                        root.tasksModel.requestAddLauncher(root.launcherUrl)
                }
            },
            { "type": "separator" },
            {
                "label": qsTr("Close"),
                "icon": "close",
                "enabled": root.canClose,
                "action": function() { root.tasksModel.requestClose(root.taskIndex) }
            }
        ]
    }
}
