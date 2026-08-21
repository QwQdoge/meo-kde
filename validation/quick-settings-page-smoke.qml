import QtQuick
import QtQuick.Window
import "../plasmoids/org.meo.topbar/contents/ui" as Topbar
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window

    width: 480
    height: 600
    visible: true
    color: MeoTheme.background

    property string pageName: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--page=") === 0)
                return argument.substring(7)
        }
        return "wifi"
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

        Loader {
            anchors.fill: parent
            anchors.margins: ShellMetrics.popupContentMargin
            sourceComponent: window.pageName === "bluetooth" ? bluetoothPage
                             : window.pageName === "audio" ? audioPage
                             : window.pageName === "power" ? powerPage : wifiPage
        }
    }

    Component { id: wifiPage; Topbar.WifiPage {} }
    Component { id: bluetoothPage; Topbar.BluetoothPage {} }
    Component { id: audioPage; Topbar.AudioPage {} }
    Component { id: powerPage; Topbar.PowerPage {} }

    Timer {
        interval: 700
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save quick-settings page snapshot", window.snapshotPath)
            Qt.quit()
        })
    }
}
