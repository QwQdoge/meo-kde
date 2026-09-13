import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window

    width: 360
    height: 120
    visible: true
    color: MeoTheme.background

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    TimeNotificationButton {
        anchors.centerIn: parent
        currentDateTime: new Date(2026, 7, 21, 14, 30)
        unreadCount: 3
        activeJobsCount: 1
        jobsPercentage: 68
        showDate: true
        active: true
    }

    Timer {
        interval: 500
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save time notification button snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
