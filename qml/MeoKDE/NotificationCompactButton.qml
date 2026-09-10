import QtQuick
import QtQuick.Controls as QQC2
import MeoUI 1.0

QQC2.AbstractButton {
    id: root
    property int unreadCount: 0
    property int activeJobsCount: 0
    property bool inhibited: false
    property bool active: false
    property bool showUnreadBadge: true
    signal statusCenterRequested()
    implicitWidth: 28 * MeoTheme.globalScale
    implicitHeight: implicitWidth
    Accessible.name: qsTr("Notifications")
    Accessible.description: root.unreadCount > 0 ? qsTr("%1 unread notifications").arg(root.unreadCount) : qsTr("No unread notifications")
    onClicked: statusCenterRequested()
    background: MeoShape {
        type: "round"
        radius: MeoTheme.shapeSmall
        color: root.active ? MeoTheme.primaryContainer : (root.hovered || root.down ? MeoTheme.surfaceContainerHighest : "transparent")
        MeoStateLayer { anchors.fill: parent; radius: parent.radius; hovered: root.hovered; pressed: root.down; focused: root.activeFocus }
    }
    contentItem: Item {
        MeoIcon { anchors.centerIn: parent; icon: root.inhibited ? "do_not_disturb_on" : (root.activeJobsCount > 0 ? "progress_activity" : "notifications"); size: 20; color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface }
        MeoBadge { visible: root.showUnreadBadge && (root.unreadCount > 0 || root.activeJobsCount > 0); text: root.unreadCount > 0 ? root.unreadCount : root.activeJobsCount; target: parent }
    }
}
