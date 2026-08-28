import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

Window {
    id: window
    width: 1366
    height: 768
    visible: true
    title: "Meo KDE MD3 Showcase"
    color: MeoTheme.background

    property string snapshotPath: {
        for (let argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }
    property bool launcherOpen: true
    property bool quickSettingsOpen: true

    FontLoader { id: roboto; source: Qt.resolvedUrl("../assets/fonts/Roboto-Regular.ttf") }
    FontLoader { id: robotoMedium; source: Qt.resolvedUrl("../assets/fonts/Roboto-Medium.ttf") }
    FontLoader { id: comfortaa; source: Qt.resolvedUrl("../assets/fonts/Comfortaa-Bold.ttf") }

    Component.onCompleted: {
        MeoTheme.isDarkMode = false
        MeoTheme.fontFamily = roboto.name
        MeoTheme.fontFamilyBrand = comfortaa.name
        const scheme = JSON.parse(JSON.stringify(MeoTheme.fallbackLightColorScheme))
        const showcaseOverrides = {
            "primary": "#9b405f", "onPrimary": "#ffffff",
            "primaryContainer": "#ffd9e2", "onPrimaryContainer": "#3f001c",
            "secondary": "#76565e", "onSecondary": "#ffffff",
            "secondaryContainer": "#ffd9e2", "onSecondaryContainer": "#2c151b",
            "tertiary": "#7c5635", "onTertiary": "#ffffff",
            "tertiaryContainer": "#ffdcc0", "onTertiaryContainer": "#2e1500",
            "background": "#fff8f8", "onBackground": "#22191b",
            "surface": "#fff8f8", "onSurface": "#22191b",
            "surfaceVariant": "#f3dde1", "onSurfaceVariant": "#514347",
            "outline": "#837377", "outlineVariant": "#d6c2c6",
            "surfaceContainerLowest": "#ffffff", "surfaceContainerLow": "#fff0f2",
            "surfaceContainer": "#fcebed", "surfaceContainerHigh": "#f7e5e8",
            "surfaceContainerHighest": "#f1dfe2",
            "error": "#ba1a1a", "onError": "#ffffff",
            "errorContainer": "#ffdad6", "onErrorContainer": "#410002",
            "inverseSurface": "#382e30", "onInverseSurface": "#ffedef",
            "surfaceTint": "#9b405f", "inversePrimary": "#ffb1c8"
        }
        for (const role in showcaseOverrides)
            scheme[role] = showcaseOverrides[role]
        MeoTheme.applyDynamicColorScheme(scheme, "meo-kde-showcase")
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/wallpapers/installer_background.png")
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: MeoTheme.background
        opacity: 0.12
    }

    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: ShellMetrics.topBarHeight
        color: MeoTheme.surfaceContainerLow
        opacity: 0.94
        border.color: MeoTheme.outlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 12

            Text {
                text: "Meo"
                color: MeoTheme.primary
                font.family: MeoTheme.fontFamilyBrand
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                text: "Desktop Showcase"
                color: MeoTheme.onSurface
                font.family: MeoTheme.fontFamily
                font.pixelSize: 14
            }
            Item { Layout.fillWidth: true }
            Text { text: "◉  󰖩  󰕾  󰂄"; color: MeoTheme.onSurfaceVariant; font.family: MeoTheme.fontFamily; font.pixelSize: 15 }
            Rectangle {
                implicitWidth: clock.implicitWidth + 24
                implicitHeight: 32
                radius: height / 2
                color: MeoTheme.primaryContainer
                Text {
                    id: clock
                    anchors.centerIn: parent
                    text: "17:28"
                    color: MeoTheme.onPrimaryContainer
                    font.family: MeoTheme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    Rectangle {
        id: launcher
        visible: window.launcherOpen
        x: 30
        y: 76
        width: 430
        height: 530
        radius: ShellMetrics.radiusPopup
        color: MeoTheme.surfaceContainer
        border.color: MeoTheme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            Text { text: "Apps"; font.family: MeoTheme.fontFamilyBrand; font.pixelSize: 28; color: MeoTheme.onSurface }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: height / 2
                color: MeoTheme.surfaceContainerHighest
                border.color: MeoTheme.outlineVariant
                Text { anchors.centerIn: parent; text: "Search apps, files and settings"; color: MeoTheme.onSurfaceVariant; font.family: MeoTheme.fontFamily; font.pixelSize: 14 }
            }
            Text { text: "Pinned"; font.family: MeoTheme.fontFamily; font.pixelSize: 14; font.bold: true; color: MeoTheme.onSurfaceVariant }
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: ["Files", "OmniStore", "Settings", "Browser", "Photos", "Music", "Terminal", "Discover"]
                    delegate: Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 78
                        radius: ShellMetrics.radiusLarge
                        color: index === 1 ? MeoTheme.primaryContainer : MeoTheme.surfaceContainerHigh
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: ["▣", "◆", "⚙", "◎", "▧", "♪", ">_", "✦"][index]; color: index === 1 ? MeoTheme.onPrimaryContainer : MeoTheme.primary; font.pixelSize: 24 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData; color: MeoTheme.onSurface; font.family: MeoTheme.fontFamily; font.pixelSize: 12 }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
            Text { text: "All apps"; color: MeoTheme.primary; font.family: MeoTheme.fontFamily; font.pixelSize: 14; font.bold: true }
        }
    }

    Rectangle {
        visible: window.quickSettingsOpen
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: topBar.bottom
        anchors.topMargin: 18
        width: 330
        height: 310
        radius: ShellMetrics.radiusPopup
        color: MeoTheme.surfaceContainer
        border.color: MeoTheme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            Text { text: "17:28"; font.family: MeoTheme.fontFamilyBrand; font.pixelSize: 28; color: MeoTheme.onSurface }
            Text { text: "Sunday, August 2"; font.family: MeoTheme.fontFamily; font.pixelSize: 14; color: MeoTheme.onSurfaceVariant }
            RowLayout {
                spacing: 10
                Repeater {
                    model: ["Wi-Fi", "Bluetooth"]
                    delegate: Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: height / 2
                        color: index === 0 ? MeoTheme.primaryContainer : MeoTheme.surfaceContainerHighest
                        Text { anchors.centerIn: parent; text: modelData; font.family: MeoTheme.fontFamily; font.pixelSize: 14; font.bold: true; color: index === 0 ? MeoTheme.onPrimaryContainer : MeoTheme.onSurfaceVariant }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: height / 2
                color: MeoTheme.surfaceContainerHighest
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * 0.72; radius: parent.radius; color: MeoTheme.primaryContainer }
                Text { anchors.centerIn: parent; text: "Volume 72%"; font.family: MeoTheme.fontFamily; font.pixelSize: 13; color: MeoTheme.onPrimaryContainer }
            }
            Item { Layout.fillHeight: true }
            Text { Layout.alignment: Qt.AlignRight; text: "Settings   Power"; font.family: MeoTheme.fontFamily; font.pixelSize: 13; color: MeoTheme.primary }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: 530
        height: ShellMetrics.shelfSurfaceHeight
        radius: height / 2
        color: MeoTheme.surfaceContainer
        border.color: MeoTheme.outlineVariant
        Row {
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: ["Meo", "Files", "Browser", "OmniStore", "Settings", "Terminal"]
                delegate: Rectangle {
                    required property string modelData
                    width: ShellMetrics.shelfItemSize
                    height: ShellMetrics.shelfItemSize
                    radius: height / 2
                    color: index === 3 ? MeoTheme.primaryContainer : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.substring(0, 1); color: index === 3 ? MeoTheme.onPrimaryContainer : MeoTheme.primary; font.family: index === 0 ? MeoTheme.fontFamilyBrand : MeoTheme.fontFamily; font.pixelSize: 18; font.bold: true }
                }
            }
        }
    }

    Timer {
        interval: 700
        running: window.snapshotPath !== ""
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(window.snapshotPath))
                console.error("Unable to save showcase to", window.snapshotPath)
            Qt.quit()
        })
    }
}
