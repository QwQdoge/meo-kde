import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import MeoUI 1.0
import MeoKDE 1.0

Item {
    id: root

    property string iconName: ""
    property var iconSource: null
    property string title: ""
    property bool isLauncher: false
    property bool isRunning: false
    property bool isActive: false
    property int winCount: 1
    property bool isPinned: false

    signal clicked(var mouse)
    signal rightClicked(var mouse)

    implicitWidth: ShellMetrics.shelfItemSize
    implicitHeight: ShellMetrics.shelfItemSize
    scale: mouseArea.pressed ? 0.94 : 1.0

    Behavior on scale {
        NumberAnimation { duration: MeoMotion.press; easing.type: Easing.OutCubic }
    }

    // Active / hover container.  The launcher itself keeps its Meo logo while
    // individual applications retain their native brand icon; shell controls
    // elsewhere use Material Symbols Rounded.
    Rectangle {
        id: bgContainer

        anchors.centerIn: parent
        width: ShellMetrics.shelfItemSize
        height: ShellMetrics.shelfItemSize
        radius: ShellMetrics.radiusMedium

        color: {
            if (root.isActive) {
                return MeoTheme.primaryContainer
            }
            if (mouseArea.pressed) {
                return MeoTheme.primaryContainer
            }
            if (mouseArea.containsMouse) {
                return MeoTheme.surfaceContainerHighest
            }
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: MeoMotion.hover; easing.type: Easing.OutCubic }
        }

        // Icon representation
        Item {
            anchors.centerIn: parent
            width: ShellMetrics.shelfIconSize
            height: ShellMetrics.shelfIconSize

            Kirigami.Icon {
                anchors.fill: parent
                source: root.isLauncher ? Qt.resolvedUrl("../images/meoarch-logo.svg")
                                        : (root.iconName !== "" ? root.iconName
                                                               : (root.iconSource ? root.iconSource : "application-x-executable"))
            }
        }
    }

    // Running indicator (Pill / Dot)
    Rectangle {
        id: runningDot
        visible: !root.isLauncher && root.isRunning
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.isActive ? 16 * MeoTheme.globalScale : (root.winCount > 1 ? 12 : 8) * MeoTheme.globalScale
        height: 3 * MeoTheme.globalScale
        radius: MeoTheme.shapeFull
        color: MeoTheme.primary

        Behavior on width {
            NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked(mouse)
            } else {
                root.clicked(mouse)
            }
        }
    }

    // M3 Formatted Tooltip (Radius 12px, surfaceContainerHighest, 450ms delay)
    QQC2.ToolTip {
        id: itemToolTip
        visible: mouseArea.containsMouse && root.title !== ""
        delay: 450
        text: root.winCount > 1 ? (root.title + "\n" + root.winCount + " windows") : root.title

        contentItem: Text {
            text: itemToolTip.text
            font.family: MeoTheme.fontFamily
            font.pixelSize: 12 * MeoTheme.globalScale * MeoTheme.fontScale
            font.weight: Font.Medium
            color: MeoTheme.onSurface
        }

        background: Rectangle {
            color: MeoTheme.surfaceContainerHighest
            radius: MeoTheme.shapeMedium
            border.color: MeoTheme.outlineVariant
            border.width: ShellMetrics.panelOutlineWidth
        }
    }
}
