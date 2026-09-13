/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only presentation over Meo.System's current-user MPRIS bridge. The
    bridge permits only MPRIS controls, uses bounded asynchronous D-Bus calls,
    and rejects remote or oversized artwork before it reaches this QML item.
*/

import QtQuick

import MeoUI 1.0
import Meo.System 1.0

Item {
    id: root

    property bool showArtwork: false

    visible: Media.available
    implicitWidth: mediaCard.implicitWidth
    implicitHeight: visible ? mediaCard.implicitHeight : 0
    Accessible.role: Accessible.Pane
    Accessible.name: mediaCard.Accessible.name

    MeoMediaController {
        id: mediaCard
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.width)
        presentation: "compact"
        title: Media.title !== "" ? Media.title : Media.playerName
        artist: Media.artist !== "" ? Media.artist : Media.playerName
        sourceName: Media.playerName
        coverSource: root.showArtwork ? Media.artUrl : ""
        showArtwork: root.showArtwork
        isPlaying: Media.playing
        canSkipPrevious: Media.canGoPrevious
        canSkipNext: Media.canGoNext
        showVolume: false
        showSecondaryActions: false
        enabled: Media.controllable

        onPlayRequested: Media.playPause()
        onPauseRequested: Media.playPause()
        onPreviousRequested: Media.previous()
        onNextRequested: Media.next()
    }
}
