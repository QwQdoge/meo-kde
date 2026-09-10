import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import MeoKDE 1.0

// This card is a direct projection of the real MPRIS bridge. It intentionally
// owns no playback state, timers, or fallback demo data.
MeoMotionSurface {
    id: root

    required property var media
    readonly property bool shown: root.media.available
    visible: implicitHeight > 0 || opacity > 0
    enabled: root.media.available
    Layout.fillWidth: true
    clip: true
    opacity: shown ? 1 : 0
    implicitHeight: shown ? 72 * MeoTheme.globalScale : 0
    radius: ShellMetrics.radiusLarge
    color: MeoTheme.surfaceContainerHigh
    elevation: 0

    Behavior on opacity {
        NumberAnimation { duration: MeoTheme.motionDurationState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: MeoTheme.motionDurationDialogEnter; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: MeoTheme.space12
        anchors.rightMargin: MeoTheme.space8
        spacing: MeoTheme.space8

        MeoIcon { icon: root.media.iconName !== "" ? root.media.iconName : "music_note"; size: 24; color: MeoTheme.primary }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MeoText { Layout.fillWidth: true; text: root.media.title !== "" ? root.media.title : root.media.playerName; typeRole: "label"; typeSize: "medium"; emphasized: true; color: MeoTheme.onSurface; elide: Text.ElideRight }
            MeoText { Layout.fillWidth: true; text: root.media.artist !== "" ? root.media.artist : root.media.playerName; typeRole: "body"; typeSize: "small"; color: MeoTheme.onSurfaceVariant; elide: Text.ElideRight }
        }
        MeoIconButton { visible: root.media.canGoPrevious; type: "standard"; size: "s"; icon.name: "skip_previous"; Accessible.name: qsTr("Previous track"); onClicked: root.media.previous() }
        MeoIconButton { type: "tonal"; size: "m"; icon.name: root.media.playing ? "pause" : "play_arrow"; Accessible.name: root.media.playing ? qsTr("Pause") : qsTr("Play"); onClicked: root.media.playPause() }
        MeoIconButton { visible: root.media.canGoNext; type: "standard"; size: "s"; icon.name: "skip_next"; Accessible.name: qsTr("Next track"); onClicked: root.media.next() }
    }
}
