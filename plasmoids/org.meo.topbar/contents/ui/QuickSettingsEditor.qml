pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import MeoUI 1.0

// MeoKDE owns the tile identifiers and Plasma configuration wire format.
// MeoQuickSettingsEditor supplies only the reusable visual/editor treatment.
QQC2.ScrollView {
    id: root

    property string tileOrder: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileSizes: "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"
    property string tileVisibility: "wifi,bluetooth,focus,nightLight,keepAwake,powerMode,microphone,audioDevices,display,screenshot"
    property string tileDensity: "comfortable"
    property bool modelReady: false
    property int tileRevision: 0
    property string undoOrder: ""
    property string undoSizes: ""
    property string undoVisibility: ""
    property string undoDensity: ""

    signal tileLayoutChanged(string order, string sizes, string visibility, string density)
    signal backRequested()

    readonly property var validTileIds: ["wifi", "bluetooth", "focus", "nightLight", "keepAwake", "powerMode", "microphone", "audioDevices", "display", "screenshot"]
    readonly property int visibleTileCount: {
        tileRevision
        let count = 0
        for (let index = 0; index < tileModel.count; ++index) {
            if (tileModel.get(index).visible)
                ++count
        }
        return count
    }
    readonly property var editorTiles: {
        tileRevision
        const values = []
        for (let index = 0; index < tileModel.count; ++index) {
            const tile = tileModel.get(index)
            if (!tile.visible)
                continue
            values.push({
                "id": tile.tileId,
                "sourceIndex": index,
                "title": root.tileTitle(tile.tileId),
                "iconName": root.tileIcon(tile.tileId),
                "span": tile.tileSpan,
                "removable": true,
                "resizable": true
            })
        }
        return values
    }
    readonly property var availableTiles: {
        tileRevision
        const values = []
        for (let index = 0; index < tileModel.count; ++index) {
            const tile = tileModel.get(index)
            if (tile.visible)
                continue
            values.push({
                "id": tile.tileId,
                "sourceIndex": index,
                "title": root.tileTitle(tile.tileId),
                "iconName": root.tileIcon(tile.tileId),
                "span": tile.tileSpan,
                "resizable": true
            })
        }
        return values
    }

    contentWidth: availableWidth
    contentHeight: editor.implicitHeight
    clip: true
    QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

    function tileTitle(id) {
        if (id === "wifi") return qsTr("Wi-Fi")
        if (id === "bluetooth") return qsTr("Bluetooth")
        if (id === "focus") return qsTr("Modes")
        if (id === "nightLight") return qsTr("Night Light")
        if (id === "keepAwake") return qsTr("Keep Awake")
        if (id === "powerMode") return qsTr("Power Mode")
        if (id === "microphone") return qsTr("Microphone")
        if (id === "audioDevices") return qsTr("Sound")
        if (id === "display") return qsTr("Displays")
        return qsTr("Screenshot")
    }

    function tileIcon(id) {
        if (id === "wifi") return "wifi"
        if (id === "bluetooth") return "bluetooth"
        if (id === "focus") return "do_not_disturb_on"
        if (id === "nightLight") return "dark_mode"
        if (id === "keepAwake") return "coffee"
        if (id === "powerMode") return "battery_saver"
        if (id === "microphone") return "mic"
        if (id === "audioDevices") return "headphones"
        if (id === "display") return "desktop_windows"
        return "screenshot_monitor"
    }

    function rebuildTiles() {
        const configuredSizes = {}
        const visible = {}
        const seen = {}
        const orderedIds = []

        for (const entry of tileSizes.split(",")) {
            const fields = entry.split(":")
            if (fields.length === 2 && validTileIds.indexOf(fields[0]) >= 0)
                configuredSizes[fields[0]] = Number(fields[1]) === 1 ? 1 : 2
        }
        // An explicitly empty string means the user removed every tile. It
        // must not silently revert to all-visible on the next popup open.
        for (const id of tileVisibility.split(",")) {
            if (validTileIds.indexOf(id) >= 0)
                visible[id] = true
        }
        for (const id of tileOrder.split(",").concat(validTileIds)) {
            if (validTileIds.indexOf(id) < 0 || seen[id])
                continue
            orderedIds.push(id)
            seen[id] = true
        }

        tileModel.clear()
        for (const id of orderedIds)
            tileModel.append({ "tileId": id, "tileSpan": configuredSizes[id] || 2,
                               "visible": visible[id] === true })
        tileRevision++
    }

    function saveLayout() {
        const order = []
        const sizes = []
        const visibility = []
        for (let index = 0; index < tileModel.count; ++index) {
            const tile = tileModel.get(index)
            order.push(tile.tileId)
            sizes.push(tile.tileId + ":" + (tile.tileSpan === 1 ? 1 : 2))
            if (tile.visible)
                visibility.push(tile.tileId)
        }
        tileLayoutChanged(order.join(","), sizes.join(","), visibility.join(","), tileDensity)
    }

    function moveVisibleTile(fromVisibleIndex, toVisibleIndex) {
        const sourceIndexes = []
        for (let index = 0; index < tileModel.count; ++index) {
            if (tileModel.get(index).visible)
                sourceIndexes.push(index)
        }
        if (fromVisibleIndex < 0 || toVisibleIndex < 0
                || fromVisibleIndex >= sourceIndexes.length
                || toVisibleIndex >= sourceIndexes.length
                || fromVisibleIndex === toVisibleIndex)
            return
        tileModel.move(sourceIndexes[fromVisibleIndex], sourceIndexes[toVisibleIndex], 1)
        tileRevision++
        saveLayout()
    }

    function setTileSpan(sourceIndex, span) {
        if (sourceIndex < 0 || sourceIndex >= tileModel.count)
            return
        tileModel.setProperty(sourceIndex, "tileSpan", span === 1 ? 1 : 2)
        tileRevision++
        saveLayout()
    }

    function setTileVisible(sourceIndex, visible) {
        if (sourceIndex < 0 || sourceIndex >= tileModel.count)
            return
        tileModel.setProperty(sourceIndex, "visible", visible)
        tileRevision++
        saveLayout()
    }

    function restoreUndo() {
        if (undoOrder === "")
            return
        tileOrder = undoOrder
        tileSizes = undoSizes
        tileVisibility = undoVisibility
        tileDensity = undoDensity
        rebuildTiles()
        saveLayout()
    }

    function prepareToClose() {
        if (modelReady)
            saveLayout()
    }

    onTileOrderChanged: if (modelReady) rebuildTiles()
    onTileSizesChanged: if (modelReady) rebuildTiles()
    onTileVisibilityChanged: if (modelReady) rebuildTiles()
    Component.onCompleted: {
        undoOrder = tileOrder
        undoSizes = tileSizes
        undoVisibility = tileVisibility
        undoDensity = tileDensity
        modelReady = true
        rebuildTiles()
    }

    ListModel { id: tileModel }

    MeoQuickSettingsEditor {
        id: editor
        width: root.availableWidth
        tiles: root.editorTiles
        availableTiles: root.availableTiles
        columns: 4
        undoEnabled: root.undoOrder !== ""
        onBackRequested: {
            root.prepareToClose()
            root.backRequested()
        }
        onUndoRequested: root.restoreUndo()
        onTileMoved: (from, to) => root.moveVisibleTile(from, to)
        onTileResizeRequested: (index, span) => {
            const tile = root.editorTiles[index]
            if (tile)
                root.setTileSpan(tile.sourceIndex, span)
        }
        onTileRemoveRequested: (index, tile) => {
            if (tile)
                root.setTileVisible(tile.sourceIndex, false)
        }
        onTileAddRequested: (index, tile) => {
            if (tile)
                root.setTileVisible(tile.sourceIndex, true)
        }
    }
}
