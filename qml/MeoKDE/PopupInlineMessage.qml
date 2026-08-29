import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

MeoMotionSurface {
    id: root

    property string text: ""
    property string tone: "error"
    property bool dismissible: false
    signal dismissed()

    visible: text !== ""
    implicitHeight: messageRow.implicitHeight + 2 * MeoTheme.space12
    radius: ShellMetrics.radiusControl
    color: tone === "error" ? MeoTheme.errorContainer
          : tone === "warning" ? MeoTheme.tertiaryContainer
          : MeoTheme.secondaryContainer
    elevation: 0

    RowLayout {
        id: messageRow
        anchors.fill: parent
        anchors.margins: MeoTheme.space12
        spacing: MeoTheme.space8

        MeoIcon {
            icon: root.tone === "error" ? "error"
                  : root.tone === "warning" ? "warning" : "info"
            size: 20
            color: root.tone === "error" ? MeoTheme.onErrorContainer
                  : root.tone === "warning" ? MeoTheme.onTertiaryContainer
                  : MeoTheme.onSecondaryContainer
        }

        MeoText {
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.PlainText
            typeRole: "body"
            typeSize: "small"
            color: root.tone === "error" ? MeoTheme.onErrorContainer
                  : root.tone === "warning" ? MeoTheme.onTertiaryContainer
                  : MeoTheme.onSecondaryContainer
            wrapMode: Text.WordWrap
        }

        MeoIconButton {
            visible: root.dismissible
            type: "standard"
            size: "s"
            icon.name: "close"
            Accessible.name: qsTr("Dismiss message")
            onClicked: root.dismissed()
        }
    }
}
