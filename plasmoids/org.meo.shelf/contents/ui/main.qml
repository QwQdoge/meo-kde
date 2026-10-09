import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import MeoUI 1.0
import MeoKDE 1.0

// Meo owns only the launcher entry point. Plasma's org.kde.plasma.icontasks
// remains authoritative for pinned/running tasks, previews, grouping,
// context menus and drag/drop interaction.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: Plasmoid.configuration.showLauncherButton
                         && compactRepresentationItem
                         ? compactRepresentationItem.implicitWidth : 0
    Layout.maximumWidth: Layout.minimumWidth
    Layout.minimumHeight: 40 * MeoTheme.globalScale
    Component.onCompleted: MeoShellTheme.sync()

    // Googlebook exposes one primary launcher/search entry in the Taskbar.
    // Search stays inside LauncherPopup (and Alt+Space remains available), so
    // the shelf does not need a second permanent search button.
    compactRepresentation: MeoIconButton {
        visible: Plasmoid.configuration.showLauncherButton
        type: "tonal"
        size: "xs"
        contentItem: Kirigami.Icon {
            source: "meoarch-logo"
            implicitWidth: 24 * MeoTheme.globalScale
            implicitHeight: implicitWidth
        }
        Accessible.name: MeoI18n.translator.i18n("All apps")
        onClicked: launcherPopup.toggleFullLauncher()
    }

    // Plasma requires both representation slots even for a compact-only
    // entry applet; the actual launcher uses its separate popup window.
    fullRepresentation: Item {
        implicitWidth: Plasmoid.configuration.showLauncherButton
                       ? 40 * MeoTheme.globalScale : 0
        implicitHeight: 40 * MeoTheme.globalScale
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
