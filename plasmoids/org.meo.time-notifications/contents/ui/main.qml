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
    onExpandedChanged: if (root.expanded) { root.expanded = false; popup.visible = true }
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
        active: popup.visible
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
        onStatusCenterRequested: popup.visible = !popup.visible
    }
    fullRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }
    PlasmaCore.Dialog {
        id: popup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.TopEdge
        visualParent: root.compactRepresentationItem
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (visible) {
            notifications.lastRead = clock.dateTime
            toast.visible = false
            Qt.callLater(function() { popup.requestActivate(); popup.mainItem.forceActiveFocus() })
        }
        mainItem: StatusCenterView {
        Keys.onEscapePressed: popup.visible = false
        revealActive: popup.visible
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
    NotificationManager.Notifications {
        id: toastModel
        limit: 1
        showNotifications: true
        showJobs: false
        showExpired: false
        showDismissed: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        property bool ready: false
        Component.onCompleted: ready = true
        onCountChanged: root.queueToast()
    }
    function queueToast() {
        // The proxy count signal can precede insertion of its final rows.
        // Present only after bindings have observed the complete model.
        Qt.callLater(function() {
            if (toastModel.ready && toastModel.count > 0 && !NotificationManager.Server.inhibited && !popup.visible) {
                toast.visible = true
                toastExpiry.restart()
            }
        })
    }
    Connections {
        target: toastModel
        function onRowsInserted() { root.queueToast() }
    }
    Timer {
        id: toastExpiry
        interval: 7000
        onTriggered: {
            toast.visible = false
            if (toastModel.count > 0) toastModel.expire(toastModel.index(0, 0))
        }
    }
    PlasmaCore.Dialog {
        id: toast
        type: PlasmaCore.Dialog.Notification
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        location: PlasmaCore.Types.Floating
        x: root.screenGeometry.x + root.screenGeometry.width - width - ShellMetrics.screenMargin
        y: root.screenGeometry.y + ShellMetrics.topBarHeight + ShellMetrics.popupGap
        mainItem: NotificationCenterView {
            implicitWidth: 360 * MeoTheme.globalScale
            implicitHeight: Math.max(180 * MeoTheme.globalScale, Math.min(320 * MeoTheme.globalScale, renderedHeight + MeoTheme.space24))
            notifications: toastModel
            currentDateTime: clock.dateTime
            showTitle: false
            showEmptyState: false
            showHeader: false
            showSettingsAction: false
            showJobs: false
            showHistory: false
        }
    }

}
