import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property bool backVisible: true
    property Component trailingContent: null
    signal backRequested()

    implicitHeight: Math.max(ShellMetrics.popupHeaderHeight, headerRow.implicitHeight)

    RowLayout {
        id: headerRow
        anchors.fill: parent
        spacing: MeoTheme.space8

        MeoIconButton {
            visible: root.backVisible
            type: "standard"
            size: "m"
            icon.name: "arrow_back"
            Accessible.name: qsTr("Back")
            onClicked: root.backRequested()
        }

        MeoIcon {
            visible: !root.backVisible && root.iconName !== ""
            icon: root.iconName
            size: 24
            color: MeoTheme.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            MeoText {
                Layout.fillWidth: true
                text: root.title
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.onSurface
                elide: Text.ElideRight
            }

            MeoText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Loader {
            sourceComponent: root.trailingContent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
