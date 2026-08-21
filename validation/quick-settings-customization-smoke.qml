import QtQuick
import QtQuick.Window
import "../plasmoids/org.meo.topbar/contents/ui" as Topbar
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window
    width: 480
    height: 760
    visible: true
    color: MeoTheme.background

    property string mode: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--mode=") === 0)
                return argument.substring(7)
        }
        return "edit"
    }
    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    FrostedSurface {
        anchors.fill: parent
        anchors.margins: 20

        Topbar.QuickSettingsHome {
            anchors.fill: parent
            anchors.margins: 20
            editMode: window.mode === "edit"
            displayExpanded: window.mode === "advanced"
            audioExpanded: window.mode === "advanced"
            tileOrder: "bluetooth,wifi,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
            tileSizes: "bluetooth:2,wifi:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
        }
    }

    Timer {
        interval: 900
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save customization snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
