import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

// Plasma data adapter for MeoUI's status-center primitive. The center owns
// its surface, responsive structure, timer lifecycle, and semantic modes;
// this file supplies only live KDE content and the compatibility string API.
MeoStatusCenter {
    id: root

    property var notifications: null
    property string clockFormat: "system"
    property bool showSeconds: false
    property bool showDate: true
    property bool showJobs: true
    property bool showHistory: true
    property string notificationView: "cards"
    property string notificationPreview: "full"
    property string density: "comfortable"
    property bool showWeekNumbers: false
    property bool showSecondaryCalendar: true
    property string defaultPage: "notifications"

    readonly property bool showTime: centerMode !== "notificationsOnly"
    readonly property bool showCalendar: centerMode === ""
                                        || centerMode === "timeCalendar"
                                        || centerMode === "timeCalendarNotifications"
    readonly property bool showNotificationPane: centerMode !== "timeCalendar"
    readonly property bool use24HourClock: clockFormat === "24h"
    readonly property string timePattern: use24HourClock
                                       ? (showSeconds ? "hh:mm:ss" : "hh:mm")
                                       : (showSeconds ? "h:mm:ss AP" : "h:mm AP")

    mode: centerMode === "notificationsOnly"
          ? MeoStatusCenter.Notifications
          : (centerMode === "timeCalendar"
             ? MeoStatusCenter.TimeCalendar
             : MeoStatusCenter.TimeCalendarNotifications)
    // `calendarEnabled` preserves legacy timeNotifications without a fourth
    // visual implementation.
    calendarEnabled: showCalendar
    contentActive: visible
    updateTimeAutomatically: false
    timeText: Qt.formatTime(root.currentDateTime, root.timePattern)
    dateText: root.showDate
              ? Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleLongDate)
              : ""
    unreadCount: notifications && typeof notifications.unreadNotificationsCount === "number"
                 ? notifications.unreadNotificationsCount : 0

    implicitWidth: ShellMetrics.statusCenterWidth
    implicitHeight: ShellMetrics.statusCenterHeight
    Layout.minimumWidth: 320 * MeoTheme.globalScale
    Layout.minimumHeight: 360 * MeoTheme.globalScale

    headerContent: showTime ? timeHeader : null
    calendarContent: monthCalendar
    notificationContent: showNotificationPane ? notificationPane : null

    Component {
        id: timeHeader

        ColumnLayout {
            width: parent ? parent.width : implicitWidth
            spacing: 0

            MeoText {
                text: Qt.formatTime(root.currentDateTime, root.timePattern)
                typeRole: "title"
                typeSize: "large"
                emphasized: true
                color: MeoTheme.onSurface
            }

            MeoText {
                visible: root.showDate
                text: Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleLongDate)
                typeRole: "body"
                typeSize: "medium"
                color: MeoTheme.onSurfaceVariant
            }

            MeoText {
                visible: root.showSecondaryCalendar && SystemState.secondaryCalendarText.length > 0
                text: SystemState.secondaryCalendarText
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.onSurfaceVariant
                Accessible.name: qsTr("Secondary calendar: %1").arg(SystemState.secondaryCalendarText)
            }
        }
    }

    Component {
        id: monthCalendar

        MeoMonthCalendar {
            anchors.fill: parent
            selectedDate: root.currentDateTime
            displayDate: root.currentDateTime
            showWeekNumbers: root.showWeekNumbers
        }
    }

    Component {
        id: notificationPane

        NotificationCenterView {
            anchors.fill: parent
            notifications: root.notifications
            currentDateTime: root.currentDateTime
            showTitle: false
            showJobs: root.showJobs
            showHistory: root.showHistory
            notificationView: root.notificationView
            notificationPreview: root.notificationPreview
            density: root.density
            onSettingsRequested: Qt.openUrlExternally("applications:org.meo.settings.notifications.desktop")
        }
    }
}
