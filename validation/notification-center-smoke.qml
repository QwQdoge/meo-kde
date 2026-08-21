import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window

    width: 560
    height: 640
    visible: true
    color: MeoTheme.background

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
            "iconName": "calendar_today",
            "applicationIconName": "",
            "closable": true,
            "configurable": true,
            "hasDefaultAction": true,
            "actionNames": ["join", "snooze"],
            "actionLabels": ["Join", "Snooze"],
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
            "iconName": "folder-copy",
            "applicationIconName": "system-file-manager",
            "closable": true,
            "configurable": false,
            "hasDefaultAction": false,
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
            "iconName": "battery-alert",
            "applicationIconName": "",
            "closable": true,
            "configurable": true,
            "hasDefaultAction": false,
            "actionNames": ["settings"],
            "actionLabels": ["Power settings"],
            "type": 1,
            "urgency": 2,
            "percentage": -1,
            "jobState": 0,
            "suspendable": false,
            "killable": false,
            "created": new Date(2026, 7, 21, 14, 28),
            "updated": new Date(2026, 7, 21, 14, 28)
        })
    }

    NotificationCenterView {
        anchors.fill: parent
        anchors.margins: 24
        notifications: previewNotifications
        currentDateTime: new Date(2026, 7, 21, 14, 30)
    }

    Timer {
        interval: 800
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save notification center snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
