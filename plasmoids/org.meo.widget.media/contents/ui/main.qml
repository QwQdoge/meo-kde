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

    Layout.minimumWidth: 280 * MeoTheme.globalScale
    Layout.minimumHeight: 132 * MeoTheme.globalScale
    Layout.preferredWidth: 520 * MeoTheme.globalScale
    Layout.preferredHeight: 232 * MeoTheme.globalScale

    fullRepresentation: Item {
        implicitWidth: 520 * MeoTheme.globalScale
        implicitHeight: 232 * MeoTheme.globalScale

        MeoWidget {
            id: widget
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
                title: MeoSystem.Media.title !== "" ? MeoSystem.Media.title : MeoSystem.Media.playerName
                artist: MeoSystem.Media.artist !== "" ? MeoSystem.Media.artist : MeoSystem.Media.playerName
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
                // Keep small/wide spans glanceable like Android/Googlebook
                // widgets. Secondary controls progressively appear only when
                // the user grants the widget more Home-screen space.
                showSourceSwitcher: widget.currentColumns >= 4
                canAdjustVolume: false
                showVolume: false
                showSecondaryActions: widget.expandedLayout
                enabled: MeoSystem.Media.controllable
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
                radius: MeoTheme.cardRadius

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 2 * (widget.compactLayout ? MeoTheme.space12 : MeoTheme.space24)
                    spacing: widget.compactLayout ? MeoTheme.space4 : MeoTheme.space8
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: (widget.compactLayout ? 52 : 64) * MeoTheme.globalScale
                        Layout.preferredHeight: Layout.preferredWidth

                        MeoShape {
                            anchors.fill: parent
                            type: "ClamShell"
                            color: MeoTheme.primaryContainer
                        }
                        MeoIcon {
                            anchors.centerIn: parent
                            icon: "queue_music"
                            size: widget.compactLayout ? 24 : 28
                            color: MeoTheme.contentOnPrimaryContainer
                        }
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: MeoI18n.translator.i18n("No media playing")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MeoText {
                        Layout.fillWidth: true
                        visible: !widget.compactLayout
                        text: MeoI18n.translator.i18n("Media controls appear when a current-session player is available.")
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
