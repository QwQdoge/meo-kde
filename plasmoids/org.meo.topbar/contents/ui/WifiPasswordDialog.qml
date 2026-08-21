import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0

QQC2.Popup {
    id: root
    property string ssid: ""
    signal accepted(string password)
    width: Math.min(320 * MeoTheme.globalScale, parent ? parent.width - 32 * MeoTheme.globalScale : 320)
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    background: FrostedSurface {}
    onOpened: {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }
    contentItem: ColumnLayout {
        spacing: MeoTheme.space16
        MeoText {
            Layout.fillWidth: true
            text: qsTr("Connect to %1").arg(root.ssid)
            typeRole: "title"
            typeSize: "medium"
            emphasized: true
            color: MeoTheme.onSurface
            wrapMode: Text.WordWrap
        }
        MeoTextField {
            id: passwordField
            Layout.fillWidth: true
            type: "outlined"
            label: qsTr("Password")
            isPassword: true
            leadingIcon: "key"
            Keys.onReturnPressed: {
                if (text.length > 0) {
                    root.accepted(text)
                    root.close()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            MeoButton { type: "text"; size: "s"; text: qsTr("Cancel"); onClicked: root.close() }
            MeoButton {
                type: "filled"
                size: "s"
                text: qsTr("Connect")
                enabled: passwordField.text.length > 0
                onClicked: {
                    root.accepted(passwordField.text)
                    root.close()
                }
            }
        }
    }
}
