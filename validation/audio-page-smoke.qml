import QtQuick
import QtQuick.Window
import "../plasmoids/org.meo.topbar/contents/ui" as Topbar
import MeoUI 1.0

// Verifies that the speakers/microphone route page instantiates against the
// real Meo.System PulseAudioQt bridge without changing the selected device.
Window {
    id: window

    width: 480
    height: 600
    visible: true
    color: MeoTheme.background

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    MeoMotionSurface {
        anchors.centerIn: parent
        width: parent.width - 24
        height: parent.height - 24
        color: MeoTheme.surfaceContainerLow
        radius: MeoTheme.shapeExtraLarge
        elevation: 3

        Topbar.AudioPage {
            anchors.fill: parent
            anchors.margins: MeoTheme.space16
        }
    }

    Timer {
        interval: 900
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save audio route snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
