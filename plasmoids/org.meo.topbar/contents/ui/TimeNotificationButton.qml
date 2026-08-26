import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

QQC2.AbstractButton {
    id: root

    property date currentDateTime: new Date()
    property int unreadCount: 0
    property real textScale: 1.0
    property bool showDate: true
    property bool showNotifications: true
    property bool use24HourClock: true

    signal statusCenterRequested()

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: ShellMetrics.compactTopControlHeight
    leftPadding: MeoTheme.space8
    rightPadding: MeoTheme.space8
    Accessible.name: qsTr("Time, calendar, and notifications")
    Accessible.description: unreadCount > 0
                            ? qsTr("%1 unread notifications").arg(unreadCount)
                            : qsTr("No unread notifications")
    onClicked: statusCenterRequested()

    background: MeoShape {
        id: statusSurface
        type: "pill"
        radius: height / 2
        color: root.hovered || root.down ? MeoTheme.surfaceContainerHighest : Qt.rgba(0, 0, 0, 0)

        MeoStateLayer {
            anchors.fill: parent
            radius: statusSurface.radius
            hovered: root.hovered
            pressed: root.down
            focused: root.visualFocus
            color: MeoTheme.onSurface
        }
    }

    contentItem: RowLayout {
        spacing: MeoTheme.space8

        ColumnLayout {
            spacing: 0

            MeoText {
                text: Qt.formatTime(root.currentDateTime, root.use24HourClock ? "hh:mm" : "h:mm AP")
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                fontScaleOverride: root.textScale
                color: MeoTheme.onSurface
            }

            MeoText {
                visible: root.showDate
                text: Qt.formatDate(root.currentDateTime, "MMM d")
                typeRole: "label"
                typeSize: "small"
                fontScaleOverride: root.textScale
                color: MeoTheme.onSurfaceVariant
            }
        }

        Item {
            visible: root.showNotifications
            implicitWidth: 24 * MeoTheme.globalScale
            implicitHeight: width

            MeoIcon {
                anchors.centerIn: parent
                icon: root.unreadCount > 0 ? "notifications" : "notifications_none"
                size: 20
                color: MeoTheme.onSurface
            }

            MeoBadge {
                visible: root.unreadCount > 0
                text: root.unreadCount
                target: parent
            }
        }
    }
}
