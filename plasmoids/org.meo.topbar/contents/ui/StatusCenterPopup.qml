import QtQuick
import QtQuick.Controls as QQC2
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.clock as PlasmaClock
import MeoUI 1.0
import MeoKDE 1.0

QQC2.Popup {
    id: statusCenter

    property var notificationWindow: null
    readonly property int unreadCount: notificationModel.unreadNotificationsCount

    y: ShellMetrics.topBarHeight + ShellMetrics.popupGap
    x: parent.width - width - ShellMetrics.screenMargin
    width: Math.min(ShellMetrics.statusCenterWidth,
                    Screen.width - 2 * ShellMetrics.screenMargin)
    height: Math.min(ShellMetrics.statusCenterHeight,
                     Screen.height - ShellMetrics.topBarHeight - 3 * ShellMetrics.screenMargin)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape
    transformOrigin: Item.TopRight

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1; to: 0.985; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
    }

    PlasmaClock.Clock {
        id: clock
        trackSeconds: true
    }

    NotificationManager.Notifications {
        id: notificationModel
        limit: 50
        showNotifications: true
        showJobs: true
        showExpired: true
        showDismissed: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        window: statusCenter.notificationWindow
    }

    onOpened: notificationModel.lastRead = clock.dateTime
    background: Item {}

    contentItem: MeoStatusCenter {
        width: statusCenter.availableWidth
        height: statusCenter.availableHeight
        currentDateTime: clock.dateTime
        timeText: Qt.formatTime(clock.dateTime, "hh:mm")
        dateText: Qt.formatDate(clock.dateTime, Qt.DefaultLocaleLongDate)
        unreadCount: notificationModel.unreadNotificationsCount

        notificationContent: Component {
            NotificationCenterView {
                notifications: notificationModel
                currentDateTime: clock.dateTime
                showTitle: false
                onSettingsRequested: Qt.openUrlExternally("systemsettings:kcm_notifications")
            }
        }
    }
}
