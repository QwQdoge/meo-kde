import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

    property string iconName: ""
    property string title: ""
    property string description: ""
    property string actionText: ""
    signal actionRequested()

    implicitHeight: emptyColumn.implicitHeight + 2 * MeoTheme.space16

    ColumnLayout {
        id: emptyColumn
        anchors.centerIn: parent
        width: Math.min(parent.width, 320 * MeoTheme.globalScale)
        spacing: MeoTheme.space8

        MeoIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.iconName !== ""
            icon: root.iconName
            size: 36
            color: MeoTheme.onSurfaceVariant
        }

        MeoText {
            Layout.fillWidth: true
            text: root.title
            typeRole: "title"
            typeSize: "small"
            emphasized: true
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.onSurface
            wrapMode: Text.WordWrap
        }

        MeoText {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            typeRole: "body"
            typeSize: "small"
            horizontalAlignment: Text.AlignHCenter
            color: MeoTheme.onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        MeoButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: MeoTheme.space4
            visible: root.actionText !== ""
            type: "tonal"
            size: "s"
            text: root.actionText
            onClicked: root.actionRequested()
        }
    }
}
