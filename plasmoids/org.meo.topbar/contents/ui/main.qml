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
    Plasmoid.title: qsTr("Meo Quick Settings")
    toolTipMainText: qsTr("Meo Quick Settings")
    toolTipSubText: qsTr("Network, audio, display, and power controls")
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
    }
    onExpandedChanged: if (!root.expanded && root.fullRepresentationItem
                           && root.fullRepresentationItem.prepareToClose)
                           root.fullRepresentationItem.prepareToClose()

    compactRepresentation: Item {
        id: compactRoot
        implicitWidth: systemStatus.implicitWidth + 2 * MeoTheme.space4
        implicitHeight: ShellMetrics.topBarHeight

        SystemStatusCluster {
            id: systemStatus
            anchors.centerIn: parent
            textScale: root.localTextScale
            showNetwork: Plasmoid.configuration.showNetwork
            showBluetooth: Plasmoid.configuration.showBluetooth
            showVolume: Plasmoid.configuration.showVolume
            batteryDisplay: Plasmoid.configuration.batteryDisplay
            onQuickSettingsRequested: root.expanded = !root.expanded
        }
    }

    fullRepresentation: QuickSettingsCenter {
        tileOrder: Plasmoid.configuration.quickTileOrder
        tileSizes: Plasmoid.configuration.quickTileSizes
        tileVisibility: Plasmoid.configuration.quickTileVisibility
        tileDensity: Plasmoid.configuration.quickTileDensity
        onTileLayoutChanged: function(order, sizes, visibility, density) {
            Plasmoid.configuration.quickTileOrder = order
            Plasmoid.configuration.quickTileSizes = sizes
            Plasmoid.configuration.quickTileVisibility = visibility
            Plasmoid.configuration.quickTileDensity = density
        }
    }
}
