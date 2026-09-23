/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only presentation over Meo.System's current-user MPRIS bridge. The
    bridge permits only MPRIS controls, uses bounded asynchronous D-Bus calls,
    and rejects remote or oversized artwork before it reaches this QML item.
*/

import QtQuick
import QtQuick.Layouts

import MeoUI 1.0
import Meo.System 1.0

Item {
    id: root

    property bool showArtwork: false
    property bool showMedia: true

    visible: (root.showMedia && Media.available) || (root.showVolume && SystemState.audioAvailable)
    property bool showVolume: false

    implicitWidth: mediaColumn.implicitWidth
    implicitHeight: visible ? mediaColumn.implicitHeight : 0
    Accessible.role: Accessible.Pane
    Accessible.name: mediaCard.Accessible.name

    ColumnLayout {
        id: mediaColumn
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(440 * MeoTheme.globalScale, root.width)
        spacing: MeoTheme.space8

        MeoMediaController {
            id: mediaCard
            visible: root.showMedia && Media.available
            Layout.fillWidth: true
            presentation: "lockScreen"
            title: Media.title !== "" ? Media.title : Media.playerName
            artist: Media.artist !== "" ? Media.artist : Media.playerName
            album: Media.album
            sourceName: Media.playerName
            coverSource: root.showArtwork ? Media.artUrl : ""
            showArtwork: root.showArtwork
            showBackdropArtwork: true
            isPlaying: Media.playing
            duration: Number(Media.durationMs)
            position: Number(Media.positionMs)
            canSeek: Media.canSeek
            canSkipPrevious: Media.canGoPrevious
            canSkipNext: Media.canGoNext
            canShuffle: Media.shuffleSupported
            canRepeat: Media.repeatSupported
            shuffleEnabled: Media.shuffle
            repeatMode: Media.repeatMode
            sourceCount: Media.playerCount
            showVolume: root.showVolume && SystemState.audioAvailable
            volume: Math.min(100, SystemState.volumePercent) / 100
            canAdjustVolume: SystemState.audioAvailable
            showSecondaryActions: false
            enabled: Media.controllable

            onPlayRequested: Media.playPause()
            onPauseRequested: Media.playPause()
            onPreviousRequested: Media.previous()
            onNextRequested: Media.next()
            onSeekRequested: newPosition => Media.seekTo(newPosition)
            onShuffleRequested: enabled => Media.setShuffle(enabled)
            onRepeatRequested: mode => Media.setRepeatMode(mode)
            onPreviousSourceRequested: Media.selectPreviousPlayer()
            onNextSourceRequested: Media.selectNextPlayer()
            onVolumeRequested: value => SystemState.volumePercent = Math.round(value * 100)
        }

        // A player is not required for the output-volume surface. Keep this
        // as the same semantic slider MeoUI uses elsewhere, but do not expose
        // a device picker or any input/microphone control on the locker.
        MeoQuickControlSlider {
            Layout.fillWidth: true
            visible: root.showVolume && SystemState.audioAvailable && !(root.showMedia && Media.available)
            iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
            label: qsTr("Output volume")
            accessibleName: label
            iconAccessibleName: SystemState.audioMuted ? qsTr("Unmute output") : qsTr("Mute output")
            from: 0
            to: 100
            value: Math.min(100, SystemState.volumePercent)
            onMoved: value => SystemState.volumePercent = Math.round(value)
            onIconTriggered: SystemState.audioMuted = !SystemState.audioMuted
        }

        MeoIconToggleButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showVolume && SystemState.audioAvailable
            icon.name: "volume_up"
            checkedIcon: "volume_off"
            checked: SystemState.audioMuted
            Accessible.name: checked ? qsTr("Unmute output") : qsTr("Mute output")
            onToggled: SystemState.audioMuted = checked
        }
    }
}
