import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: 36 * MeoTheme.globalScale
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight
    Component.onCompleted: MeoShellTheme.sync()

    // Use this panel's output and the current activity/desktop. A fullscreen
    // window on another monitor must not blacken the desktop's top bar.
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: windows
        filterByScreen: true
        screenGeometry: root.screenGeometry
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    property int revision: 0
    readonly property bool covered: {
        revision
        for (let row = 0; row < windows.count; ++row) {
            const index = windows.index(row, 0)
            if (!windows.data(index, TaskManager.AbstractTasksModel.IsMinimized)
                    && (windows.data(index, TaskManager.AbstractTasksModel.IsFullScreen)
                        || windows.data(index, TaskManager.AbstractTasksModel.IsMaximized)))
                return true
        }
        return false
    }
    Connections {
        target: windows
        function onDataChanged() { root.revision++ }
        function onRowsInserted() { root.revision++ }
        function onRowsRemoved() { root.revision++ }
        function onModelReset() { root.revision++ }
    }
    // Leave the desktop visible through the entire panel; the window clear
    // color supplies the black surface when a window covers this output.
    Binding {
        target: Plasmoid.containment
        property: "backgroundHints"
        value: PlasmaCore.Types.NoBackground
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: root.Window.window
        property: "color"
        value: root.covered ? "black" : "transparent"
        restoreMode: Binding.RestoreBindingOrValue
    }
    compactRepresentation: MeoIconButton {
        type: "standard"
        size: "xs"
        contentItem: Kirigami.Icon { source: "meoarch-logo"; implicitWidth: 20 * MeoTheme.globalScale; implicitHeight: implicitWidth }
        Accessible.name: MeoI18n.translator.i18n("System menu")
        onClicked: root.expanded = !root.expanded
    }
    fullRepresentation: MeoCard {
        function close() { root.expanded = false }
        type: "filled"
        padding: MeoTheme.space16
        Layout.minimumWidth: 288 * MeoTheme.globalScale
        implicitWidth: 288 * MeoTheme.globalScale
        implicitHeight: menuContent.implicitHeight + 2 * padding
        contentItem: ColumnLayout {
        id: menuContent
        spacing: MeoTheme.space8
        MeoText { text: MeoI18n.translator.i18n("MeoArch"); typeRole: "title"; typeSize: "medium" }
        MeoButton {
            text: MeoI18n.translator.i18n("About this system")
            icon.name: "info"
            Layout.fillWidth: true
            onClicked: { if (Platform.openSystemAbout()) root.expanded = false }
        }
        MeoButton {
            text: MeoI18n.translator.i18n("Task manager")
            icon.name: "monitoring"
            Layout.fillWidth: true
            onClicked: { if (Platform.openTaskManager()) root.expanded = false }
        }
        MeoButton {
            text: MeoI18n.translator.i18n("Lock screen")
            icon.name: "lock"
            Layout.fillWidth: true
            onClicked: { Platform.lockScreen(); root.expanded = false }
        }
        MeoButton {
            id: power
            text: MeoI18n.translator.i18n("Power and session")
            icon.name: "power_settings_new"
            Layout.fillWidth: true
            onClicked: sessionMenu.openAt(power, 0, power.height)
        }
        MeoText { text: Platform.lastError; visible: text.length > 0; color: MeoTheme.error; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        SessionMenu { id: sessionMenu; closeTarget: root.fullRepresentationItem }
        }
    }
}
