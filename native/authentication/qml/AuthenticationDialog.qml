import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: root

    property var backend: null

    width: Math.round(480 * MeoTheme.globalScale)
    height: Math.round(Math.max(480 * MeoTheme.globalScale,
                               content.implicitHeight + 48 * MeoTheme.globalScale))
    minimumWidth: Math.round(360 * MeoTheme.globalScale)
    maximumWidth: Math.round(560 * MeoTheme.globalScale)
    visible: root.backend && root.backend.inProgress
    modality: Qt.ApplicationModal
    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: qsTr("Authentication required")

    function submit() {
        if (!root.backend || root.backend.busy || responseField.text.length === 0)
            return
        const response = responseField.text
        responseField.clear()
        responseField.passwordVisible = false
        root.backend.submitResponse(response)
    }

    Component.onCompleted: if (root.backend) root.backend.setDialogWindow(root)
    onVisibleChanged: {
        if (visible)
            responseField.forceActiveFocus(Qt.PopupFocusReason)
    }
    onClosing: function(close) {
        if (root.backend && root.backend.inProgress) {
            close.accepted = false
            root.backend.cancel()
        }
    }

    Connections {
        target: root.backend
        function onClearResponseRequested() {
            responseField.clear()
            responseField.passwordVisible = false
        }
        function onFocusResponseRequested() {
            responseField.forceActiveFocus(Qt.PopupFocusReason)
        }
    }

    FrostedSurface {
        anchors.fill: parent
        baseColor: MeoTheme.surfaceContainerLow
        radius: ShellMetrics.radiusPopup

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: MeoTheme.space24
            spacing: MeoTheme.space16

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space16

                MeoMotionSurface {
                    Layout.preferredWidth: 56 * MeoTheme.globalScale
                    Layout.preferredHeight: Layout.preferredWidth
                    color: MeoTheme.primaryContainer
                    radius: width / 2
                    elevation: 0

                    MeoIcon {
                        anchors.centerIn: parent
                        icon: "admin_panel_settings"
                        size: 28
                        color: MeoTheme.onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space2

                    MeoText {
                        Layout.fillWidth: true
                        text: qsTr("Authentication required")
                        typeRole: "title"
                        typeSize: "medium"
                        emphasized: true
                        color: MeoTheme.onSurface
                        wrapMode: Text.WordWrap
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.backend ? root.backend.requesterLabel : ""
                        typeRole: "label"
                        typeSize: "medium"
                        color: MeoTheme.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                MeoIconButton {
                    type: "standard"
                    size: "s"
                    icon.name: "close"
                    Accessible.name: qsTr("Cancel authorization")
                    onClicked: if (root.backend) root.backend.cancel()
                }
            }

            MeoMotionSurface {
                Layout.fillWidth: true
                implicitHeight: requestContent.implicitHeight + 2 * MeoTheme.space16
                color: MeoTheme.surfaceContainerHigh
                radius: MeoTheme.shapeLargeIncreased
                elevation: 0

                ColumnLayout {
                    id: requestContent
                    anchors.fill: parent
                    anchors.margins: MeoTheme.space16
                    spacing: MeoTheme.space8

                    MeoText {
                        Layout.fillWidth: true
                        text: root.backend && root.backend.message !== ""
                              ? root.backend.message
                              : qsTr("An application is requesting permission to change system settings.")
                        textFormat: Text.PlainText
                        typeRole: "body"
                        typeSize: "large"
                        emphasized: true
                        wrapMode: Text.WordWrap
                        color: MeoTheme.onSurface
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: root.backend ? root.backend.actionId : ""
                        textFormat: Text.PlainText
                        typeRole: "label"
                        typeSize: "small"
                        wrapMode: Text.WrapAnywhere
                        color: MeoTheme.onSurfaceVariant
                        Accessible.name: qsTr("Permission identifier: %1").arg(text)
                    }
                }
            }

            MeoExposedDropdown {
                visible: root.backend && root.backend.identities.length > 1
                Layout.fillWidth: true
                label: qsTr("Authenticate as")
                model: root.backend ? root.backend.identities : []
                currentIndex: root.backend ? root.backend.selectedIdentityIndex : -1
                enabled: root.backend && !root.backend.busy
                onSelected: function(index, value) {
                    root.backend.selectIdentity(index)
                }
            }

            PopupInlineMessage {
                Layout.fillWidth: true
                text: root.backend ? root.backend.errorText : ""
                tone: "error"
                Accessible.role: Accessible.AlertMessage
                Accessible.name: text
            }

            PopupInlineMessage {
                Layout.fillWidth: true
                text: root.backend ? root.backend.infoText : ""
                tone: "info"
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            MeoTextField {
                id: responseField
                visible: root.backend && root.backend.prompt !== "" && !root.backend.busy
                Layout.fillWidth: true
                type: "outlined"
                label: root.backend && root.backend.prompt !== "" ? root.backend.prompt : qsTr("Password")
                isPassword: !root.backend || !root.backend.echoResponse
                leadingIcon: root.backend && root.backend.echoResponse ? "person" : "key"
                helperText: root.backend && root.backend.echoResponse
                            ? qsTr("Enter the requested value.")
                            : qsTr("Your password is sent only to the system authentication service.")
                Accessible.name: label
                Accessible.description: helperText
                onAccepted: root.submit()
            }

            RowLayout {
                visible: root.backend && root.backend.busy
                Layout.fillWidth: true
                spacing: MeoTheme.space12

                MeoLoadingIndicator {
                    size: "s"
                    running: root.backend && root.backend.busy
                }
                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("Waiting for the system authentication service…")
                    typeRole: "body"
                    typeSize: "medium"
                    color: MeoTheme.onSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space8

                MeoText {
                    visible: root.backend && root.backend.attemptsRemaining < 3
                    Layout.fillWidth: true
                    text: qsTr("%1 attempt(s) remaining").arg(root.backend ? root.backend.attemptsRemaining : 0)
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.error
                }
                Item { visible: !root.backend || root.backend.attemptsRemaining >= 3; Layout.fillWidth: true }
                MeoButton {
                    type: "text"
                    size: "s"
                    text: qsTr("Cancel")
                    onClicked: if (root.backend) root.backend.cancel()
                }
                MeoButton {
                    type: "filled"
                    size: "s"
                    text: qsTr("Authenticate")
                    loading: root.backend && root.backend.busy
                    enabled: root.backend && !root.backend.busy && responseField.text.length > 0
                    onClicked: root.submit()
                }
            }
        }
    }
}
