import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import MeoUI 1.0
import MeoKDE 1.0
import "components"

PlasmoidItem {
    id: root

    readonly property real localTextScale: Math.max(0.75, Math.min(1.5,
        Number(Plasmoid.configuration.textScalePercent) / 100.0))
    readonly property real compactWidth: Math.ceil(compactRepresentationItem
                                                    ? compactRepresentationItem.implicitWidth
                                                    : 112 * MeoTheme.globalScale)
    readonly property real compactHeight: ShellMetrics.topBarHeight

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Meo Quick Settings")
    toolTipMainText: MeoI18n.translator.i18n("Meo Quick Settings")
    toolTipSubText: MeoI18n.translator.i18n("Network, audio, display, and power controls")
    // A panel must always use the compact representation.  Without these
    // constraints Plasma can reserve the much larger popup width in the panel.
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: compactWidth
    Layout.preferredWidth: compactWidth
    Layout.maximumWidth: compactWidth
    Layout.minimumHeight: compactHeight
    Layout.preferredHeight: compactHeight
    Layout.maximumHeight: compactHeight

    readonly property string legacyQuickTileSizes: "wifi:1,bluetooth:2,focus:1,nightLight:1,keepAwake:1,powerMode:1,microphone:1,audioDevices:2,display:1,screenshot:1"
    readonly property string pillQuickTileSizes: "wifi:2,bluetooth:2,focus:2,nightLight:2,keepAwake:2,powerMode:2,microphone:2,audioDevices:2,display:2,screenshot:2"

    Component.onCompleted: {
        MeoShellTheme.sync()
        if (Plasmoid.configuration.quickTileSizes === legacyQuickTileSizes)
            Plasmoid.configuration.quickTileSizes = pillQuickTileSizes
        // density is the public per-instance key.  Keep the original tile
        // key as a compatibility mirror so prior custom arrangements survive.
        if (Plasmoid.configuration.density === "comfortable"
                && Plasmoid.configuration.quickTileDensity !== "comfortable")
            Plasmoid.configuration.density = Plasmoid.configuration.quickTileDensity
        else if (Plasmoid.configuration.density !== Plasmoid.configuration.quickTileDensity)
            Plasmoid.configuration.quickTileDensity = Plasmoid.configuration.density
    }
    onExpandedChanged: if (root.expanded) { root.expanded = false; popup.visible = true }

    compactRepresentation: Item {
        id: compactRoot
        implicitWidth: systemStatus.implicitWidth
        implicitHeight: ShellMetrics.topBarHeight

        SystemStatusCluster {
            id: systemStatus
            anchors.centerIn: parent
            active: popup.visible
            textScale: root.localTextScale
            showNetwork: Plasmoid.configuration.showNetwork
            showBluetooth: Plasmoid.configuration.showBluetooth
            showVolume: Plasmoid.configuration.showVolume
            batteryDisplay: Plasmoid.configuration.batteryDisplay
            onQuickSettingsRequested: popup.visible = !popup.visible
        }
    }

    fullRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }
    PlasmaCore.Dialog {
        id: popup
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.TopEdge
        visualParent: root.compactRepresentationItem
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() { popup.requestActivate(); popup.mainItem.forceActiveFocus() })
            } else if (mainItem && mainItem.prepareToClose) {
                // Persist a pending tile-editor change when the popup closes.
                mainItem.prepareToClose()
            }
        }
        mainItem: QuickSettingsCenter {
        Keys.onEscapePressed: popup.visible = false
        revealActive: popup.visible
        tileOrder: Plasmoid.configuration.quickTileOrder
        tileSizes: Plasmoid.configuration.quickTileSizes
        tileVisibility: Plasmoid.configuration.quickTileVisibility
        tileDensity: Plasmoid.configuration.density
        onTileLayoutChanged: function(order, sizes, visibility, density) {
            Plasmoid.configuration.quickTileOrder = order
            Plasmoid.configuration.quickTileSizes = sizes
            Plasmoid.configuration.quickTileVisibility = visibility
            Plasmoid.configuration.quickTileDensity = density
            Plasmoid.configuration.density = density
        }
    }
    }

    DialogBlur { dialog: popup }
}
