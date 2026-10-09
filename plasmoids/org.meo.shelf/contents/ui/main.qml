import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import MeoUI 1.0
import MeoKDE 1.0

// Only the two entry actions live here. Plasma's org.kde.plasma.icontasks
// applet owns every task, preview, context menu and drag/drop interaction.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth : 100 * MeoTheme.globalScale
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: 40 * MeoTheme.globalScale
    Component.onCompleted: MeoShellTheme.sync()

    compactRepresentation: entryButtons
    fullRepresentation: entryButtons
    Component {
        id: entryButtons
        MeoButtonGroup {
        variant: "connected"
        type: "tonal"
        size: "xs"
        currentIndex: -1
        selectionWidthDelta: 0
        accessibleName: MeoI18n.translator.i18n("Applications and search")
        model: [
            { label: MeoI18n.translator.i18n("Applications"), icon: "apps", compactWhenUnselected: true },
            { label: MeoI18n.translator.i18n("Search"), icon: "search", compactWhenUnselected: true }
        ]
        onSelected: function(index, data) {
            currentIndex = -1
            if (index === 0) launcherPopup.toggleFullLauncher()
            else launcherPopup.openQuickSearch()
        }
    }
    }
    Connections {
        target: Plasmoid
        function onActivated() { launcherPopup.toggleFullLauncher() }
    }
    LauncherPopup {
        id: launcherPopup
        objectName: "meoLauncherPopup"
        shellApplet: root
        defaultPage: Plasmoid.configuration.launcherDefaultPage || "apps"
        widthPreset: Plasmoid.configuration.launcherWidth || "standard"
        placementMode: Plasmoid.configuration.launcherPlacement || "center"
        showFavoritesSection: Plasmoid.configuration.launcherShowFavorites
        showRecentSection: Plasmoid.configuration.launcherShowRecents
    }
}
