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
    Accessible.name: MeoI18n.translator.i18n("Notifications")
    Accessible.description: root.unreadCount > 0 ? MeoI18n.translator.i18n("%1 unread notifications").arg(root.unreadCount) : MeoI18n.translator.i18n("No unread notifications")
    onClicked: statusCenterRequested()

    PointHandler {
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            compactStateLayer._pointerPressActive = active
            if (active) {
                const localPoint = compactStateLayer.mapFromItem(root,
                                                                  point.position.x,
                                                                  point.position.y)
                compactStateLayer.trigger(localPoint.x, localPoint.y)
            } else {
                compactStateLayer.releaseRipple()
            }
        }
    }

    Keys.onPressed: event => {
        if (!event.isAutoRepeat
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space))
            compactStateLayer.triggerFromKeyboard()
    }

    background: MeoShape {
        type: "round"
        radius: MeoTheme.shapeSmall
        color: root.active ? MeoTheme.primaryContainer : "transparent"
        MeoStateLayer {
            id: compactStateLayer
            anchors.fill: parent
            internalPointerTrackingEnabled: false
            radius: parent.radius
            hovered: root.hovered
            pressed: root.down
            focused: root.visualFocus
            focusColor: MeoTheme.primary
        }
    }
    contentItem: Item {
        MeoIcon { anchors.centerIn: parent; icon: root.inhibited ? "do_not_disturb_on" : (root.activeJobsCount > 0 ? "progress_activity" : "notifications"); size: 20; color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface }
        MeoBadge { visible: root.showUnreadBadge && (root.unreadCount > 0 || root.activeJobsCount > 0); text: root.unreadCount > 0 ? root.unreadCount : root.activeJobsCount; target: parent }
    }
}
