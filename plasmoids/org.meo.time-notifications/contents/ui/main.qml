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
    onExpandedChanged: if (root.expanded) { root.expanded = false; root.openCenter() }
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
        // Plasma's grouping proxy stacks one application's notifications;
        // a collapsed group shows its newest one, and the rest fan out below.
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 1
        expandUnread: false
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
        onStatusCenterRequested: popup.visible ? root.closeCenter() : root.openCenter()
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
            Qt.callLater(function() { popup.requestActivate(); centerView.forceActiveFocus() })
        } else {
            // Reopen with every application group stacked again.
            notifications.collapseAllGroups()
        }
        mainItem: Item {
        id: centerContent
        // Content offset for the slide; the window itself stays put.
        property real slide: 0
        implicitWidth: centerView.implicitWidth
        implicitHeight: centerView.implicitHeight
        clip: true
        StatusCenterView {
        id: centerView
        x: centerContent.slide
        width: parent.width
        height: parent.height
        opacity: 1 - Math.min(1, Math.max(0, centerContent.slide) / Math.max(1, centerContent.width)) * 0.8
        Keys.onEscapePressed: root.closeCenter()
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
    }

    // Notification Center slides in from the right and leaves to the right
    // (macOS-style). Clicking elsewhere still hides the window at once:
    // Plasma owns that path.
    function openCenter() {
        centerExit.stop()
        if (MeoTheme.reduceMotion) {
            centerContent.slide = 0
            popup.visible = true
            return
        }
        centerContent.slide = Math.max(1, centerContent.width) * 0.6
        popup.visible = true
        centerEnter.restart()
    }
    function closeCenter() {
        if (!popup.visible)
            return
        centerEnter.stop()
        if (MeoTheme.reduceMotion) {
            popup.visible = false
            return
        }
        centerExit.restart()
    }
    NumberAnimation {
        id: centerEnter
        target: centerContent; property: "slide"; to: 0
        duration: 450
        easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
    }
    SequentialAnimation {
        id: centerExit
        NumberAnimation {
            target: centerContent; property: "slide"; to: centerContent.width * 0.6
            duration: 200
            easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedAccelerate
        }
        ScriptAction { script: popup.visible = false }
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
                root.showToast()
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
        onTriggered: root.hideToast(true)
    }
    // The banner slides in from the screen edge on the right and leaves the
    // same way (with a soft settle, like a macOS banner). The window itself
    // stays put; only its content moves, clipped to the window.
    function showToast() {
        toastExit.stop()
        if (!toast.visible) {
            toastContent.slide = MeoTheme.reduceMotion ? 0 : toastContent.width
            toast.visible = true
        }
        if (!MeoTheme.reduceMotion)
            toastEnter.restart()
    }
    function hideToast(expire) {
        if (!toast.visible)
            return
        toastEnter.stop()
        toastExit.expireAfter = expire
        toastExit.restart()
    }
    // MD3 emphasized decelerate: a fast start and a long, soft settle (close to
    // Apple's ease-out). No overshoot: the window edge would clip it.
    NumberAnimation {
        id: toastEnter
        target: toastContent; property: "slide"; to: 0
        duration: 450
        easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
    }
    SequentialAnimation {
        id: toastExit
        property bool expireAfter: false
        NumberAnimation {
            target: toastContent; property: "slide"; to: toastContent.width
            duration: MeoTheme.reduceMotion ? 0 : 260
            easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedAccelerate
        }
        ScriptAction {
            script: {
                toast.visible = false
                if (toastExit.expireAfter && toastModel.count > 0)
                    toastModel.expire(toastModel.index(0, 0))
            }
        }
    }
    Connections {
        target: toastModel
        // Swiped away or closed from its own buttons: nothing left to show.
        function onCountChanged() {
            if (toastModel.count === 0 && toast.visible) {
                toastExpiry.stop()
                toast.visible = false
            }
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
        mainItem: Item {
            id: toastContent
            property real slide: 0
            implicitWidth: toastView.implicitWidth
            implicitHeight: toastView.implicitHeight
            clip: true
            NotificationCenterView {
            id: toastView
            x: toastContent.slide
            width: parent.width
            height: parent.height
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

}
