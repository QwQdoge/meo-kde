import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

MeoCard {
    id: root

    property string title: ""
    property string iconName: "monitoring"
    property string valueText: ""
    property string subtitle: ""
    property string detail: ""
    property real progressValue: -1
    property var history: []
    property var secondaryHistory: []
    property color accentColor: MeoTheme.primary
    property color secondaryAccentColor: MeoTheme.tertiary

    type: "filled"
    radius: MeoTheme.cardRadius
    implicitHeight: 154 * MeoTheme.globalScale

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: MeoTheme.space12
        spacing: MeoTheme.space8

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoIcon {
                icon: root.iconName
                size: 22
                color: root.accentColor
            }

            MeoText {
                Layout.fillWidth: true
                text: root.title
                typeRole: "label"
                typeSize: "large"
                emphasized: true
                color: MeoTheme.contentOnSurfaceVariant
            }

            MeoText {
                text: root.valueText
                typeRole: "title"
                typeSize: "medium"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
        }

        PerformanceGraph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 42 * MeoTheme.globalScale
            values: root.history
            secondaryValues: root.secondaryHistory
            primaryColor: root.accentColor
            secondaryColor: root.secondaryAccentColor
            maximum: root.progressValue >= 0 ? 100 : 0
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: root.progressValue >= 0
            value: Math.max(0, Math.min(100, root.progressValue)) / 100
            activeColor: root.accentColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoText {
                Layout.fillWidth: true
                text: root.subtitle
                typeRole: "body"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
                elide: Text.ElideRight
            }
            MeoText {
                visible: root.detail.length > 0
                text: root.detail
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.contentOnSurfaceVariant
            }
        }
    }
}
