import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0
Item {
    id: root
    property var notifications: null
    property date currentDateTime: new Date()
    property string centerMode: "timeNotifications"
    property string clockFormat: "system"
    property bool showSeconds: false
    property bool showDate: true
    property bool showJobs: true
    property bool showHistory: true
    property string notificationView: "cards"
    property string notificationPreview: "full"
    property string density: "comfortable"
    property string surfaceStyle: "theme"
    property int surfaceOpacityPercent: 100
    property bool showWeekNumbers: false
    property bool showSecondaryCalendar: true
    property string defaultPage: "notifications"
    property bool revealActive: true
    readonly property bool showCalendar: centerMode === "timeCalendar" || centerMode === "timeCalendarNotifications" || centerMode === ""
    readonly property bool use24Hour: clockFormat === "24h" || (clockFormat === "system" && Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") < 0)
    implicitWidth: 420 * MeoTheme.globalScale
    implicitHeight: 580 * MeoTheme.globalScale
    Layout.minimumWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    Loader {
        anchors.fill: parent
        active: root.showCalendar
        source: "OriginalStatusCenterView.qml"
        onLoaded: {
            for (const key of ["notifications", "currentDateTime", "centerMode", "clockFormat", "showSeconds", "showDate", "showJobs", "showHistory", "showWeekNumbers", "showSecondaryCalendar"])
                item[key] = Qt.binding(function() { return root[key] })
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space12
        visible: !root.showCalendar
        MeoMotionSurface {
            objectName: "fixedTimeCard"
            visible: root.centerMode !== "notificationsOnly"
            Layout.fillWidth: true
            Layout.preferredHeight: 112 * MeoTheme.globalScale
            radius: MeoTheme.shapeExtraLarge
            color: MeoTheme.surfaceContainerLow
            elevation: 0
            showOutline: false
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space24
                spacing: MeoTheme.space4
                MeoText {
                    text: Qt.formatTime(root.currentDateTime, root.use24Hour ? (root.showSeconds ? "hh:mm:ss" : "hh:mm") : "h:mm AP")
                    typeRole: "title"; typeSize: "large"
                    font.pixelSize: MeoTheme.displaySmall.size * MeoTheme.globalScale * MeoTheme.fontScale
                    lineHeight: MeoTheme.displaySmall.lineHeight * MeoTheme.globalScale * MeoTheme.fontScale
                    lineHeightMode: Text.FixedHeight
                    color: MeoTheme.contentOnSurface
                }
                MeoText {
                    text: Qt.formatDate(root.currentDateTime, Qt.locale().dateFormat(Locale.LongFormat))
                    visible: root.showDate
                    typeRole: "body"; typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                }
            }
        }
        NotificationCenterView {
            objectName: "scrollableNotifications"
            Layout.fillWidth: true
            Layout.fillHeight: true
            notifications: root.notifications
            currentDateTime: root.currentDateTime
            showTitle: true
            showJobs: root.showJobs
            showHistory: root.showHistory
            notificationView: root.notificationView
            notificationPreview: root.notificationPreview
            density: root.density
            onSettingsRequested: Qt.openUrlExternally("applications:org.meo.settings.notifications.desktop")
        }
    }
}
