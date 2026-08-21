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

    Component.onCompleted: MeoShellTheme.sync()

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
        onTileLayoutChanged: function(order, sizes) {
            Plasmoid.configuration.quickTileOrder = order
            Plasmoid.configuration.quickTileSizes = sizes
        }
    }
}
