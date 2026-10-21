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

    // The card adapts to the cell it is given: a short cell drops the graph and
    // progress bar, a narrow one drops the subtitle, so content never spills out
    // of the card or over its neighbours.
    readonly property bool compact: height > 0 && height < 118 * MeoTheme.globalScale
    readonly property bool narrow: width > 0 && width < 230 * MeoTheme.globalScale
    readonly property bool tiny: width > 0 && width < 170 * MeoTheme.globalScale
    readonly property real inset: compact ? MeoTheme.space8 : MeoTheme.space12

    type: "filled"
    radius: MeoTheme.shapeLargeIncreased
    implicitHeight: 166 * MeoTheme.globalScale
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.inset
        spacing: root.compact ? MeoTheme.space4 : MeoTheme.space8

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            Rectangle {
                visible: !root.tiny
                Layout.preferredWidth: (root.compact ? 30 : 38) * MeoTheme.globalScale
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
                radius: (root.compact ? 10 : 13) * MeoTheme.globalScale
                color: MeoTheme.surfaceContainerHighest

                MeoIcon {
                    anchors.centerIn: parent
                    icon: root.iconName
                    size: root.compact ? 17 : 21
                    fill: true
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
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
                    visible: root.subtitle.length > 0 && !root.narrow
                    text: root.subtitle
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            Item {
                id: valueBox
                objectName: "metricValueBox"
                // The value may be a long rate such as "↓ 2.1 MiB/s". Give it
                // at most half the card; inside that box it shrinks to fit and,
                // as a last resort, elides, so it never grows over the title.
                readonly property real limit: Math.max(64 * MeoTheme.globalScale, root.width * 0.5)
                Layout.preferredWidth: Math.min(valueText.implicitWidth, limit)
                Layout.maximumWidth: limit
                Layout.preferredHeight: valueText.implicitHeight
                Layout.alignment: Qt.AlignVCenter
                clip: true

                MeoText {
                    id: valueText
                    anchors.fill: parent
                    text: root.valueText
                    typeRole: "title"
                    typeSize: root.compact ? "medium" : "large"
                    emphasized: true
                    color: MeoTheme.contentOnSurface
                    horizontalAlignment: Text.AlignRight
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        PerformanceGraph {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 46 * MeoTheme.globalScale
            visible: !root.compact
            values: root.history
            secondaryValues: root.secondaryHistory
            primaryColor: root.accentColor
            secondaryColor: root.secondaryAccentColor
            maximum: root.progressValue >= 0 ? 100 : 0
        }

        MeoProgressBar {
            Layout.fillWidth: true
            visible: root.progressValue >= 0 && !root.compact
            value: Math.max(0, Math.min(100, root.progressValue)) / 100
            activeColor: root.accentColor
            wavy: true
        }

        MeoText {
            Layout.fillWidth: true
            visible: root.detail.length > 0 && !root.compact
            text: root.detail
            typeRole: "label"
            typeSize: "small"
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
