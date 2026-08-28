import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.private.sessions 2.0 as Sessions
import MeoUI 1.0
import MeoKDE 1.0

Item {
    id: root

    // Retained only for compatibility with an already-open representation
    // during a live applet update.  The current layout uses two independent
    // surfaces, but this fallback must not fail while Plasma rebinds models.
    property var notifications: null

    function openMeoSettings() {
        if (!Qt.openUrlExternally("applications:org.meo.settings.desktop"))
            Qt.openUrlExternally("systemsettings:")
    }

    function openMeoBluetoothSettings() {
        if (Qt.openUrlExternally("applications:org.meo.settings.bluetooth.desktop"))
            return
        if (Qt.openUrlExternally("applications:org.meo.settings.desktop"))
            return
        Qt.openUrlExternally("systemsettings:kcm_bluetooth")
    }
    property date currentDateTime: new Date()

    implicitWidth: 1120 * MeoTheme.globalScale
    implicitHeight: 548 * MeoTheme.globalScale
    Layout.minimumWidth: 700 * MeoTheme.globalScale
    Layout.minimumHeight: 420 * MeoTheme.globalScale
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    Component.onCompleted: if (notifications)
                               notifications.lastRead = currentDateTime

    MeoMotionSurface {
        anchors.fill: parent
        color: MeoTheme.surfaceContainerLow
        radius: ShellMetrics.radiusPopup
        elevation: 3

        RowLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space16
            spacing: MeoTheme.space16

            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: 400 * MeoTheme.globalScale
                Layout.minimumWidth: 336 * MeoTheme.globalScale

                QuickSettingsHome {
                    anchors.fill: parent
                    // This legacy combined surface is still supported, but its
                    // daily settings handoff goes to Meo Settings first. KDE
                    // System Settings is only the no-Meo-install fallback.
                    onWifiDetailsRequested: root.openMeoSettings()
                    onBluetoothDetailsRequested: root.openMeoBluetoothSettings()
                    onPowerDetailsRequested: root.openMeoSettings()
                    onPowerRequested: powerMenu.open()
                }
            }

            MeoDivider {
                Layout.fillHeight: true
                orientation: "vertical"
            }

            MeoStatusCenter {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentDateTime: root.currentDateTime
                timeText: Qt.formatTime(root.currentDateTime, "hh:mm")
                dateText: Qt.formatDate(root.currentDateTime, Qt.DefaultLocaleLongDate)
                unreadCount: root.notifications ? root.notifications.unreadNotificationsCount : 0

                notificationContent: Component {
                    NotificationCenterView {
                        notifications: root.notifications
                        currentDateTime: root.currentDateTime
                        showTitle: false
                        onSettingsRequested: {
                            if (!Qt.openUrlExternally("applications:org.meo.settings.desktop"))
                                Qt.openUrlExternally("systemsettings:kcm_notifications")
                        }
                    }
                }
            }
        }
    }

    Sessions.SessionManagement {
        id: sessionManagement
    }

    QQC2.Menu {
        id: powerMenu
        QQC2.MenuItem {
            text: qsTr("Sleep")
            visible: sessionManagement.canSuspend
            onTriggered: sessionManagement.suspend()
        }
        QQC2.MenuItem {
            text: qsTr("Restart")
            visible: sessionManagement.canReboot
            onTriggered: sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt)
        }
        QQC2.MenuItem {
            text: qsTr("Shut down")
            visible: sessionManagement.canShutdown
            onTriggered: sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: qsTr("Sign out")
            visible: sessionManagement.canLogout
            onTriggered: sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt)
        }
    }
}
