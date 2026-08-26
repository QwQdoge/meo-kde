import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.notificationmanager as NotificationManager
import MeoUI 1.0
import MeoKDE 1.0
import Meo.System 1.0

QQC2.ScrollView {
    id: root
    signal wifiDetailsRequested()
    signal bluetoothDetailsRequested()
    signal audioDetailsRequested()
    signal powerDetailsRequested()
    signal powerRequested()
    signal editRequested()
    signal tileLayoutChanged(string order, string sizes, string visibility, string density)

    property string tileOrder: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileSizes: "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
    property string tileVisibility: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileDensity: "comfortable"
    property bool editMode: false
    property bool displayExpanded: false
    property bool audioExpanded: false
    property bool tileModelReady: false

    implicitWidth: ShellMetrics.quickSettingsWidth
    implicitHeight: ShellMetrics.quickSettingsHeight
    contentWidth: availableWidth
    contentHeight: contentColumn.implicitHeight
    clip: true
    QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

    readonly property var validTileIds: ["wifi", "bluetooth", "focus", "nightLight", "keepAwake", "powerMode", "microphone", "audioDevices", "display", "screenshot"]
    readonly property string defaultTileVisibility: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    readonly property real tileDensityScale: tileDensity === "compact" ? 0.86
                                                   : (tileDensity === "spacious" ? 1.14 : 1.0)

    function visibleTileIds() {
        const result = []
        const seen = {}
        for (const id of tileVisibility.split(",")) {
            if (validTileIds.indexOf(id) >= 0 && !seen[id]) {
                result.push(id)
                seen[id] = true
            }
        }
        // An empty persisted visibility list is intentional and must remain
        // empty until the user adds tiles again in the editor.
        return result
    }

    function normalizedTileDensity() {
        return tileDensity === "compact" || tileDensity === "spacious" ? tileDensity : "comfortable"
    }

    function rebuildTiles() {
        tileModel.clear()
        const requested = tileOrder.split(",")
        const sizes = {}
        const visible = {}
        for (const entry of tileSizes.split(",")) {
            const fields = entry.split(":")
            if (fields.length === 2)
                sizes[fields[0]] = Number(fields[1]) === 2 ? 2 : 1
        }
        for (const id of visibleTileIds())
            visible[id] = true
        const added = {}
        for (const id of requested.concat(validTileIds)) {
            if (validTileIds.indexOf(id) < 0 || added[id] || !visible[id])
                continue
            tileModel.append({ "tileId": id, "tileSpan": sizes[id] || 2 })
            added[id] = true
        }
    }

    function saveTiles() {
        const order = []
        const sizes = []
        const visibility = []
        const seen = {}
        const configuredSizes = {}
        for (const entry of tileSizes.split(",")) {
            const fields = entry.split(":")
            if (fields.length === 2)
                configuredSizes[fields[0]] = Number(fields[1]) === 1 ? 1 : 2
        }
        for (let index = 0; index < tileModel.count; ++index) {
            const tile = tileModel.get(index)
            order.push(tile.tileId)
            sizes.push(tile.tileId + ":" + tile.tileSpan)
            visibility.push(tile.tileId)
            configuredSizes[tile.tileId] = tile.tileSpan
            seen[tile.tileId] = true
        }
        for (const id of tileOrder.split(",").concat(validTileIds)) {
            if (validTileIds.indexOf(id) < 0 || seen[id])
                continue
            order.push(id)
            sizes.push(id + ":" + (configuredSizes[id] || 2))
            seen[id] = true
        }
        tileLayoutChanged(order.join(","), sizes.join(","), visibility.join(","), normalizedTileDensity())
    }

    function scheduleSaveTiles() {
        saveTilesTimer.restart()
    }

    function prepareToClose() {
        editMode = false
        displayExpanded = false
        audioExpanded = false
        if (saveTilesTimer.running) {
            saveTilesTimer.stop()
            saveTiles()
        }
    }

    function bluetoothSubtitle() {
        if (!SystemState.bluetoothEnabled) return qsTr("Off")
        for (const device of SystemState.bluetoothDevices) {
            if (device.connected) return device.name
        }
        return qsTr("On")
    }

    function tileTitle(id) {
        if (id === "wifi") return qsTr("Wi-Fi")
        if (id === "bluetooth") return qsTr("Bluetooth")
        if (id === "focus") return qsTr("Focus")
        if (id === "nightLight") return qsTr("Night Light")
        if (id === "keepAwake") return qsTr("Keep Awake")
        if (id === "powerMode") return qsTr("Power Mode")
        if (id === "microphone") return qsTr("Microphone")
        if (id === "audioDevices") return qsTr("Sound")
        if (id === "display") return qsTr("Displays")
        return qsTr("Screenshot")
    }

    function tileSubtitle(id) {
        if (id === "wifi") return SystemState.networkName !== "" ? SystemState.networkName : SystemState.networkStatus
        if (id === "bluetooth") return bluetoothSubtitle()
        if (id === "focus") return NotificationManager.Server.inhibited ? qsTr("Do Not Disturb") : qsTr("Notifications on")
        if (id === "nightLight") return Platform.nightLightRunning ? qsTr("On") : qsTr("Off")
        if (id === "keepAwake") return Platform.keepAwake ? qsTr("On") : qsTr("Off")
        if (id === "powerMode") return Platform.activePowerProfile
        if (id === "microphone") return SystemState.microphoneMuted ? qsTr("Muted") : SystemState.microphoneDevice
        if (id === "audioDevices") return SystemState.audioMuted ? qsTr("Muted") : SystemState.audioDevice
        if (id === "display") return qsTr("%1 connected").arg(Platform.brightnessDisplays.length)
        return qsTr("Capture screen")
    }

    function tileIcon(id) {
        if (id === "wifi") return SystemState.wirelessEnabled ? (SystemState.networkConnected ? "wifi" : "wifi_find") : "wifi_off"
        if (id === "bluetooth") return "bluetooth"
        if (id === "focus") return NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications"
        if (id === "nightLight") return "dark_mode"
        if (id === "keepAwake") return "coffee"
        if (id === "powerMode") return "battery_saver"
        if (id === "microphone") return SystemState.microphoneMuted ? "mic_off" : "mic"
        if (id === "audioDevices") return SystemState.audioMuted ? "volume_off" : "headphones"
        if (id === "display") return "desktop_windows"
        return "screenshot_monitor"
    }

    function tileActive(id) {
        if (id === "wifi") return SystemState.wirelessEnabled
        if (id === "bluetooth") return SystemState.bluetoothEnabled
        if (id === "focus") return NotificationManager.Server.valid && NotificationManager.Server.inhibited
        if (id === "nightLight") return Platform.nightLightEnabled
        if (id === "keepAwake") return Platform.keepAwake
        if (id === "powerMode") return Platform.activePowerProfile === "performance"
        if (id === "microphone") return SystemState.microphoneAvailable && !SystemState.microphoneMuted
        if (id === "audioDevices") return SystemState.audioAvailable && !SystemState.audioMuted
        return false
    }

    function tileEnabled(id) {
        if (id === "wifi") return SystemState.networkAvailable
        if (id === "bluetooth") return SystemState.bluetoothAvailable
        if (id === "focus") return NotificationManager.Server.valid
        if (id === "nightLight") return Platform.nightLightAvailable
        if (id === "powerMode") return Platform.powerProfilesAvailable
        if (id === "microphone") return SystemState.microphoneAvailable
        if (id === "audioDevices") return SystemState.audioAvailable
        if (id === "display") return Platform.brightnessDisplays.length > 0
        return true
    }

    function triggerTile(id) {
        if (id === "wifi") SystemState.wirelessEnabled = !SystemState.wirelessEnabled
        else if (id === "bluetooth") SystemState.bluetoothEnabled = !SystemState.bluetoothEnabled
        else if (id === "focus") NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        else if (id === "nightLight") Platform.nightLightEnabled = !Platform.nightLightEnabled
        else if (id === "keepAwake") Platform.keepAwake = !Platform.keepAwake
        else if (id === "powerMode") root.powerDetailsRequested()
        else if (id === "microphone") SystemState.microphoneMuted = !SystemState.microphoneMuted
        else if (id === "audioDevices") root.audioDetailsRequested()
        else if (id === "display") Qt.openUrlExternally("systemsettings:kcm_kscreen")
        else if (id === "screenshot") Qt.openUrlExternally("applications:org.kde.spectacle.desktop")
    }

    function requestDetails(id) {
        if (id === "wifi") root.wifiDetailsRequested()
        else if (id === "bluetooth") root.bluetoothDetailsRequested()
        else if (id === "powerMode") root.powerDetailsRequested()
        else if (id === "microphone") root.audioDetailsRequested()
        else if (id === "audioDevices") root.audioDetailsRequested()
    }

    onTileOrderChanged: if (tileModelReady) rebuildTiles()
    onTileSizesChanged: if (tileModelReady) rebuildTiles()
    onTileVisibilityChanged: if (tileModelReady) rebuildTiles()

    Component.onCompleted: {
        tileModelReady = true
        rebuildTiles()
    }

    ListModel { id: tileModel }

    Timer {
        id: saveTilesTimer
        interval: 180
        onTriggered: root.saveTiles()
    }

    ColumnLayout {
        id: contentColumn
        width: root.availableWidth
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                MeoText { id: timeText; typeRole: "title"; typeSize: "large"; emphasized: true; color: MeoTheme.onSurface }
                MeoText { id: dateText; typeRole: "body"; typeSize: "medium"; color: MeoTheme.onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            MeoText {
                visible: root.editMode
                text: qsTr("Drag to reorder · use arrows to resize")
                typeRole: "label"
                typeSize: "small"
                color: MeoTheme.primary
            }
            RowLayout {
                visible: SystemState.batteryAvailable && !root.editMode
                spacing: MeoTheme.space4
                MeoIcon { icon: SystemState.batteryCharging ? "battery_charging_full" : "battery_full"; size: 20; color: MeoTheme.onSurfaceVariant }
                MeoText { text: SystemState.batteryPercent + "%"; typeRole: "label"; typeSize: "medium"; emphasized: true; color: MeoTheme.onSurface }
            }
        }

        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                const now = new Date()
                timeText.text = Qt.formatDateTime(now, "hh:mm")
                dateText.text = Qt.formatDateTime(now, "dddd, MMMM d")
            }
        }

        Repeater {
            model: Platform.brightnessDisplays
            delegate: MeoQuickControlSlider {
                required property int index
                required property var modelData
                Layout.fillWidth: true
                visible: index === 0 || root.displayExpanded
                iconName: "light_mode"
                label: root.displayExpanded && Platform.brightnessDisplays.length > 1 ? modelData.label : ""
                accessibleName: modelData.label
                    ? qsTr("%1 brightness").arg(modelData.label)
                    : qsTr("Display brightness")
                iconAccessibleName: ""
                iconActionEnabled: false
                from: 0
                to: modelData.maximum
                value: modelData.brightness
                detailsAvailable: index === 0 && Platform.brightnessDisplays.length > 1
                expanded: root.displayExpanded
                onMoved: function(value) { Platform.setBrightness(modelData.id, Math.round(value)) }
                onDetailsToggled: function(expanded) { root.displayExpanded = expanded }
            }
        }

        MeoQuickControlSlider {
            Layout.fillWidth: true
            visible: SystemState.audioAvailable
            iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
            label: ""
            accessibleName: qsTr("Output volume")
            iconAccessibleName: SystemState.audioMuted ? qsTr("Unmute output") : qsTr("Mute output")
            from: 0
            to: 100
            value: SystemState.volumePercent
            detailsAvailable: SystemState.audioOutputDevices.length > 1 || SystemState.microphoneAvailable
            expanded: root.audioExpanded
            onMoved: function(value) { SystemState.volumePercent = Math.round(value) }
            onIconTriggered: SystemState.audioMuted = !SystemState.audioMuted
            onDetailsToggled: function(expanded) { root.audioExpanded = expanded }
        }

        MeoMotionSurface {
            readonly property bool shown: root.audioExpanded && SystemState.audioAvailable
            Layout.fillWidth: true
            visible: implicitHeight > 0 || opacity > 0
            enabled: shown
            clip: true
            opacity: shown ? 1 : 0
            implicitHeight: shown ? audioAdvanced.implicitHeight + 2 * MeoTheme.space12 : 0
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0
            Behavior on opacity {
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
            }
            ColumnLayout {
                id: audioAdvanced
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8
                MeoExposedDropdown {
                    Layout.fillWidth: true
                    label: qsTr("Output device")
                    model: SystemState.audioOutputDevices.map(function(device) { return device.name })
                    text: SystemState.audioDevice
                    onSelected: function(index, value) { SystemState.setDefaultAudioOutput(SystemState.audioOutputDevices[index].id) }
                }
                MeoQuickControlSlider {
                    Layout.fillWidth: true
                    visible: SystemState.microphoneAvailable
                    iconName: SystemState.microphoneMuted ? "mic_off" : "mic"
                    label: SystemState.microphoneDevice
                    accessibleName: qsTr("Microphone volume")
                    iconAccessibleName: SystemState.microphoneMuted
                        ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                    from: 0; to: 100; value: SystemState.microphoneVolumePercent
                    onMoved: function(value) { SystemState.microphoneVolumePercent = Math.round(value) }
                    onIconTriggered: SystemState.microphoneMuted = !SystemState.microphoneMuted
                }
                MeoExposedDropdown {
                    Layout.fillWidth: true
                    visible: SystemState.audioInputDevices.length > 1
                    label: qsTr("Input device")
                    model: SystemState.audioInputDevices.map(function(device) { return device.name })
                    text: SystemState.microphoneDevice
                    onSelected: function(index, value) { SystemState.setDefaultAudioInput(SystemState.audioInputDevices[index].id) }
                }
            }
        }

        GridLayout {
            id: tileGrid
            Layout.fillWidth: true
            columns: root.availableWidth < 320 * MeoTheme.globalScale ? 2 : 4
            uniformCellWidths: true
            columnSpacing: MeoTheme.space8
            rowSpacing: MeoTheme.space8

            Repeater {
                model: tileModel
                delegate: Item {
                    id: tileSlot
                    required property int index
                    required property string tileId
                    required property int tileSpan
                    Layout.columnSpan: tileSpan
                    Layout.fillWidth: true
                    implicitHeight: (tileSpan === 2 ? 72 : 96) * root.tileDensityScale * MeoTheme.globalScale
                    Layout.preferredHeight: implicitHeight

                    DropArea {
                        anchors.fill: parent
                        enabled: root.editMode
                        onEntered: function(drag) {
                            const from = drag.source ? drag.source.modelIndex : -1
                            if (from >= 0 && from !== tileSlot.index) {
                                tileModel.move(from, tileSlot.index, 1)
                                root.scheduleSaveTiles()
                            }
                        }
                    }

                    MeoQuickSettingsTile {
                        anchors.fill: parent
                        title: root.tileTitle(tileSlot.tileId)
                        supportingText: root.tileSubtitle(tileSlot.tileId)
                        iconName: root.tileIcon(tileSlot.tileId)
                        active: root.tileActive(tileSlot.tileId)
                        enabled: root.tileEnabled(tileSlot.tileId)
                        wide: tileSlot.tileSpan === 2
                        detailsEnabled: tileSlot.tileId === "wifi" || tileSlot.tileId === "bluetooth" || tileSlot.tileId === "powerMode" || tileSlot.tileId === "microphone" || tileSlot.tileId === "audioDevices"
                        editMode: root.editMode
                        modelIndex: tileSlot.index
                        onTriggered: root.triggerTile(tileSlot.tileId)
                        onDetailsRequested: root.requestDetails(tileSlot.tileId)
                        onResizeRequested: {
                            tileModel.setProperty(tileSlot.index, "tileSpan", tileSlot.tileSpan === 2 ? 1 : 2)
                            root.scheduleSaveTiles()
                        }
                    }

                    Behavior on x {
                        NumberAnimation { duration: root.editMode ? MeoMotion.stateChange : 0; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        NumberAnimation { duration: root.editMode ? MeoMotion.stateChange : 0; easing.type: Easing.OutCubic }
                    }
                    Behavior on implicitHeight {
                        NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        MeoMotionSurface {
            visible: implicitHeight > 0 || opacity > 0
            enabled: Media.available
            Layout.fillWidth: true
            clip: true
            opacity: Media.available ? 1 : 0
            implicitHeight: Media.available ? 72 * MeoTheme.globalScale : 0
            radius: MeoTheme.shapeLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0
            Behavior on opacity {
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: MeoTheme.space12
                anchors.rightMargin: MeoTheme.space8
                spacing: MeoTheme.space8

                MeoIcon {
                    icon: Media.iconName !== "" ? Media.iconName : "music_note"
                    size: 24
                    color: MeoTheme.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    MeoText {
                        Layout.fillWidth: true
                        text: Media.title !== "" ? Media.title : Media.playerName
                        typeRole: "label"
                        typeSize: "medium"
                        emphasized: true
                        color: MeoTheme.onSurface
                        elide: Text.ElideRight
                    }
                    MeoText {
                        Layout.fillWidth: true
                        text: Media.artist !== "" ? Media.artist : Media.playerName
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                MeoIconButton {
                    visible: Media.canGoPrevious
                    type: "standard"; size: "s"; icon.name: "skip_previous"
                    Accessible.name: qsTr("Previous track")
                    onClicked: Media.previous()
                }
                MeoIconButton {
                    type: "tonal"; size: "m"; icon.name: Media.playing ? "pause" : "play_arrow"
                    Accessible.name: Media.playing ? qsTr("Pause") : qsTr("Play")
                    onClicked: Media.playPause()
                }
                MeoIconButton {
                    visible: Media.canGoNext
                    type: "standard"; size: "s"; icon.name: "skip_next"
                    Accessible.name: qsTr("Next track")
                    onClicked: Media.next()
                }
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: SystemState.operationError !== "" ? SystemState.operationError : (Platform.lastError !== "" ? Platform.lastError : Media.lastError)
            dismissible: true
            onDismissed: { SystemState.clearOperationError(); Platform.clearError(); Media.clearError() }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            MeoIconButton {
                visible: root.editMode
                type: "standard"; size: "m"; icon.name: "restart_alt"
                Accessible.name: qsTr("Reset tile layout")
                onClicked: {
                    root.tileOrder = "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
                    root.tileSizes = "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
                    root.tileVisibility = root.defaultTileVisibility
                    root.tileDensity = "comfortable"
                    root.rebuildTiles(); root.scheduleSaveTiles()
                }
            }
            MeoIconButton { type: "standard"; size: "m"; icon.name: "lock"; Accessible.name: qsTr("Lock screen"); onClicked: Platform.lockScreen() }
            MeoIconButton {
                type: "standard"; size: "m"; icon.name: "settings"
                Accessible.name: qsTr("Meo Settings")
                onClicked: {
                    if (!Qt.openUrlExternally("applications:org.meo.settings.desktop"))
                        Qt.openUrlExternally("systemsettings:")
                }
            }
            MeoIconButton { type: "standard"; size: "m"; icon.name: "power_settings_new"; Accessible.name: qsTr("Power"); onClicked: root.powerRequested() }
            MeoIconButton {
                type: "standard"; size: "m"; icon.name: "edit"
                Accessible.name: qsTr("Edit quick settings")
                onClicked: root.editRequested()
            }
        }
    }
}
