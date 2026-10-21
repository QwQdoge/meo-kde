import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window

    width: 600
    height: 1040
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

    function mk(o) {
        const base = {
            "summary": "", "body": "", "applicationName": "", "originName": "", "iconName": "",
            "applicationIconName": "", "closable": true, "expired": false, "configurable": true,
            "hasDefaultAction": false, "hasReplyAction": false, "replyActionLabel": "",
            "replyPlaceholderText": "", "replySubmitButtonText": "", "actionNames": [],
            "actionLabels": [], "type": 1, "urgency": 1, "percentage": -1, "jobState": 0,
            "suspendable": false, "killable": false,
            "created": new Date(2026, 7, 21, 14, 20), "updated": new Date(2026, 7, 21, 14, 20)
        }
        for (const key in o) base[key] = o[key]
        previewNotifications.append(base)
    }

    Component.onCompleted: {
        // Running transfer with size, speed, remaining time and description lines.
        mk({ "summary": "Copying 128 files", "body": "to Backups", "applicationName": "Dolphin",
             "iconName": "edit-copy", "type": 2, "percentage": 62, "jobState": 1,
             "suspendable": true, "killable": true,
             "jobDetails": { "totalBytes": 4831838208, "processedBytes": 2995740049, "speed": 78643200,
                             "descriptionLabel1": "Source", "descriptionValue1": "/home/meo/Projects",
                             "descriptionLabel2": "Destination", "descriptionValue2": "/run/media/meo/Backups",
                             "effectiveDestUrl": "file:///run/media/meo/Backups", "errorText": "" } })
        // Paused transfer.
        mk({ "summary": "Extracting archive", "body": "assets.tar.zst", "applicationName": "Ark",
             "iconName": "ark", "type": 2, "percentage": 18, "jobState": 2,
             "suspendable": true, "killable": true,
             "jobDetails": { "totalBytes": 912261120, "processedBytes": 164208000, "speed": 0,
                             "descriptionLabel1": "", "descriptionValue1": "", "descriptionLabel2": "",
                             "descriptionValue2": "", "effectiveDestUrl": "file:///home/meo/Downloads", "errorText": "" } })
        // Failed transfer.
        mk({ "summary": "Could not copy file", "body": "disk image", "applicationName": "Dolphin",
             "iconName": "dialog-error", "type": 2, "percentage": 41, "jobState": 0, "jobError": 4,
             "jobDetails": { "totalBytes": 0, "processedBytes": 0, "speed": 0, "descriptionLabel1": "",
                             "descriptionValue1": "", "descriptionLabel2": "", "descriptionValue2": "",
                             "effectiveDestUrl": "", "errorText": "The destination has no space left." } })
        // Message with avatar, default action label and quick reply.
        mk({ "summary": "Mina", "body": "Are we still on for the review at 3?", "applicationName": "Telegram",
             "iconName": "telegram", "image": "user-identity", "hasDefaultAction": true,
             "defaultActionLabel": "Open chat", "hasReplyAction": true, "replyActionLabel": "Reply",
             "replyPlaceholderText": "Reply to Mina", "replySubmitButtonText": "Send",
             "desktopEntry": "org.telegram.desktop" })
        // Notification with actions and attached files.
        mk({ "summary": "Screenshot saved", "body": "Saved to Pictures/Screenshots", "applicationName": "Spectacle",
             "iconName": "spectacle", "actionNames": ["open", "folder"], "actionLabels": ["Open", "Open Containing Folder"],
             "urls": ["file:///home/meo/Pictures/Screenshots/Screenshot_20261021.png"],
             "desktopEntry": "org.kde.spectacle" })
        // No default action: clicking opens the posting application.
        mk({ "summary": "Update ready", "body": "Meo Settings 0.4 finished downloading.", "applicationName": "Meo Settings",
             "iconName": "org.meo.settings", "desktopEntry": "org.meo.settings" })
        // Critical.
        mk({ "summary": "Battery level is critical", "body": "Connect a charger to keep working.",
             "applicationName": "Power Management", "iconName": "battery-caution", "urgency": 2 })
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
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save notification center snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
