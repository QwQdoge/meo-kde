import QtQuick
import QtQuick.Layouts
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
    property bool showRunningIndicator: true
    property bool showTooltip: true

    signal clicked(var mouse)
    signal rightClicked(var mouse)

    implicitWidth: ShellMetrics.shelfItemSize
    implicitHeight: ShellMetrics.shelfItemSize
    activeFocusOnTab: title !== ""
    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: root.isLauncher
                            ? MeoI18n.translator.i18n("Open applications")
                            : (root.winCount > 1
                               ? MeoI18n.translator.i18n("%1 open windows").arg(root.winCount)
                               : MeoI18n.translator.i18n("Open application"))
    Accessible.focusable: title !== ""
    Accessible.onPressAction: root.activate()
    scale: mouseArea.pressed ? 0.94 : 1.0

    function activate() {
        root.clicked({ button: Qt.LeftButton })
    }

    Behavior on scale {
        NumberAnimation { duration: MeoMotion.press; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
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
            ColorAnimation { duration: MeoMotion.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
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
        visible: root.showRunningIndicator && !root.isLauncher && root.isRunning
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.isActive ? 16 * MeoTheme.globalScale : (root.winCount > 1 ? 12 : 8) * MeoTheme.globalScale
        height: 3 * MeoTheme.globalScale
        radius: MeoTheme.shapeFull
        color: MeoTheme.primary

        Behavior on width {
            NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
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

    MeoTooltip {
        visible: root.showTooltip && mouseArea.containsMouse && root.title !== ""
        delay: MeoTheme.motionDurationLong1
        text: root.winCount > 1
              ? root.title + "\n" + MeoI18n.translator.i18n("%1 windows").arg(root.winCount)
              : root.title
    }
}
