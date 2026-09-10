import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

// Action presentation only. The host retains configuration mutation and all
// page navigation so the existing plasmoid contracts remain unchanged.
RowLayout {
    id: root

    property bool editMode: false
    required property var platform
    signal resetRequested()
    signal powerRequested()
    signal editRequested()

    Layout.fillWidth: true
    Item { Layout.fillWidth: true }
    MeoIconButton {
        visible: root.editMode
        type: "standard"; size: "m"; icon.name: "restart_alt"
        Accessible.name: qsTr("Reset tile layout")
        onClicked: root.resetRequested()
    }
    MeoIconButton { type: "standard"; size: "m"; icon.name: "lock"; Accessible.name: qsTr("Lock screen"); onClicked: root.platform.lockScreen() }
    MeoIconButton {
        type: "standard"; size: "m"; icon.name: "settings"
        Accessible.name: qsTr("Meo Settings")
        onClicked: Qt.openUrlExternally("applications:org.meo.settings.desktop")
    }
    MeoIconButton { type: "standard"; size: "m"; icon.name: "power_settings_new"; Accessible.name: qsTr("Power"); onClicked: root.powerRequested() }
    MeoIconButton {
        type: "standard"; size: "m"; icon.name: "edit"
        Accessible.name: qsTr("Edit quick settings")
        onClicked: root.editRequested()
    }
}
