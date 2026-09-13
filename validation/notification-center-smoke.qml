import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window

    width: 560
    height: 720
    visible: true
    color: MeoTheme.background
    readonly property bool compactNotificationView: Qt.application.arguments.indexOf("--compact") !== -1
    readonly property bool summaryPreview: Qt.application.arguments.indexOf("--summary") !== -1
    readonly property bool hideHistory: Qt.application.arguments.indexOf("--hide-history") !== -1
    readonly property bool hideJobs: Qt.application.arguments.indexOf("--hide-jobs") !== -1

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    ListModel {
        id: previewNotifications
    }

    Component.onCompleted: {
        previewNotifications.append({
            "summary": "Design review starts in 10 minutes",
            "body": "Meo desktop notification polish",
            "applicationName": "Calendar",
            "originName": "",
            "iconName": "view-calendar-day",
            "applicationIconName": "",
            "closable": true,
            "expired": false,
            "configurable": true,
            "hasDefaultAction": true,
            "hasReplyAction": true,
            "replyActionLabel": "Reply",
            "replyPlaceholderText": "Reply to Calendar",
            "replySubmitButtonText": "Send",
            "actionNames": [],
            "actionLabels": [],
            "type": 1,
            "urgency": 1,
            "percentage": -1,
            "jobState": 0,
            "suspendable": false,
            "killable": false,
            "created": new Date(2026, 7, 21, 14, 24),
            "updated": new Date(2026, 7, 21, 14, 24)
        })
        previewNotifications.append({
            "summary": "Copying release image",
            "body": "meoarch-2026.08.21-x86_64.iso",
            "applicationName": "Dolphin",
            "originName": "",
            "iconName": "folder",
            "applicationIconName": "system-file-manager",
            "closable": true,
            "expired": false,
            "configurable": false,
            "hasDefaultAction": false,
            "hasReplyAction": false,
            "replyActionLabel": "",
            "replyPlaceholderText": "",
            "replySubmitButtonText": "",
            "actionNames": [],
            "actionLabels": [],
            "type": 2,
            "urgency": 1,
            "percentage": 68,
            "jobState": 1,
            "suspendable": true,
            "killable": true,
            "created": new Date(2026, 7, 21, 14, 17),
            "updated": new Date(2026, 7, 21, 14, 27)
        })
        previewNotifications.append({
            "summary": "Battery level is critical",
            "body": "Connect a charger to keep working.",
            "applicationName": "Power Management",
            "originName": "",
            "iconName": "battery-caution",
            "applicationIconName": "",
            "closable": true,
            "expired": false,
            "configurable": true,
            "hasDefaultAction": false,
            "hasReplyAction": false,
            "replyActionLabel": "",
            "replyPlaceholderText": "",
            "replySubmitButtonText": "",
            "actionNames": [],
            "actionLabels": [],
            "type": 1,
            "urgency": 2,
            "percentage": -1,
            "jobState": 0,
            "suspendable": false,
            "killable": false,
            "created": new Date(2026, 7, 21, 14, 28),
            "updated": new Date(2026, 7, 21, 14, 28)
        })
        previewNotifications.append({
            "summary": "Phone link is ready",
            "body": "Messages and battery status can now sync with this desktop.",
            "applicationName": "KDE Connect",
            "originName": "Pixel 10",
            "iconName": "smartphone",
            "applicationIconName": "kdeconnect",
            "closable": true,
            "expired": true,
            "configurable": true,
            "hasDefaultAction": false,
            "hasReplyAction": false,
            "replyActionLabel": "",
            "replyPlaceholderText": "",
            "replySubmitButtonText": "",
            "actionNames": [],
            "actionLabels": [],
            "type": 1,
            "urgency": 1,
            "percentage": -1,
            "jobState": 0,
            "suspendable": false,
            "killable": false,
            "created": new Date(2026, 7, 20, 18, 10),
            "updated": new Date(2026, 7, 20, 18, 10)
        })
    }

    MeoMotionSurface {
        anchors.fill: parent
        anchors.margins: 24
        color: MeoTheme.surfaceContainerLow
        radius: MeoTheme.shapeExtraLarge
        elevation: 2

        NotificationCenterView {
            id: notificationCenter
            anchors.fill: parent
            anchors.margins: 16
            notifications: previewNotifications
            currentDateTime: new Date(2026, 7, 21, 14, 30)
            notificationView: window.compactNotificationView ? "compact" : "cards"
            notificationPreview: window.summaryPreview ? "summary" : "full"
            showHistory: !window.hideHistory
            showJobs: !window.hideJobs
        }
    }

    Timer {
        interval: 800
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            const expectedVisibleCount = (window.hideHistory ? 3 : 4)
                                         - (window.hideJobs ? 1 : 0)
            if (notificationCenter.visibleNotificationCount !== expectedVisibleCount) {
                console.error("Unexpected visible notification count",
                              notificationCenter.visibleNotificationCount,
                              "expected", expectedVisibleCount)
                Qt.exit(2)
                return
            }
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save notification center snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
