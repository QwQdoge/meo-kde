pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    readonly property bool use24Hour: Plasmoid.configuration.clockFormat === "24h"
                                      || (Plasmoid.configuration.clockFormat === "system"
                                          && Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") < 0)

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Meo Time and Notifications")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: compactRepresentation
    onExpandedChanged: if (root.expanded)
                           notifications.lastRead = clock.dateTime
    Layout.minimumWidth: compactRepresentationItem
                         ? compactRepresentationItem.implicitWidth
                         : 80 * MeoTheme.globalScale
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

    PlasmaClock.Clock {
        id: clock
        trackSeconds: Plasmoid.configuration.showSeconds
    }

    NotificationManager.Notifications {
        id: notifications
        limit: 50
        showNotifications: true
        showJobs: Plasmoid.configuration.showJobs
        showExpired: Plasmoid.configuration.showNotificationHistory
        showDismissed: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        window: root.Window.window
    }
    compactRepresentation: TimeNotificationButton {
        active: root.expanded
        currentDateTime: clock.dateTime
        unreadCount: notifications.unreadNotificationsCount
        activeJobsCount: notifications.activeJobsCount
        jobsPercentage: notifications.jobsPercentage
        inhibited: NotificationManager.Server.inhibited
        showDate: Plasmoid.configuration.showDate
        showSeconds: Plasmoid.configuration.showSeconds
        showNotifications: true
        showUnreadBadge: Plasmoid.configuration.showUnreadBadge
        use24HourClock: root.use24Hour
        onStatusCenterRequested: root.expanded = !root.expanded
    }
    fullRepresentation: StatusCenterView {
        notifications: notifications
        currentDateTime: clock.dateTime
        centerMode: "timeNotifications"
        clockFormat: Plasmoid.configuration.clockFormat
        showSeconds: Plasmoid.configuration.showSeconds
        showDate: Plasmoid.configuration.showDate
        showJobs: Plasmoid.configuration.showJobs
        showHistory: Plasmoid.configuration.showNotificationHistory
        notificationView: Plasmoid.configuration.notificationView
        notificationPreview: Plasmoid.configuration.notificationPreview
        density: Plasmoid.configuration.density
    }
}
