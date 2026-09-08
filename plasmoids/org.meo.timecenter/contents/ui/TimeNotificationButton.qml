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
    property bool active: false
    readonly property bool hasNotificationState: root.unreadCount > 0
                                                 || root.activeJobsCount > 0
                                                 || root.inhibited
    signal statusCenterRequested()

    implicitWidth: timeContent.implicitWidth + leftPadding + rightPadding
    // The top panel is intentionally compact.  Keep time, date and the
    // notification affordance on a single baseline in the compact 32 dp
    // panel while retaining a small vertical breathing margin.
    implicitHeight: 28 * MeoTheme.globalScale
    leftPadding: MeoTheme.space4
    rightPadding: MeoTheme.space4
    Accessible.name: qsTr("Time, calendar, and notifications")
    Accessible.description: inhibited
                            ? qsTr("Do Not Disturb is on")
                            : (unreadCount > 0
                               ? qsTr("%1 unread notifications").arg(unreadCount)
                               : (activeJobsCount > 0
                                  ? qsTr("%1 background tasks, %2 percent complete")
                                      .arg(activeJobsCount).arg(jobsPercentage)
                                  : qsTr("No unread notifications")))
    onClicked: statusCenterRequested()

    MeoSpringValue {
        id: pressSpring
        value: 1
        targetValue: root.down ? 0.94 : 1
        spring: MeoMotion.fastSpatial
    }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: pressSpring.value
        yScale: pressSpring.value
    }

    background: MeoShape {
        id: statusSurface
        type: "pill"
        radius: height / 2
        color: root.active
               ? MeoTheme.primaryContainer
               : (root.hovered || root.down
                  ? MeoTheme.surfaceContainerHighest
                  : Qt.rgba(0, 0, 0, 0))
        strokeColor: Qt.rgba(0, 0, 0, 0)
        strokeWidth: 0

        Behavior on color {
            ColorAnimation {
                duration: MeoTheme.motionDurationEffectDefault
                easing.bezierCurve: MeoTheme.motionEasingStandard
            }
        }

        MeoStateLayer {
            anchors.fill: parent
            radius: statusSurface.radius
            color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface
            hovered: root.hovered
            pressed: root.down
            focused: root.activeFocus
        }

    }

    contentItem: RowLayout {
        id: timeContent
        spacing: MeoTheme.space4

        RowLayout {
            spacing: MeoTheme.space4
            Layout.alignment: Qt.AlignVCenter

            MeoText {
                text: Qt.formatTime(root.currentDateTime, root.use24HourClock ? "hh:mm" : "h:mm AP")
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                fontScaleOverride: root.textScale
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface
            }

            MeoText {
                visible: root.showDate
                text: Qt.formatDate(root.currentDateTime, "MMM d")
                typeRole: "label"
                typeSize: "small"
                fontScaleOverride: root.textScale
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
            }
        }

        Item {
            // The clock already opens the combined calendar/notification
            // center. Keep the bell out of the idle bar unless it has state.
            visible: root.showNotifications && root.hasNotificationState
            Layout.leftMargin: MeoTheme.space2
            implicitWidth: 24 * MeoTheme.globalScale
            implicitHeight: width

            MeoIcon {
                anchors.centerIn: parent
                icon: root.inhibited ? "do_not_disturb_on"
                                     : (root.activeJobsCount > 0 && root.unreadCount === 0
                                        ? "progress_activity" : "notifications")
                size: 20
                color: root.active
                       ? MeoTheme.onPrimaryContainer
                       : (root.inhibited || root.unreadCount > 0
                          ? MeoTheme.primary : MeoTheme.onSurface)
            }

            MeoBadge {
                visible: root.unreadCount > 0 || root.activeJobsCount > 0
                text: root.unreadCount > 0 ? root.unreadCount : root.activeJobsCount
                target: parent
            }
        }
    }
}
