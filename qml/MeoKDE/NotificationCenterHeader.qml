import QtQuick
import QtQuick.Layouts
import org.kde.notificationmanager as NotificationManager
import MeoUI 1.0

// Header and DND disclosure for the real NotificationManager model. Actions
// are surfaced as signals so the view keeps ownership of model mutation.
ColumnLayout {
    id: root

    property bool showTitle: true
    property bool showSettingsAction: true
    property int notificationCount: 0
    property int unreadCount: 0
    property int activeJobsCount: 0
    property int liveNotificationCount: 0
    property int historyNotificationCount: 0
    signal clearRequested()
    signal settingsRequested()

    Layout.fillWidth: true
    spacing: MeoTheme.space8

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40 * MeoTheme.globalScale
        spacing: MeoTheme.space8

        ColumnLayout {
            visible: root.showTitle
            Layout.fillWidth: true
            spacing: 0
            MeoText {
                text: root.unreadCount > 0
                      ? qsTr("Notifications · %1 unread").arg(root.unreadCount)
                      : qsTr("Notifications")
                typeRole: "title"; typeSize: "medium"; emphasized: true; color: MeoTheme.onSurface
            }
            MeoText {
                visible: root.activeJobsCount > 0
                text: root.activeJobsCount === 1 ? qsTr("1 background task") : qsTr("%1 background tasks").arg(root.activeJobsCount)
                typeRole: "label"; typeSize: "small"; color: MeoTheme.onSurfaceVariant
            }
            MeoText {
                visible: root.activeJobsCount === 0 && (root.liveNotificationCount > 0 || root.historyNotificationCount > 0)
                text: root.liveNotificationCount > 0 && root.historyNotificationCount > 0
                      ? qsTr("%1 live · %2 in history").arg(root.liveNotificationCount).arg(root.historyNotificationCount)
                      : (root.liveNotificationCount > 0 ? qsTr("%1 live notification").arg(root.liveNotificationCount) : qsTr("%1 in history").arg(root.historyNotificationCount))
                typeRole: "label"; typeSize: "small"; color: MeoTheme.onSurfaceVariant
            }
        }
        Item { visible: !root.showTitle; Layout.fillWidth: true }
        MeoIconButton {
            type: NotificationManager.Server.inhibited ? "filled" : "tonal"
            size: "s"
            icon.name: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications"
            enabled: NotificationManager.Server.valid
            Accessible.name: NotificationManager.Server.inhibited ? qsTr("Turn off Do Not Disturb") : qsTr("Turn on Do Not Disturb")
            Accessible.checked: NotificationManager.Server.inhibited
            onClicked: NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        }
        MeoButton { visible: root.notificationCount > 0; type: "text"; size: "s"; text: qsTr("Clear all"); onClicked: root.clearRequested() }
        MeoIconButton { visible: root.showSettingsAction; type: "standard"; size: "s"; icon.name: "settings"; Accessible.name: qsTr("Notification settings"); onClicked: root.settingsRequested() }
    }

    MeoMotionSurface {
        visible: NotificationManager.Server.inhibited
        Layout.fillWidth: true
        Layout.preferredHeight: dndMessage.implicitHeight + 2 * MeoTheme.space8
        color: MeoTheme.secondaryContainer
        radius: MeoTheme.shapeMedium
        elevation: 0
        RowLayout {
            id: dndMessage
            anchors.fill: parent
            anchors.margins: MeoTheme.space8
            spacing: MeoTheme.space8
            MeoIcon { icon: "do_not_disturb_on"; size: 20; color: MeoTheme.onSecondaryContainer; Accessible.ignored: true }
            MeoText { Layout.fillWidth: true; text: qsTr("Do Not Disturb is on. New notifications are collected quietly."); typeRole: "label"; typeSize: "small"; wrapMode: Text.Wrap; color: MeoTheme.onSecondaryContainer }
        }
    }
}
