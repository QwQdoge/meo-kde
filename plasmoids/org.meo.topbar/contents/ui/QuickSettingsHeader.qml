import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

RowLayout {
    id: root
    property bool editMode: false
    required property var systemState
    required property var platform
    signal resetRequested()
    signal powerRequested()
    signal editRequested()
    Layout.fillWidth: true
    spacing: MeoTheme.space4

    MeoIconButton {
        type: "standard"; size: "s"; icon.name: "edit"
        Accessible.name: MeoI18n.translator.i18n("Edit quick settings")
        onClicked: root.editRequested()
    }
    MeoIconButton {
        type: "standard"; size: "s"; icon.name: "settings"
        Accessible.name: MeoI18n.translator.i18n("Meo Settings")
        onClicked: Qt.openUrlExternally("applications:org.meo.settings.desktop")
    }
    MeoIconButton {
        visible: root.editMode
        type: "standard"; size: "s"; icon.name: "restart_alt"
        Accessible.name: MeoI18n.translator.i18n("Reset tile layout")
        onClicked: root.resetRequested()
    }
    Item { Layout.fillWidth: true }
    MeoText {
        visible: root.systemState.batteryAvailable
        text: root.systemState.batteryPercent + "%"
        typeRole: "label"; typeSize: "medium"
    }
    MeoIconButton {
        type: "standard"; size: "s"; icon.name: "lock"
        Accessible.name: MeoI18n.translator.i18n("Lock screen")
        onClicked: root.platform.lockScreen()
    }
    MeoIconButton {
        type: "standard"; size: "s"; icon.name: "power_settings_new"
        Accessible.name: MeoI18n.translator.i18n("Power")
        onClicked: root.powerRequested()
    }
}
