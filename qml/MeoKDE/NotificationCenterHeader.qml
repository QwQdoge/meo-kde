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
    property int closableCount: 0
    property int unreadCount: 0
    property int activeJobsCount: 0
    property int liveNotificationCount: 0
    property int historyNotificationCount: 0
    property bool clearPending: false
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
                text: MeoI18n.translator.i18n("Notifications")
                typeRole: "title"; typeSize: "small"; emphasized: true; color: MeoTheme.contentOnSurface
            }
            MeoText {
                visible: root.activeJobsCount > 0
                text: root.activeJobsCount === 1 ? MeoI18n.translator.i18n("1 background task") : MeoI18n.translator.i18n("%1 background tasks", root.activeJobsCount)
                typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
            }
            MeoText {
                visible: root.activeJobsCount === 0 && (root.liveNotificationCount > 0 || root.historyNotificationCount > 0)
                text: root.liveNotificationCount > 0 && root.historyNotificationCount > 0
                      ? MeoI18n.translator.i18n("%1 live · %2 in history", root.liveNotificationCount, root.historyNotificationCount)
                      : (root.liveNotificationCount > 0 ? MeoI18n.translator.i18n("%1 live notification", root.liveNotificationCount) : MeoI18n.translator.i18n("%1 in history", root.historyNotificationCount))
                typeRole: "label"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant
            }
        }
        Item { visible: !root.showTitle; Layout.fillWidth: true }
        MeoIconButton {
            type: "tonal"
            size: "s"
            toggle: true
            selected: NotificationManager.Server.inhibited
            icon.name: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications"
            selectedIcon: "do_not_disturb_on"
            enabled: NotificationManager.Server.valid
            Accessible.name: NotificationManager.Server.inhibited ? MeoI18n.translator.i18n("Turn off Do Not Disturb") : MeoI18n.translator.i18n("Turn on Do Not Disturb")
            Accessible.checked: NotificationManager.Server.inhibited
            onClicked: NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        }
        MeoButton {
            visible: root.closableCount > 0 || root.clearPending
            type: "text"
            size: "s"
            text: MeoI18n.translator.i18n("Clear all")
            loading: root.clearPending
            enabled: !root.clearPending
            Accessible.name: MeoI18n.translator.i18n("Clear %1 dismissible notifications", root.closableCount)
            onClicked: root.clearRequested()
        }
        MeoIconButton { visible: root.showSettingsAction; type: "standard"; size: "s"; icon.name: "settings"; Accessible.name: MeoI18n.translator.i18n("Notification settings"); onClicked: root.settingsRequested() }
    }

}
