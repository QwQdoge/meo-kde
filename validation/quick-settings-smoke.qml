import QtQuick
import QtQuick.Window
import "../plasmoids/org.meo.topbar/contents/ui" as Topbar
import MeoUI 1.0

// Offscreen smoke for the complete KDE-backed quick-settings hierarchy.  It
// intentionally performs no system action; device discovery, audio routing
// and notification inhibition remain user-initiated controls.
Window {
    id: window

    readonly property bool compact: Qt.application.arguments.indexOf("--compact") !== -1
    width: compact ? 320 : 480
    height: 760
    visible: true
    color: MeoTheme.background

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    Topbar.QuickSettingsCenter {
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, implicitWidth)
        height: Math.min(parent.height - 24, implicitHeight)
    }

    Timer {
        interval: 900
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save quick settings snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
