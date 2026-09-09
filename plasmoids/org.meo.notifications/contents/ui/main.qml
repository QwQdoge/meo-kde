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
    Plasmoid.title: qsTr("Meo Notifications")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: compactRepresentation
    onExpandedChanged: if (root.expanded) notifications.lastRead = new Date()
    Layout.minimumWidth: 28 * MeoTheme.globalScale; Layout.preferredWidth: Layout.minimumWidth; Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight; Layout.preferredHeight: Layout.minimumHeight; Layout.maximumHeight: Layout.minimumHeight
    NotificationManager.Notifications { id: notifications; limit: 50; showNotifications: true; showJobs: Plasmoid.configuration.showJobs; showExpired: true; showDismissed: false; sortMode: NotificationManager.Notifications.SortByDate; sortOrder: Qt.DescendingOrder; groupMode: NotificationManager.Notifications.GroupDisabled; window: root.Window.window }
    compactRepresentation: NotificationCompactButton { anchors.centerIn: parent; active: root.expanded; unreadCount: notifications.unreadNotificationsCount; activeJobsCount: notifications.activeJobsCount; inhibited: NotificationManager.Server.inhibited; showUnreadBadge: Plasmoid.configuration.showUnreadBadge; onStatusCenterRequested: root.expanded = !root.expanded }
    fullRepresentation: StatusCenterView { notifications: notifications; centerMode: "notificationsOnly"; showJobs: Plasmoid.configuration.showJobs }
}
