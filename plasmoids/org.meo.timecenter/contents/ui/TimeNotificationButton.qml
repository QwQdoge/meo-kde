import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0

QQC2.AbstractButton {
    id: root

    property date currentDateTime: new Date()
    property int unreadCount: 0
    property int activeJobsCount: 0
    property int jobsPercentage: 0
    property bool inhibited: false
    property real textScale: 1.0
    property bool showDate: true
    property bool showNotifications: true
    property bool use24HourClock: true
    signal statusCenterRequested()

    implicitWidth: timeContent.implicitWidth + leftPadding + rightPadding
    // The top panel is intentionally compact.  Keep time, date and the
    // notification affordance on a single baseline so they cannot visually
    // collide at 32–40 px panel heights or high fractional scale factors.
    implicitHeight: 32 * MeoTheme.globalScale
    leftPadding: MeoTheme.space8
    rightPadding: MeoTheme.space8
    Accessible.name: qsTr("Time, calendar, and notifications")
    Accessible.description: inhibited
                            ? qsTr("Do Not Disturb is on")
                            : (unreadCount > 0
                               ? qsTr("%1 unread notifications").arg(unreadCount)
                               : (activeJobsCount > 0
                                  ? qsTr("%1 background tasks").arg(activeJobsCount)
                                  : qsTr("No unread notifications")))
    onClicked: statusCenterRequested()

    background: MeoShape {
        id: statusSurface
        type: "pill"
        radius: height / 2
        color: root.hovered || root.down
               ? MeoTheme.surfaceContainerHighest
               : MeoTheme.surfaceContainer
        strokeColor: MeoTheme.outlineVariant
        // See the system-status trigger: this keeps a live module handoff
        // from assigning an undefined value to MeoShape.strokeWidth.
        strokeWidth: typeof MeoTheme.strokeWidthThin === "number"
                     ? MeoTheme.strokeWidthThin
                     : MeoTheme.globalScale

        // MeoUI owns the compact-control interaction treatment, including the
        // MD3 state layer and clipped ripple.
        MeoStateLayer {
            anchors.fill: parent
            radius: statusSurface.radius
            color: MeoTheme.primary
            hovered: root.hovered
            pressed: root.down
            focused: root.activeFocus
        }

    }

    contentItem: RowLayout {
        id: timeContent
        spacing: MeoTheme.space4 + MeoTheme.space2

        RowLayout {
            spacing: MeoTheme.space4
            Layout.alignment: Qt.AlignVCenter

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
            Layout.leftMargin: MeoTheme.space2
            implicitWidth: 24 * MeoTheme.globalScale
            implicitHeight: width

            MeoIcon {
                anchors.centerIn: parent
                icon: root.inhibited ? "do_not_disturb_on"
                                     : (root.unreadCount > 0 ? "notifications" : "notifications_none")
                size: 20
                color: root.inhibited || root.unreadCount > 0 ? MeoTheme.primary : MeoTheme.onSurface
            }

            MeoBadge {
                visible: root.unreadCount > 0 || root.activeJobsCount > 0
                text: root.unreadCount > 0 ? root.unreadCount : root.activeJobsCount
                target: parent
            }
        }
    }
}
