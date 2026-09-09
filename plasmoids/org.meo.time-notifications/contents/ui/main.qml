import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root
    readonly property bool use24Hour: Plasmoid.configuration.clockFormat !== "12h"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: qsTr("Meo Time and Notifications")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: compactRepresentation
    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth : 80 * MeoTheme.globalScale; Layout.preferredWidth: Layout.minimumWidth; Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight; Layout.preferredHeight: Layout.minimumHeight; Layout.maximumHeight: Layout.minimumHeight
    PlasmaClock.Clock { id: clock; trackSeconds: true }
    NotificationManager.Notifications { id: notifications; limit: 50; showNotifications: true; showJobs: Plasmoid.configuration.showJobs; showExpired: true; showDismissed: false; sortMode: NotificationManager.Notifications.SortByDate; sortOrder: Qt.DescendingOrder; groupMode: NotificationManager.Notifications.GroupDisabled; window: root.Window.window }
    compactRepresentation: QQC2.AbstractButton {
        implicitWidth: row.implicitWidth + 8 * MeoTheme.globalScale; implicitHeight: 28 * MeoTheme.globalScale
        Accessible.name: qsTr("Time and notifications")
        onClicked: root.expanded = !root.expanded
        background: MeoShape { type: "pill"; radius: height / 2; color: parent.down || parent.hovered || root.expanded ? MeoTheme.surfaceContainerHighest : Qt.rgba(0,0,0,0) }
        contentItem: RowLayout { id: row; spacing: MeoTheme.space4; MeoText { text: Qt.formatTime(clock.dateTime, root.use24Hour ? (Plasmoid.configuration.showSeconds ? "hh:mm:ss" : "hh:mm") : (Plasmoid.configuration.showSeconds ? "h:mm:ss AP" : "h:mm AP")); typeRole: "label"; typeSize: "medium"; emphasized: true } MeoText { visible: Plasmoid.configuration.showDate; text: Qt.formatDate(clock.dateTime, "MMM d"); typeRole: "label"; typeSize: "small" } NotificationCompactButton { active: root.expanded; unreadCount: notifications.unreadNotificationsCount; activeJobsCount: notifications.activeJobsCount; inhibited: NotificationManager.Server.inhibited; showUnreadBadge: Plasmoid.configuration.showUnreadBadge; onStatusCenterRequested: root.expanded = !root.expanded } }
    }
    fullRepresentation: StatusCenterView { notifications: notifications; currentDateTime: clock.dateTime; centerMode: "timeNotifications"; clockFormat: Plasmoid.configuration.clockFormat; showSeconds: Plasmoid.configuration.showSeconds; showDate: Plasmoid.configuration.showDate; showJobs: Plasmoid.configuration.showJobs }
}
