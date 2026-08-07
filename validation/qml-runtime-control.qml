import QtQuick
import QtQuick.Window

Window {
    visible: true
    width: 1
    height: 1
    Timer {
        interval: 250
        running: true
        onTriggered: {
            console.warn("QML_RUNTIME_CONTROL_OK")
            Qt.quit()
        }
    }
}
