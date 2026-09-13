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
            type: "tonal"
            size: "s"
            toggle: true
            selected: NotificationManager.Server.inhibited
            icon.name: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications"
            selectedIcon: "do_not_disturb_on"
            enabled: NotificationManager.Server.valid
            Accessible.name: NotificationManager.Server.inhibited ? qsTr("Turn off Do Not Disturb") : qsTr("Turn on Do Not Disturb")
            Accessible.checked: NotificationManager.Server.inhibited
            onClicked: NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        }
        MeoButton {
            visible: root.closableCount > 0 || root.clearPending
            type: "text"
            size: "s"
            text: qsTr("Clear all")
            loading: root.clearPending
            enabled: !root.clearPending
            Accessible.name: qsTr("Clear %1 dismissible notifications").arg(root.closableCount)
            onClicked: root.clearRequested()
        }
        MeoIconButton { visible: root.showSettingsAction; type: "standard"; size: "s"; icon.name: "settings"; Accessible.name: qsTr("Notification settings"); onClicked: root.settingsRequested() }
    }

    MeoMotionSurface {
        visible: implicitHeight > 0 || opacity > 0
        enabled: NotificationManager.Server.inhibited
        opacity: NotificationManager.Server.inhibited ? 1 : 0
        Layout.fillWidth: true
        implicitHeight: NotificationManager.Server.inhibited
                        ? dndMessage.implicitHeight + 2 * MeoTheme.space8 : 0
        Layout.preferredHeight: implicitHeight
        color: MeoTheme.secondaryContainer
        radius: MeoTheme.shapeMedium
        elevation: 0
        clip: true
        Behavior on implicitHeight {
            NumberAnimation {
                duration: MeoTheme.reduceMotion ? 0 : (NotificationManager.Server.inhibited
                          ? MeoTheme.motionDurationDisclosureEnter
                          : MeoTheme.motionDurationDisclosureExit)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: NotificationManager.Server.inhibited ? MeoTheme.motionEasingEmphasizedDecelerate : MeoTheme.motionEasingEmphasizedAccelerate
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationPanelState
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MeoTheme.motionEasingStandard
            }
        }
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
