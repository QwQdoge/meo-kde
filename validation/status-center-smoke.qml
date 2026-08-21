import QtQuick
import QtQuick.Window
import "../plasmoids/org.meo.timecenter/contents/ui" as TimeCenter
import MeoUI 1.0

Window {
    id: window

    width: 900
    height: 580
    visible: true
    color: MeoTheme.background

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    TimeCenter.TimeNotificationCenter {
        anchors.centerIn: parent
        width: 820
        height: 540
        notifications: null
        currentDateTime: new Date(2026, 7, 18, 17, 28)
        use24HourClock: true
    }

    Timer {
        interval: 700
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save status center snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
