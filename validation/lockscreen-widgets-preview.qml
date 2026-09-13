// Isolated visual preview only. It has no KScreenLocker, PAM, D-Bus, network,
// or notification backend and is never installed as a lock-screen surface.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import MeoUI 1.0

Window {
    id: window

    width: 1280
    height: 720
    visible: true
    color: MeoTheme.surface

    property string snapshotPath: {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf("--snapshot=") === 0)
                return argument.substring(11)
        }
        return ""
    }

    Rectangle {
        anchors.fill: parent
        color: MeoTheme.surface

        Rectangle {
            width: 640
            height: 640
            radius: width / 2
            x: parent.width - width * 0.52
            y: -height * 0.64
            color: MeoTheme.primaryContainer
            opacity: 0.32
        }
        Rectangle {
            width: 520
            height: 520
            radius: width / 2
            x: -width * 0.58
            y: parent.height - height * 0.42
            color: MeoTheme.tertiaryContainer
            opacity: 0.26
        }
    }

    MeoText {
        anchors {
            top: parent.top
            left: parent.left
            margins: MeoTheme.space24
        }
        text: "Meo lock screen · isolated visual preview"
        typeRole: "label"
        typeSize: "medium"
        color: MeoTheme.contentOnSurfaceVariant
    }

    ColumnLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 72 * MeoTheme.globalScale
        }
        spacing: MeoTheme.space12

        MeoAmbientClock {
            Layout.alignment: Qt.AlignHCenter
            timeText: "09:41"
            dateText: "Saturday, September 13"
        }

        MeoWeatherStatus {
            Layout.alignment: Qt.AlignHCenter
            available: true
            temperatureText: "28°C"
            condition: "Partly cloudy"
            location: "Singapore"
            showLocation: false
            iconName: "weather-partly-cloudy"
        }

    }

    MeoPrivacyNotificationSummary {
        anchors {
            left: parent.left
            leftMargin: 48 * MeoTheme.globalScale
            verticalCenter: authenticationSurface.verticalCenter
        }
        width: 320 * MeoTheme.globalScale
        privacyLevel: "app-name"
        notificationCount: 2
        applicationName: "Messages"
    }

    MeoAuthenticationSurface {
        id: authenticationSurface
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 82 * MeoTheme.globalScale
        }
        width: 400 * MeoTheme.globalScale
        title: "Unlock"
        supportingText: "Authenticate to return to your session"
        status: "fingerprint"
        statusText: "Or scan your fingerprint"

        MeoTextField {
            Layout.fillWidth: true
            label: "Password"
            isPassword: true
        }
        MeoButton {
            Layout.fillWidth: true
            text: "Unlock"
            icon.name: "lock_open"
        }
    }

    MeoMediaController {
        id: mediaCard
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: MeoTheme.space24
        }
        width: 420 * MeoTheme.globalScale
        presentation: "compact"
        title: "Night Drive"
        artist: "Meo Sessions"
        sourceName: "Preview player"
        isPlaying: true
        showArtwork: false
        showVolume: false
        showSecondaryActions: false
    }

    Timer {
        interval: 700
        running: window.snapshotPath !== ""
        repeat: false
        onTriggered: window.contentItem.grabToImage(function(result) {
            if (!authenticationSurface.visible || !mediaCard.visible)
                throw new Error("Expected preview widgets did not render")
            if (!result.saveToFile(window.snapshotPath))
                throw new Error("Unable to save lock-screen widget preview")
            Qt.quit()
        })
    }
}
