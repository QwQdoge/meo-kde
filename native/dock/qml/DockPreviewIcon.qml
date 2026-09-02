import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import MeoUI 1.0

Item {
    required property string title
    required property string iconSource
    required property string iconMode
    required property bool isActive

    width: 56 * MeoTheme.globalScale
    height: width

    Rectangle {
        anchors.centerIn: parent
        width: 50 * MeoTheme.globalScale
        height: width
        radius: width / 2
        color: isActive
               ? Qt.rgba(MeoTheme.primaryContainer.r,
                         MeoTheme.primaryContainer.g,
                         MeoTheme.primaryContainer.b, 0.22)
               : "transparent"
        border.width: 0

        Kirigami.Icon {
            id: appIcon
            anchors.centerIn: parent
            width: 44 * MeoTheme.globalScale
            height: width
            source: iconSource
            active: isActive
        }


        MultiEffect {
            anchors.fill: appIcon
            source: appIcon
            visible: iconMode === "mono"
            colorization: 1.0
            colorizationColor: MeoTheme.onSurface
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 3 * MeoTheme.globalScale
            width: isActive ? 22 * MeoTheme.globalScale : 6 * MeoTheme.globalScale
            height: 3 * MeoTheme.globalScale
            radius: height / 2
            color: MeoTheme.primary
        }
    }
}
