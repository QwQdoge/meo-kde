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
    property string tileSizes: "wifi:2,bluetooth:2,focus:1,nightLight:1,keepAwake:1,powerMode:1,microphone:1,audioDevices:1,display:1,screenshot:1"
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

    readonly property var validTileIds: ["wifi", "bluetooth", "focus", "nightLight", "keepAwake", "powerMode", "microphone", "audioDevices", "display", "screenshot", "darkTheme"]
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
        if (!SystemState.bluetoothEnabled) return MeoI18n.translator.i18n("Off")
        for (const device of SystemState.bluetoothDevices) {
            if (device.connected) return device.name
        }
        return MeoI18n.translator.i18n("On")
    }

    function tileTitle(id) {
        if (id === "darkTheme") return MeoI18n.translator.i18n("Dark theme")
        if (id === "wifi") return MeoI18n.translator.i18n("Wi-Fi")
        if (id === "bluetooth") return MeoI18n.translator.i18n("Bluetooth")
        if (id === "focus") return MeoI18n.translator.i18n("Focus")
        if (id === "nightLight") return MeoI18n.translator.i18n("Night Light")
        if (id === "keepAwake") return MeoI18n.translator.i18n("Keep Awake")
        if (id === "powerMode") return MeoI18n.translator.i18n("Power Mode")
        if (id === "microphone") return MeoI18n.translator.i18n("Microphone")
        if (id === "audioDevices") return MeoI18n.translator.i18n("Sound")
        if (id === "display") return MeoI18n.translator.i18n("Displays")
        return MeoI18n.translator.i18n("Screenshot")
    }

    function tileSubtitle(id) {
        if (id === "darkTheme") return MeoShellTheme.darkMode ? MeoI18n.translator.i18n("On") : MeoI18n.translator.i18n("Off")
        if (id === "wifi") return SystemState.networkName !== "" ? SystemState.networkName : SystemState.networkStatus
        if (id === "bluetooth") return bluetoothSubtitle()
        if (id === "focus") return NotificationManager.Server.inhibited ? MeoI18n.translator.i18n("Do Not Disturb") : MeoI18n.translator.i18n("Notifications on")
        if (id === "nightLight") return Platform.nightLightRunning ? MeoI18n.translator.i18n("On") : MeoI18n.translator.i18n("Off")
        if (id === "keepAwake") return Platform.keepAwake ? MeoI18n.translator.i18n("On") : MeoI18n.translator.i18n("Off")
        if (id === "powerMode") return Platform.activePowerProfile
        if (id === "microphone") return SystemState.microphoneMuted ? MeoI18n.translator.i18n("Muted") : SystemState.microphoneDevice
        if (id === "audioDevices") return SystemState.audioMuted ? MeoI18n.translator.i18n("Muted") : SystemState.audioDevice
        if (id === "display") return MeoI18n.translator.i18n("%1 connected", Platform.brightnessDisplays.length)
        return MeoI18n.translator.i18n("Capture screen")
    }

    function tileIcon(id) {
        if (id === "darkTheme") return "contrast"
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
        if (id === "darkTheme") return MeoShellTheme.darkMode
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
        if (id === "darkTheme") return !ColorSchemeActions.busy
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
        if (id === "darkTheme") { ColorSchemeActions.setDarkMode(!MeoShellTheme.darkMode); return }
        if (id === "wifi") SystemState.wirelessEnabled = !SystemState.wirelessEnabled
        else if (id === "bluetooth") SystemState.bluetoothEnabled = !SystemState.bluetoothEnabled
        else if (id === "focus") NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        else if (id === "nightLight") Platform.nightLightEnabled = !Platform.nightLightEnabled
        else if (id === "keepAwake") Platform.keepAwake = !Platform.keepAwake
        else if (id === "powerMode") root.powerDetailsRequested()
        else if (id === "microphone") SystemState.microphoneMuted = !SystemState.microphoneMuted
        else if (id === "audioDevices") root.audioDetailsRequested()
        else if (id === "display") Qt.openUrlExternally("applications:org.meo.settings.display.desktop")
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

    // The quick control is one persistent slider, independent of list resets.
    // Settings retains the native per-display controls.
    readonly property real combinedBrightness: {
        const displays = Platform.brightnessDisplays
        if (displays.length === 0) return 0
        let total = 0
        for (const display of displays)
            total += 100 * display.brightness / Math.max(1, display.maximum)
        return total / displays.length
    }
    function setAllBrightness(percent) {
        const displays = Platform.brightnessDisplays
        const ratio = Math.max(0, Math.min(100, percent)) / 100
        for (const display of displays)
            Platform.setBrightness(display.id, Math.round(ratio * display.maximum))
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
        // One section rhythm for the whole panel instead of ad-hoc gaps.
        spacing: ShellMetrics.popupSectionSpacing

        QuickSettingsHeader {
            editMode: root.editMode
            systemState: SystemState
            platform: Platform
            onResetRequested: {
                root.tileOrder = "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
                root.tileSizes = "wifi:2,bluetooth:2,focus:1,nightLight:1,keepAwake:1,powerMode:1,microphone:1,audioDevices:1,display:1,screenshot:1"
                root.tileVisibility = root.defaultTileVisibility
                root.tileDensity = "comfortable"
                root.rebuildTiles()
                root.scheduleSaveTiles()
            }
            onPowerRequested: root.powerRequested()
            onEditRequested: root.editRequested()
        }

        MeoQuickControlSlider {
            id: combinedBrightnessSlider
            objectName: "combinedBrightnessSlider"
            controlled: true
            Layout.fillWidth: true
            visible: Platform.brightnessAvailable
                iconName: "light_mode"
                trailingIcon: "settings"
                extraActionIcon: "dark_mode"
                extraActionEnabled: Platform.nightLightAvailable
                extraActionActive: Platform.nightLightEnabled
                extraActionAccessibleName: MeoI18n.translator.i18n("Night Light")
                onExtraActionTriggered: Platform.nightLightEnabled = !Platform.nightLightEnabled
                onTrailingTriggered: Qt.openUrlExternally("applications:org.meo.settings.display.desktop")
            label: ""
            accessibleName: Platform.brightnessDisplays.length > 1
                            ? MeoI18n.translator.i18n("Brightness of all displays")
                            : MeoI18n.translator.i18n("Display brightness")
            iconAccessibleName: ""
            iconActionEnabled: false
            from: 0
            to: 100
            value: root.combinedBrightness
            detailsAvailable: false
            onMoved: function(value) { root.setAllBrightness(value) }
        }

        MeoQuickControlSlider {
                controlled: true
            Layout.fillWidth: true
            visible: SystemState.audioAvailable
            iconName: SystemState.audioMuted ? "volume_off" : "volume_up"
            trailingIcon: "music_note"
            extraActionIcon: "tune"
            extraActionActive: root.audioExpanded
            extraActionAccessibleName: MeoI18n.translator.i18n("Audio controls")
            onExtraActionTriggered: root.audioDetailsRequested()
            onTrailingTriggered: root.audioExpanded = !root.audioExpanded
            label: ""
            accessibleName: MeoI18n.translator.i18n("Output volume")
            iconAccessibleName: SystemState.audioMuted ? MeoI18n.translator.i18n("Unmute output") : MeoI18n.translator.i18n("Mute output")
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
            radius: ShellMetrics.radiusLarge
            color: MeoTheme.surfaceContainerHigh
            elevation: 0
            Behavior on opacity {
                NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
            }
            ColumnLayout {
                id: audioAdvanced
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8
                MeoExposedDropdown {
                    Layout.fillWidth: true
                    label: MeoI18n.translator.i18n("Output device")
                    model: SystemState.audioOutputDevices.map(function(device) { return device.name })
                    text: SystemState.audioDevice
                    onSelected: function(index, value) { SystemState.setDefaultAudioOutput(SystemState.audioOutputDevices[index].id) }
                }
                MeoQuickControlSlider {
                controlled: true
                    Layout.fillWidth: true
                    visible: SystemState.microphoneAvailable
                    iconName: SystemState.microphoneMuted ? "mic_off" : "mic"
                    label: SystemState.microphoneDevice
                    accessibleName: MeoI18n.translator.i18n("Microphone volume")
                    iconAccessibleName: SystemState.microphoneMuted
                        ? MeoI18n.translator.i18n("Unmute microphone") : MeoI18n.translator.i18n("Mute microphone")
                    from: 0; to: 100; value: SystemState.microphoneVolumePercent
                    onMoved: function(value) { SystemState.microphoneVolumePercent = Math.round(value) }
                    onIconTriggered: SystemState.microphoneMuted = !SystemState.microphoneMuted
                }
                MeoExposedDropdown {
                    Layout.fillWidth: true
                    visible: SystemState.audioInputDevices.length > 1
                    label: MeoI18n.translator.i18n("Input device")
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
                    // Pixel tiles keep a consistent 80 dp touch height. Wide
                    // tiles gain information density horizontally instead of
                    // becoming a different visual language vertically.
                    implicitHeight: ShellMetrics.quickSettingsTileHeight * root.tileDensityScale
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
                        visualStyle: "pixel"
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
                        NumberAnimation { duration: root.editMode ? MeoTheme.motionDurationDisclosureEnter : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
                    }
                    Behavior on y {
                        NumberAnimation { duration: root.editMode ? MeoTheme.motionDurationDisclosureEnter : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate }
                    }
                    Behavior on implicitHeight {
                        NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
                    }
                }
            }
        }

        QuickSettingsMediaCard { media: Media }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: ColorSchemeActions.error
            dismissible: false
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            text: SystemState.operationError !== "" ? SystemState.operationError : (Platform.lastError !== "" ? Platform.lastError : Media.lastError)
            dismissible: true
            onDismissed: { SystemState.clearOperationError(); Platform.clearError(); Media.clearError() }
        }


    }
}
