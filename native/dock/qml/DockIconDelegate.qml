import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import MeoUI 1.0

Item {
    id: root

    required property int taskRow
    required property var tasksModel
    required property real pointerX

    readonly property var taskIndex: tasksModel.index(taskRow, 0)
    readonly property string title: tasksModel.data(taskIndex, Qt.DisplayRole) || ""
    readonly property var iconSource: tasksModel.data(taskIndex, Qt.DecorationRole)
    readonly property string appId: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.AppId) || ""
    readonly property url launcherUrl: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.LauncherUrl) || ""
    readonly property bool isActive: tasksModel.data(taskIndex, TaskManager.AbstractTasksModel.IsActive) || false
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
    property real magnification: pointerX < 0
                                 ? 1.0
                                 : 1.0 + 0.34 * Math.exp(
                                       -Math.pow(pointerDistance / (72 * MeoTheme.globalScale), 2))

    width: 56 * MeoTheme.globalScale
    height: width
    z: Math.round(magnification * 100)
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height
        xScale: root.magnification
        yScale: root.magnification
    }

    Behavior on magnification {
        enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
        NumberAnimation { duration: MeoMotion.hover; easing.type: Easing.OutCubic }
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

        Behavior on color {
            enabled: !MeoTheme.reduceMotion && !DockConfig.reduceMotion
            ColorAnimation { duration: MeoMotion.stateChange }
        }

        Kirigami.Icon {
            id: appIcon
            anchors.centerIn: parent
            width: 44 * MeoTheme.globalScale
            height: width
            source: root.iconSource
            active: root.isActive
        }

        // Pixel monochrome mode is a real app-mark treatment, not only a
        // different circle behind the unchanged full-colour icon.
        MultiEffect {
            anchors.fill: appIcon
            source: appIcon
            visible: root.iconMode === "mono"
            colorization: 1.0
            colorizationColor: MeoTheme.onSurface
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
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
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

    QQC2.ToolTip.visible: hover.hovered && !contextMenu.visible
    QQC2.ToolTip.text: root.title
    QQC2.ToolTip.delay: 450

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
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
        onTapped: contextMenu.popup()
    }

    QQC2.Menu {
        id: contextMenu

        QQC2.MenuItem {
            text: qsTr("Open new window")
            enabled: root.canLaunchNew
            onTriggered: root.tasksModel.requestNewInstance(root.taskIndex)
        }
        QQC2.MenuItem {
            text: root.hasLauncher || root.isLauncher ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
            onTriggered: {
                if (root.hasLauncher || root.isLauncher)
                    root.tasksModel.requestRemoveLauncher(root.launcherUrl)
                else
                    root.tasksModel.requestAddLauncher(root.launcherUrl)
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: qsTr("Close")
            enabled: root.canClose
            onTriggered: root.tasksModel.requestClose(root.taskIndex)
        }
    }
}
