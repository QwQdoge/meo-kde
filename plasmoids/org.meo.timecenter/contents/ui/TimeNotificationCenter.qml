import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

Item {
    id: root

    property var notifications: null
    property date currentDateTime: new Date()
    property bool use24HourClock: true

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
                Layout.fillWidth: true
                Layout.preferredHeight: 64 * MeoTheme.globalScale
                spacing: 0

                MeoText {
                    text: Qt.formatTime(root.currentDateTime, root.use24HourClock ? "hh:mm" : "h:mm AP")
                    typeRole: "title"
                    typeSize: "large"
                    emphasized: true
                    color: MeoTheme.onSurface
                }

                MeoText {
                    text: Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleLongDate)
                    typeRole: "body"
                    typeSize: "medium"
                    color: MeoTheme.onSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: MeoTheme.space16

                MeoMotionSurface {
                    visible: root.width >= 620 * MeoTheme.globalScale
                    Layout.preferredWidth: 292 * MeoTheme.globalScale
                    Layout.fillHeight: true
                    color: MeoTheme.surfaceContainer
                    radius: MeoTheme.shapeExtraLarge
                    elevation: 0

                    MeoMonthCalendar {
                        anchors.fill: parent
                        anchors.margins: MeoTheme.space16
                        selectedDate: root.currentDateTime
                        displayDate: root.currentDateTime
                    }
                }

                MeoDivider {
                    visible: root.width >= 620 * MeoTheme.globalScale
                    Layout.fillHeight: true
                    orientation: "vertical"
                }

                NotificationCenterView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    notifications: root.notifications
                    currentDateTime: root.currentDateTime
                    onSettingsRequested: {
                        if (!Qt.openUrlExternally("applications:org.meo.settings.desktop"))
                            Qt.openUrlExternally("systemsettings:kcm_notifications")
                    }
                }
            }
        }
    }
}
