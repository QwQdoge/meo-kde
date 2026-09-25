import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0

// One compact interaction target shared by every clock/notification applet.
// The notification glyph is deliberately non-interactive: nesting a second
// button inside the clock caused duplicate popup toggles and split feedback.
QQC2.AbstractButton {
    id: root

    property date currentDateTime: new Date()
    property int unreadCount: 0
    property int activeJobsCount: 0
    property int jobsPercentage: 0
    property bool inhibited: false
    property real textScale: 1.0
    property bool showDate: true
    property bool showSeconds: false
    property bool showNotifications: true
    property bool showUnreadBadge: true
    property bool use24HourClock: true
    property bool active: false
    readonly property bool hasNotificationState: unreadCount > 0
                                                 || activeJobsCount > 0
                                                 || inhibited

    signal statusCenterRequested()

    implicitWidth: timeContent.implicitWidth + leftPadding + rightPadding
    implicitHeight: 28 * MeoTheme.globalScale
    leftPadding: MeoTheme.space4
    rightPadding: MeoTheme.space4
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: MeoI18n.translator.i18n("Time, calendar, and notifications")
    Accessible.description: {
        const time = Qt.formatTime(root.currentDateTime,
                                   root.use24HourClock
                                   ? (root.showSeconds ? "hh:mm:ss" : "hh:mm")
                                   : (root.showSeconds ? "h:mm:ss AP" : "h:mm AP"))
        const date = root.showDate
                   ? Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleShortDate) : ""
        const timeAndDate = date === "" ? time
                                         : MeoI18n.translator.i18n("%1 · %2").arg(time).arg(date)
        const notificationState = root.inhibited
                                ? MeoI18n.translator.i18n("Do Not Disturb is on")
                                : (root.unreadCount > 0
                                   ? MeoI18n.translator.i18n("%1 unread notifications").arg(root.unreadCount)
                                   : (root.activeJobsCount > 0
                                      ? MeoI18n.translator.i18n("%1 background tasks, %2 percent complete")
                                          .arg(root.activeJobsCount).arg(root.jobsPercentage)
                                      : MeoI18n.translator.i18n("No unread notifications")))
        return MeoI18n.translator.i18n("%1 · %2").arg(timeAndDate).arg(notificationState)
    }
    onClicked: statusCenterRequested()

    MeoInteractionMotion {
        id: interactionMotion
        hovered: root.hovered
        pressed: root.down
        active: root.active
        enabled: root.enabled
        pressedScale: 0.965
    }

    scale: interactionMotion.scale
    transform: Translate { y: interactionMotion.offsetY }

    PointHandler {
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            stateLayer._pointerPressActive = active
            if (active) {
                const localPoint = stateLayer.mapFromItem(root,
                                                          point.position.x,
                                                          point.position.y)
                stateLayer.trigger(localPoint.x, localPoint.y)
            } else {
                stateLayer.releaseRipple()
            }
        }
    }

    Keys.onPressed: event => {
        if (!event.isAutoRepeat
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space))
            stateLayer.triggerFromKeyboard()
    }

    background: MeoShape {
        id: statusSurface
        type: "round"
        radius: MeoTheme.shapeSmall
        color: root.active
               ? MeoTheme.primaryContainer
               : (root.hovered || root.down
                  ? MeoTheme.surfaceContainerHighest
                  : "transparent")
        strokeColor: "transparent"
        strokeWidth: 0

        Behavior on color {
            ColorAnimation {
                duration: MeoTheme.motionDurationSelection
                easing.type: Easing.BezierSpline
                easing.bezierCurve: MeoTheme.motionEasingStandard
            }
        }

        MeoStateLayer {
            id: stateLayer
            anchors.fill: parent
            internalPointerTrackingEnabled: false
            radius: statusSurface.radius
            hovered: root.hovered
            pressed: root.down
            focused: root.visualFocus
            focusColor: MeoTheme.primary
        }
    }

    contentItem: RowLayout {
        id: timeContent
        spacing: MeoTheme.space4

        RowLayout {
            spacing: MeoTheme.space4
            Layout.alignment: Qt.AlignVCenter

            MeoText {
                text: Qt.formatTime(root.currentDateTime,
                                    root.use24HourClock
                                    ? (root.showSeconds ? "hh:mm:ss" : "hh:mm")
                                    : (root.showSeconds ? "h:mm:ss AP" : "h:mm AP"))
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                fontScaleOverride: root.textScale
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurface
            }

            MeoText {
                visible: root.showDate
                text: Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleShortDate)
                typeRole: "label"
                typeSize: "small"
                fontScaleOverride: root.textScale
                color: root.active ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant
            }
        }

        Item {
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
                visible: root.showUnreadBadge
                         && (root.unreadCount > 0 || root.activeJobsCount > 0)
                text: root.unreadCount > 0 ? root.unreadCount : root.activeJobsCount
                target: parent
            }
        }
    }
}
