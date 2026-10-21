pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Meo Notifications")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: compactRepresentation
    // The shell popup is a transparent dialog that draws only its own rounded
    // surface, so the platform's outer panel background never shows around it.
    // `expanded` is only the trigger; the dialog below owns visibility.
    onExpandedChanged: if (root.expanded) {
        root.expanded = false
        popup.visible = !popup.visible
    }
    Layout.minimumWidth: 28 * MeoTheme.globalScale
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

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

    compactRepresentation: NotificationCompactButton {
        anchors.centerIn: parent
        active: popup.visible
        unreadCount: notifications.unreadNotificationsCount
        activeJobsCount: notifications.activeJobsCount
        inhibited: NotificationManager.Server.inhibited
        showUnreadBadge: Plasmoid.configuration.showUnreadBadge
        onStatusCenterRequested: popup.visible = !popup.visible
    }

    fullRepresentation: Item {
        implicitWidth: 1
        implicitHeight: 1
    }

    PlasmaCore.Dialog {
        id: popup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.TopEdge
        visualParent: root.compactRepresentationItem
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (visible) {
            notifications.lastRead = new Date()
            toast.visible = false
            Qt.callLater(function() {
                popup.requestActivate()
                popup.mainItem.forceActiveFocus()
            })
        }

        mainItem: StatusCenterView {
            Keys.onEscapePressed: popup.visible = false
            revealActive: popup.visible
            notifications: notifications
            centerMode: "notificationsOnly"
            showJobs: Plasmoid.configuration.showJobs
            showHistory: Plasmoid.configuration.showNotificationHistory
            notificationView: Plasmoid.configuration.notificationView
            notificationPreview: Plasmoid.configuration.notificationPreview
            density: Plasmoid.configuration.density
            surfaceStyle: Plasmoid.configuration.surfaceStyle
            surfaceOpacityPercent: Plasmoid.configuration.surfaceOpacityPercent
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
            if (toastModel.ready && toastModel.count > 0 && !NotificationManager.Server.inhibited
                    && !popup.visible) {
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
            if (toastModel.count > 0)
                toastModel.expire(toastModel.index(0, 0))
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
            implicitHeight: Math.max(180 * MeoTheme.globalScale,
                                     Math.min(320 * MeoTheme.globalScale,
                                              renderedHeight + MeoTheme.space24))
            notifications: toastModel
            currentDateTime: new Date()
            showTitle: false
            showEmptyState: false
            showHeader: false
            showSettingsAction: false
            showJobs: false
            showHistory: false
        }
    }
}
