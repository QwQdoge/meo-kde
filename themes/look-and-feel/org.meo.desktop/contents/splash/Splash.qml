import QtQuick
import MeoUI

// Plasma owns the startup stages. This theme is deliberately visual only: it
// never claims that a service or account is ready before Plasma reaches it.
Rectangle {
    id: root
    color: MeoTheme.surface
    property int stage

    Image {
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/MeoArch/installer_background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(MeoTheme.scrim.r, MeoTheme.scrim.g, MeoTheme.scrim.b, 0.18) }

    Column {
        anchors.centerIn: parent
        spacing: 18 * MeoTheme.globalScale

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "file:///usr/share/pixmaps/meoarch-logo.svg"
            width: 192 * MeoTheme.globalScale
            height: 72 * MeoTheme.globalScale
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Preparing your desktop")
            color: MeoTheme.contentOnSurface
            font.family: MeoTheme.typefacePlain
            font.pixelSize: MeoTheme.titleLarge.size * MeoTheme.globalScale
            Accessible.name: text
        }

        MeoLoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44 * MeoTheme.globalScale
            height: width
            running: root.stage < 5
            indeterminate: true
            color: MeoTheme.primary
        }
    }
}
