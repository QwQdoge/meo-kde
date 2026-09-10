import QtQuick
import QtQuick.Window
import MeoUI 1.0
import MeoKDE 1.0

// Runtime evidence for the DMS-style retained-content disclosure lifecycle.
Window {
    id: window

    width: 440
    height: 320
    visible: true
    color: MeoTheme.background
    readonly property bool expand: Qt.application.arguments.indexOf("--expand") !== -1
    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    MeoMotionSurface {
        anchors.fill: parent
        anchors.margins: MeoTheme.space24
        color: MeoTheme.surfaceContainerHigh
        radius: MeoTheme.shapeExtraLarge

        NotificationBodyDisclosure {
            id: disclosure
            anchors.fill: parent
            anchors.margins: MeoTheme.space16
            bodyText: "This longer notification body exercises the same retained-content lifecycle used by the notification center. The expanded projection remains alive while the card contracts, then is released after the semantic exit duration has completed."
            collapsedLines: 2
        }
    }

    Timer {
        interval: 80
        running: window.expand
        repeat: false
        onTriggered: disclosure.toggleExpanded()
    }

    Timer {
        interval: window.expand ? 700 : 350
        running: window.snapshotPath !== ""
        repeat: false
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save notification disclosure snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
