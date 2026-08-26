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

    readonly property real localTextScale: Math.max(0.75, Math.min(1.5,
        Number(Plasmoid.configuration.textScalePercent) / 100.0))
    readonly property real compactWidth: Math.ceil(compactRepresentationItem
                                                    ? compactRepresentationItem.implicitWidth
                                                    : 96 * MeoTheme.globalScale)
    readonly property real compactHeight: ShellMetrics.topBarHeight

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: qsTr("Meo Time and Notifications")
    toolTipMainText: qsTr("Meo Time and Notifications")
    toolTipSubText: notificationModel.unreadNotificationsCount > 0
                    ? qsTr("%1 unread notifications").arg(notificationModel.unreadNotificationsCount)
                    : qsTr("Calendar and notifications")
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    // Let Plasma recalculate this compact trigger from the live content.  A
    // retained minimum width is what made the clock allocation drift after
    // panel reloads.
    Layout.minimumWidth: 0
    Layout.preferredWidth: compactWidth
    Layout.maximumWidth: compactWidth
    Layout.minimumHeight: compactHeight
    Layout.preferredHeight: compactHeight
    Layout.maximumHeight: compactHeight

    Component.onCompleted: MeoShellTheme.sync()
    onExpandedChanged: function() {
        if (root.expanded)
            notificationModel.lastRead = clock.dateTime
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
        // This delegate renders every advertised action and job control. Keep
        // the model ungrouped so no child notification is hidden behind an
        // aggregate row with different role semantics.
        groupMode: NotificationManager.Notifications.GroupDisabled
        window: root.Window.window
    }

    compactRepresentation: TimeNotificationButton {
        currentDateTime: clock.dateTime
        unreadCount: notificationModel.unreadNotificationsCount
        activeJobsCount: notificationModel.activeJobsCount
        jobsPercentage: notificationModel.jobsPercentage
        inhibited: NotificationManager.Server.inhibited
        textScale: root.localTextScale
        showDate: Plasmoid.configuration.showDate
        showNotifications: Plasmoid.configuration.showNotifications
        use24HourClock: Plasmoid.configuration.use24HourClock
        onStatusCenterRequested: root.expanded = !root.expanded
    }

    fullRepresentation: TimeNotificationCenter {
        notifications: notificationModel
        currentDateTime: clock.dateTime
        use24HourClock: Plasmoid.configuration.use24HourClock
    }
}
