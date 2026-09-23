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
    radius: MeoTheme.shapeLargeIncreased
    implicitHeight: 166 * MeoTheme.globalScale

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: MeoTheme.space12
        spacing: MeoTheme.space8

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            Rectangle {
                width: 38 * MeoTheme.globalScale
                height: width
                radius: 13 * MeoTheme.globalScale
                color: MeoTheme.surfaceContainerHighest

                MeoIcon {
                    anchors.centerIn: parent
                    icon: root.iconName
                    size: 21
                    fill: true
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    Layout.fillWidth: true
                    text: root.title
                    typeRole: "label"
                    typeSize: "large"
                    emphasized: true
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }

                MeoText {
                    Layout.fillWidth: true
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            MeoText {
                text: root.valueText
                typeRole: "title"
                typeSize: "large"
                emphasized: true
                color: MeoTheme.contentOnSurface
            }
        }

        PerformanceGraph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 46 * MeoTheme.globalScale
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

        MeoText {
            Layout.fillWidth: true
            visible: root.detail.length > 0
            text: root.detail
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
