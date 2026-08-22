import QtQuick
import QtQuick.Window
import MeoUI 1.0

Window {
    id: window

    readonly property bool compact: Qt.application.arguments.indexOf("--compact") !== -1
    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    width: compact ? 360 : 800
    height: 520
    visible: true
    color: MeoTheme.background

    MeoStatusCenter {
        anchors.fill: parent
        anchors.margins: 12 * MeoTheme.globalScale
        currentDateTime: new Date(2026, 7, 21, 22, 30)
        unreadCount: 3
        notificationContent: Component {
            Item {
                MeoText {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 240 * MeoTheme.globalScale)
                    text: qsTr("Shared notification content")
                    typeRole: "body"
                    typeSize: "medium"
                    horizontalAlignment: Text.AlignHCenter
                    color: MeoTheme.onSurfaceVariant
                }
            }
        }
    }

    Timer {
        interval: window.snapshotPath === "" ? 1 : 500
        running: true
        onTriggered: {
            if (window.snapshotPath === "") {
                console.warn("MEOUI_SHELL_COMPONENTS_OK")
                Qt.quit()
                return
            }
            window.contentItem.grabToImage(function(result) {
                if (!result.saveToFile(window.snapshotPath))
                    console.error("Unable to save MeoUI shell component snapshot", window.snapshotPath)
                Qt.quit()
            })
        }
    }
}
