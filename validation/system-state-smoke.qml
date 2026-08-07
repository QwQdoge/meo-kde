import QtQuick
import QtQuick.Window
import Meo.System 1.0

Window {
    width: 1
    height: 1
    visible: true
    Timer {
        interval: 1000
        running: true
        onTriggered: {
            console.warn("MEO_SYSTEM_STATE",
                    "networkAvailable=" + SystemState.networkAvailable,
                    "networkConnected=" + SystemState.networkConnected,
                    "wirelessEnabled=" + SystemState.wirelessEnabled,
                    "networkName=" + SystemState.networkName,
                    "bluetoothAvailable=" + SystemState.bluetoothAvailable,
                    "bluetoothEnabled=" + SystemState.bluetoothEnabled,
                    "batteryAvailable=" + SystemState.batteryAvailable,
                    "batteryPercent=" + SystemState.batteryPercent,
                    "audioAvailable=" + SystemState.audioAvailable,
                    "volumePercent=" + SystemState.volumePercent,
                    "audioDevice=" + SystemState.audioDevice)
            Qt.quit()
        }
    }
}
