import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.ScrollView {
    id: root
    signal backRequested()
    implicitWidth: ShellMetrics.quickSettingsWidth
    implicitHeight: ShellMetrics.quickSettingsHeight
    contentWidth: availableWidth
    contentHeight: pageContent.implicitHeight
    clip: true
    QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

    function deviceIcon(formFactor, input) {
        if (formFactor === "headset" || formFactor === "headphone") return "headphones"
        if (formFactor === "bluetooth") return "bluetooth_audio"
        if (input || formFactor === "microphone" || formFactor === "webcam") return "mic"
        return "volume_up"
    }

    ColumnLayout {
        id: pageContent
        width: root.availableWidth
        spacing: ShellMetrics.popupItemSpacing

        PopupPageHeader {
            Layout.fillWidth: true
            title: qsTr("Sound")
            subtitle: SystemState.audioAvailable ? SystemState.audioDevice : qsTr("No audio service")
            onBackRequested: root.backRequested()
            trailingContent: Component {
                MeoIconButton {
                    type: "standard"
                    size: "m"
                    icon.name: "settings"
                    Accessible.name: qsTr("Open Sound Settings")
                    onClicked: Qt.openUrlExternally("systemsettings:kcm_pulseaudio")
                }
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: SystemState.operationError
            dismissible: true
            onDismissed: SystemState.clearOperationError()
        }

        PopupEmptyState {
            Layout.fillWidth: true
            Layout.preferredHeight: 220 * MeoTheme.globalScale
            visible: !SystemState.audioAvailable
            iconName: "volume_off"
            title: qsTr("Audio is unavailable")
            description: qsTr("Open Sound Settings to check PipeWire or PulseAudio devices.")
            actionText: qsTr("Sound Settings")
            onActionRequested: Qt.openUrlExternally("systemsettings:kcm_pulseaudio")
        }

        PopupSectionLabel {
            visible: SystemState.audioAvailable
            sectionText: qsTr("Output volume")
        }

        MeoMotionSurface {
            Layout.fillWidth: true
            visible: SystemState.audioAvailable
            implicitHeight: outputControls.implicitHeight + 2 * MeoTheme.space12
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0
            RowLayout {
                id: outputControls
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8
                MeoIconButton {
                    type: "tonal"
                    size: "m"
                    icon.name: SystemState.audioMuted ? "volume_off" : "volume_up"
                    Accessible.name: SystemState.audioMuted ? qsTr("Unmute") : qsTr("Mute")
                    onClicked: SystemState.audioMuted = !SystemState.audioMuted
                }
                MeoSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 150
                    value: SystemState.volumePercent
                    valueLabelEnabled: false
                    size: "s"
                    Accessible.name: qsTr("Output volume")
                    onMoved: function(value) { SystemState.volumePercent = Math.round(value) }
                }
                MeoText {
                    text: SystemState.volumePercent + "%"
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.onSurfaceVariant
                }
            }
        }

        PopupSectionLabel {
            visible: SystemState.audioAvailable
            sectionText: qsTr("Output device")
        }

        Repeater {
            model: SystemState.audioAvailable ? SystemState.audioOutputDevices : []
            delegate: MeoListItem {
                required property var modelData
                Layout.fillWidth: true
                isDense: true
                isSegmented: true
                roundingStrategy: "all"
                headline: modelData.name
                leadingIcon: root.deviceIcon(modelData.formFactor, false)
                selected: modelData.active
                trailingComponent: Component {
                    MeoIcon { visible: modelData.active; icon: "check"; size: 18; fill: true; color: MeoTheme.primary }
                }
                onClicked: SystemState.setDefaultAudioOutput(modelData.id)
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: SystemState.audioAvailable && SystemState.audioOutputDevices.length === 0
            text: qsTr("No output device is currently available.")
            tone: "info"
        }

        PopupSectionLabel {
            visible: SystemState.microphoneAvailable
            sectionText: qsTr("Microphone")
        }

        MeoMotionSurface {
            Layout.fillWidth: true
            visible: SystemState.microphoneAvailable
            implicitHeight: inputControls.implicitHeight + 2 * MeoTheme.space12
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0
            RowLayout {
                id: inputControls
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8
                MeoIconButton {
                    type: "tonal"
                    size: "m"
                    icon.name: SystemState.microphoneMuted ? "mic_off" : "mic"
                    Accessible.name: SystemState.microphoneMuted ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                    onClicked: SystemState.microphoneMuted = !SystemState.microphoneMuted
                }
                MeoSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 150
                    value: SystemState.microphoneVolumePercent
                    valueLabelEnabled: false
                    size: "s"
                    Accessible.name: qsTr("Microphone volume")
                    onMoved: function(value) { SystemState.microphoneVolumePercent = Math.round(value) }
                }
                MeoText {
                    text: SystemState.microphoneVolumePercent + "%"
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.onSurfaceVariant
                }
            }
        }

        Repeater {
            model: SystemState.microphoneAvailable ? SystemState.audioInputDevices : []
            delegate: MeoListItem {
                required property var modelData
                Layout.fillWidth: true
                isDense: true
                isSegmented: true
                roundingStrategy: "all"
                headline: modelData.name
                leadingIcon: root.deviceIcon(modelData.formFactor, true)
                selected: modelData.active
                trailingComponent: Component {
                    MeoIcon { visible: modelData.active; icon: "check"; size: 18; fill: true; color: MeoTheme.primary }
                }
                onClicked: SystemState.setDefaultAudioInput(modelData.id)
            }
        }

        Item { Layout.preferredHeight: MeoTheme.space8 }
    }
}
