import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

MeoMotionPopup {
    id: root
    property string ssid: ""
    property bool busy: false
    property bool connected: false
    property string errorText: ""
    signal accepted(string password)

    function submit() {
        if (root.busy || passwordField.text.length === 0)
            return
        const password = passwordField.text
        passwordField.clear()
        passwordField.passwordVisible = false
        root.accepted(password)
    }

    width: Math.min(320 * MeoTheme.globalScale, parent ? parent.width - 32 * MeoTheme.globalScale : 320)
    presentation: MeoMotionPopup.Dialog
    surfaceRadius: ShellMetrics.radiusPopup
    surfaceColor: MeoTheme.surfaceContainerLow
    initialFocusItem: passwordField
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    onOpened: {
        passwordField.clear()
        passwordField.passwordVisible = false
        passwordField.forceActiveFocus()
    }
    onClosed: {
        passwordField.clear()
        passwordField.passwordVisible = false
    }
    onConnectedChanged: if (root.connected && !root.busy && root.opened) root.close()
    onBusyChanged: if (root.connected && !root.busy && root.opened) root.close()
    contentItem: ColumnLayout {
        spacing: MeoTheme.space16

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space12

            MeoMotionSurface {
                Layout.preferredWidth: 44 * MeoTheme.globalScale
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: MeoTheme.primaryContainer
                elevation: 0

                MeoIcon {
                    anchors.centerIn: parent
                    icon: "wifi_lock"
                    size: 22
                    color: MeoTheme.onPrimaryContainer
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("Connect to %1").arg(root.ssid)
                    textFormat: Text.PlainText
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.onSurface
                    wrapMode: Text.WordWrap
                }
                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("This network requires a password.")
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.onSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
            MeoIconButton {
                type: "standard"
                size: "s"
                icon.name: "close"
                enabled: !root.busy
                Accessible.name: qsTr("Cancel connection")
                onClicked: root.close()
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: root.errorText
            tone: "error"
        }

        MeoTextField {
            id: passwordField
            Layout.fillWidth: true
            type: "outlined"
            label: qsTr("Password")
            isPassword: true
            leadingIcon: "key"
            helperText: qsTr("The password is saved by NetworkManager only after the connection succeeds.")
            enabled: !root.busy
            Accessible.description: helperText
            onAccepted: root.submit()
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            MeoButton {
                type: "text"
                size: "s"
                text: qsTr("Cancel")
                enabled: !root.busy
                onClicked: root.close()
            }
            MeoButton {
                type: "filled"
                size: "s"
                text: qsTr("Connect")
                loading: root.busy
                enabled: !root.busy && passwordField.text.length > 0
                onClicked: root.submit()
            }
        }
    }
}
