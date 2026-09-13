pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

PlasmoidItem {
    id: root

    Plasmoid.title: qsTr("Meo Media")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: 280 * MeoTheme.globalScale
    Layout.minimumHeight: 132 * MeoTheme.globalScale
    Layout.preferredWidth: 384 * MeoTheme.globalScale
    Layout.preferredHeight: 176 * MeoTheme.globalScale

    fullRepresentation: Item {
        implicitWidth: 384 * MeoTheme.globalScale
        implicitHeight: 176 * MeoTheme.globalScale

        MeoWidget {
            anchors.fill: parent
            widgetId: "media"
            preferredSize: MeoWidget.SizeLarge
            supportedSizes: [MeoWidget.SizeWide, MeoWidget.SizeMedium,
                             MeoWidget.SizeLarge]
            privacy: MeoWidget.Media
            refreshPolicy: MeoWidget.EventDriven
            supportedSurfaces: [MeoWidget.Desktop, MeoWidget.LockScreen]
            frameMode: MeoWidget.Adaptive
            wantsOwnBackground: true
            accessibleName: Plasmoid.title
            accessibleDescription: qsTr("Current-session media controls")

            MeoMediaController {
                anchors.fill: parent
                anchors.margins: MeoTheme.space4
                visible: MeoSystem.Media.available
                presentation: "compact"
                title: MeoSystem.Media.title
                artist: MeoSystem.Media.artist
                sourceName: MeoSystem.Media.playerName
                coverSource: MeoSystem.Media.artUrl
                isPlaying: MeoSystem.Media.playing
                canSeek: false
                canSkipPrevious: MeoSystem.Media.canGoPrevious
                canSkipNext: MeoSystem.Media.canGoNext
                canAdjustVolume: false
                showVolume: false
                showSecondaryActions: false
                onPlayRequested: MeoSystem.Media.playPause()
                onPauseRequested: MeoSystem.Media.playPause()
                onPreviousRequested: MeoSystem.Media.previous()
                onNextRequested: MeoSystem.Media.next()
            }

            MeoCard {
                anchors.fill: parent
                visible: !MeoSystem.Media.available
                type: "filled"
                radius: MeoTheme.dialogRadius

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 2 * MeoTheme.space24
                    spacing: MeoTheme.space8
                    MeoIcon { Layout.alignment: Qt.AlignHCenter; icon: "music_off"; size: 28; color: MeoTheme.contentOnSurfaceVariant }
                    MeoText { Layout.fillWidth: true; text: qsTr("No media playing"); typeRole: "title"; typeSize: "small"; emphasized: true; horizontalAlignment: Text.AlignHCenter }
                    MeoText { Layout.fillWidth: true; text: qsTr("Media controls appear when a current-session player is available."); typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
