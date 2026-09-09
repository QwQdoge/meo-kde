import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

// Shared content surface for all Meo notification applets.  Plasma's
// NotificationManager model remains owned by each applet instance; this item
// only selects the presentation around that real model.
Item {
    id: root

    property var notifications: null
    property date currentDateTime: new Date()
    property string centerMode: "timeCalendarNotifications"
    property string clockFormat: "system"
    property bool showSeconds: false
    property bool showDate: true
    property bool showJobs: true
    property bool showWeekNumbers: false
    property bool showSecondaryCalendar: true
    property string defaultPage: "notifications"

    readonly property bool showTime: centerMode !== "notificationsOnly"
    readonly property bool showCalendar: centerMode === "timeCalendarNotifications"
    readonly property bool use24HourClock: clockFormat === "24h"
    readonly property string timePattern: use24HourClock
                                       ? (showSeconds ? "hh:mm:ss" : "hh:mm")
                                       : (showSeconds ? "h:mm:ss AP" : "h:mm AP")

    implicitWidth: ShellMetrics.statusCenterWidth
    implicitHeight: ShellMetrics.statusCenterHeight
    Layout.minimumWidth: 320 * MeoTheme.globalScale
    Layout.minimumHeight: 360 * MeoTheme.globalScale

    FrostedSurface {
        anchors.fill: parent
        baseColor: MeoTheme.surfaceContainerLow

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ShellMetrics.popupContentMargin
            spacing: MeoTheme.space16

            ColumnLayout {
                visible: root.showTime
                Layout.fillWidth: true
                spacing: 0
                MeoText {
                    text: Qt.formatTime(root.currentDateTime, root.timePattern)
                    typeRole: "title"; typeSize: "large"; emphasized: true
                    color: MeoTheme.onSurface
                }
                MeoText {
                    visible: root.showDate
                    text: Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleLongDate)
                    typeRole: "body"; typeSize: "medium"; color: MeoTheme.onSurfaceVariant
                }
                MeoText {
                    visible: root.showSecondaryCalendar && SystemState.secondaryCalendarText.length > 0
                    text: SystemState.secondaryCalendarText
                    typeRole: "label"; typeSize: "small"; color: MeoTheme.onSurfaceVariant
                    Accessible.name: qsTr("Secondary calendar: %1").arg(SystemState.secondaryCalendarText)
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: MeoTheme.space16
                MeoMotionSurface {
                    visible: root.showCalendar && root.width >= 620 * MeoTheme.globalScale
                    Layout.preferredWidth: 292 * MeoTheme.globalScale; Layout.fillHeight: true
                    color: MeoTheme.surfaceContainer; radius: ShellMetrics.radiusPopup; elevation: 0
                    MeoMonthCalendar {
                        anchors.fill: parent; anchors.margins: MeoTheme.space16
                        selectedDate: root.currentDateTime; displayDate: root.currentDateTime
                    }
                }
                MeoDivider {
                    visible: root.showCalendar && root.width >= 620 * MeoTheme.globalScale
                    Layout.fillHeight: true; orientation: "vertical"
                }
                NotificationCenterView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    notifications: root.notifications; currentDateTime: root.currentDateTime
                    onSettingsRequested: Qt.openUrlExternally("applications:org.meo.settings.notifications.desktop")
                }
            }
        }
    }
}
