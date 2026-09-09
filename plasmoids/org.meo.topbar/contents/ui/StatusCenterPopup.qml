import QtQuick
import QtQuick.Controls as QQC2
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.clock as PlasmaClock
import MeoUI 1.0
import MeoKDE 1.0

MeoMotionPopup {
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
    presentation: MeoMotionPopup.Dialog
    transformOrigin: Item.TopRight

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
                onSettingsRequested: {
                    Qt.openUrlExternally("applications:org.meo.settings.notifications.desktop")
                }
            }
        }
    }
}
