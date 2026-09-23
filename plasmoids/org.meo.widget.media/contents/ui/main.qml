pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.title: MeoI18n.translator.i18n("Meo Media")
    toolTipMainText: Plasmoid.title
    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: 320 * MeoTheme.globalScale
    Layout.minimumHeight: 148 * MeoTheme.globalScale
    Layout.preferredWidth: 720 * MeoTheme.globalScale
    Layout.preferredHeight: 300 * MeoTheme.globalScale

    fullRepresentation: Item {
        implicitWidth: 720 * MeoTheme.globalScale
        implicitHeight: 300 * MeoTheme.globalScale

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
            accessibleDescription: MeoI18n.translator.i18n("Current-session media controls")

            MeoMediaController {
                anchors.fill: parent
                anchors.margins: MeoTheme.space4
                visible: MeoSystem.Media.available
                presentation: "adaptive"
                title: MeoSystem.Media.title
                artist: MeoSystem.Media.artist
                album: MeoSystem.Media.album
                sourceName: MeoSystem.Media.playerName
                coverSource: MeoSystem.Media.remoteArtUrl !== ""
                             ? MeoSystem.Media.remoteArtUrl : MeoSystem.Media.artUrl
                isPlaying: MeoSystem.Media.playing
                duration: Number(MeoSystem.Media.durationMs)
                position: Number(MeoSystem.Media.positionMs)
                canSeek: MeoSystem.Media.canSeek
                canSkipPrevious: MeoSystem.Media.canGoPrevious
                canSkipNext: MeoSystem.Media.canGoNext
                canShuffle: MeoSystem.Media.shuffleSupported
                canRepeat: MeoSystem.Media.repeatSupported
                shuffleEnabled: MeoSystem.Media.shuffle
                repeatMode: MeoSystem.Media.repeatMode
                sourceCount: MeoSystem.Media.playerCount
                canAdjustVolume: false
                showVolume: false
                showSecondaryActions: false
                onPlayRequested: MeoSystem.Media.playPause()
                onPauseRequested: MeoSystem.Media.playPause()
                onPreviousRequested: MeoSystem.Media.previous()
                onNextRequested: MeoSystem.Media.next()
                onSeekRequested: newPosition => MeoSystem.Media.seekTo(newPosition)
                onShuffleRequested: enabled => MeoSystem.Media.setShuffle(enabled)
                onRepeatRequested: mode => MeoSystem.Media.setRepeatMode(mode)
                onPreviousSourceRequested: MeoSystem.Media.selectPreviousPlayer()
                onNextSourceRequested: MeoSystem.Media.selectNextPlayer()
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
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 72 * MeoTheme.globalScale
                        Layout.preferredHeight: 72 * MeoTheme.globalScale

                        MeoShape {
                            anchors.fill: parent
                            type: "ClamShell"
                            color: MeoTheme.primaryContainer
                        }
                        MeoIcon {
                            anchors.centerIn: parent
                            icon: "queue_music"
                            size: 30
                            color: MeoTheme.contentOnPrimaryContainer
                        }
                    }
                    MeoText { Layout.fillWidth: true; text: MeoI18n.translator.i18n("No media playing"); typeRole: "title"; typeSize: "small"; emphasized: true; horizontalAlignment: Text.AlignHCenter }
                    MeoText { Layout.fillWidth: true; text: MeoI18n.translator.i18n("Media controls appear when a current-session player is available."); typeRole: "body"; typeSize: "small"; color: MeoTheme.contentOnSurfaceVariant; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
