import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    implicitHeight: ShellMetrics.topBarHeight
    Layout.fillWidth: true

    // Active Window Tracking from TaskManager
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
    }

    property string activeAppName: ""
    property string activeAppIcon: ""
    property bool isMaximized: false
    property bool isFullscreen: false

    Component.onCompleted: MeoShellTheme.sync()

    function updateActiveWindowInfo() {
        for (var i = 0; i < tasksModel.rowCount(); i++) {
            var idx = tasksModel.index(i, 0)
            var isActive = tasksModel.data(idx, TaskManager.TasksModel.IsActive)
            if (isActive) {
                activeAppName = tasksModel.data(idx, TaskManager.TasksModel.Display) || ""
                var ic = tasksModel.data(idx, TaskManager.TasksModel.Icon)
                activeAppIcon = typeof ic === "string" ? ic : ""
                isMaximized = tasksModel.data(idx, TaskManager.TasksModel.IsMaximized) || false
                isFullscreen = tasksModel.data(idx, TaskManager.TasksModel.IsFullScreen) || false
                return
            }
        }
        activeAppName = ""
        activeAppIcon = ""
        isMaximized = false
        isFullscreen = false
    }

    Connections {
        target: tasksModel
        function onDataChanged() { updateActiveWindowInfo() }
        function onRowsInserted() { updateActiveWindowInfo() }
        function onRowsRemoved() { updateActiveWindowInfo() }
    }

    visible: !isFullscreen

    // Background Surface Container for Top Bar
    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: root.isMaximized ? MeoTheme.surfaceContainer : MeoTheme.surfaceContainerLow
        opacity: root.isMaximized ? 0.92 : (MeoTheme.isDarkMode ? 0.76 : 0.82)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: ShellMetrics.panelOutlineWidth
            color: MeoTheme.outlineVariant
            opacity: 0.72
        }

        Behavior on opacity {
            NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: MeoTheme.space16
        anchors.rightMargin: MeoTheme.space16
        spacing: MeoTheme.space12

        // Active Application Identity Area (Left)
        RowLayout {
            spacing: MeoTheme.space8
            visible: root.activeAppName !== ""

            Kirigami.Icon {
                source: root.activeAppIcon !== "" ? root.activeAppIcon : "application-x-executable"
                implicitWidth: MeoTheme.iconSizeS
                implicitHeight: MeoTheme.iconSizeS
            }

            Text {
                text: root.activeAppName
                font.family: MeoTheme.fontFamily
                font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                font.weight: Font.Medium
                color: MeoTheme.onSurface
                elide: Text.ElideRight
                Layout.maximumWidth: 240
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // Clock & Quick Settings Target Area (Right)
        Rectangle {
            id: clockBtn
            implicitWidth: clockText.implicitWidth + 20
            implicitHeight: 32 * MeoTheme.globalScale
            radius: MeoTheme.shapeFull
            color: clockMouse.containsMouse ? MeoTheme.surfaceContainerHighest : "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: MeoTheme.space4 + MeoTheme.space2

                Text {
                    id: clockText
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    font.family: MeoTheme.fontFamily
                    font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                    font.weight: Font.Medium
                    color: MeoTheme.onSurface
                }
            }

            Timer {
                interval: 10000
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm")
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: quickSettingsPopup.visible = !quickSettingsPopup.visible
            }
        }
    }

    // Quick Settings Popup Surface
    QuickSettingsPopup {
        id: quickSettingsPopup
    }
}
