import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

// Unified media projection for Quick Settings. The host owns only the real
// MPRIS bridge; presentation and interaction stay in MeoUI so desktop widgets,
// Quick Settings, and the lock screen share one media language.
MeoMotionSurface {
    id: root

    required property var media
    readonly property bool shown: root.media.available
    visible: implicitHeight > 0 || opacity > 0
    enabled: root.media.available
    Layout.fillWidth: true
    clip: true
    opacity: shown ? 1 : 0
    implicitHeight: shown ? 236 * MeoTheme.globalScale : 0
    radius: ShellMetrics.radiusLarge
    color: "transparent"
    elevation: 0

    Behavior on opacity {
        NumberAnimation {
            duration: MeoTheme.motionDurationState
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingStandard
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: MeoTheme.motionDurationDialogEnter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }

    MeoMediaController {
        anchors.fill: parent
        presentation: "controlCenter"
        title: root.media.title !== "" ? root.media.title : root.media.playerName
        artist: root.media.artist !== "" ? root.media.artist : root.media.playerName
        album: root.media.album
        sourceName: root.media.playerName
        coverSource: root.media.remoteArtUrl !== "" ? root.media.remoteArtUrl : root.media.artUrl
        isPlaying: root.media.playing
        duration: Number(root.media.durationMs)
        position: Number(root.media.positionMs)
        canSeek: root.media.canSeek
        canSkipPrevious: root.media.canGoPrevious
        canSkipNext: root.media.canGoNext
        canShuffle: root.media.shuffleSupported
        canRepeat: root.media.repeatSupported
        shuffleEnabled: root.media.shuffle
        repeatMode: root.media.repeatMode
        sourceCount: root.media.playerCount
        canAdjustVolume: false
        showVolume: false
        showFavoriteAction: false
        showOutputAction: false
        enabled: root.media.controllable

        onPlayRequested: root.media.playPause()
        onPauseRequested: root.media.playPause()
        onPreviousRequested: root.media.previous()
        onNextRequested: root.media.next()
        onSeekRequested: newPosition => root.media.seekTo(newPosition)
        onShuffleRequested: enabled => root.media.setShuffle(enabled)
        onRepeatRequested: mode => root.media.setRepeatMode(mode)
        onPreviousSourceRequested: root.media.selectPreviousPlayer()
        onNextSourceRequested: root.media.selectNextPlayer()
    }
}
