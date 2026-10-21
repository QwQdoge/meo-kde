import QtQuick
import QtQuick.Controls as QQC2
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
    compactRepresentation: QQC2.AbstractButton {
        id: launcherButton
        visible: Plasmoid.configuration.showLauncherButton
        implicitWidth: 60 * MeoTheme.globalScale
        implicitHeight: 36 * MeoTheme.globalScale
        hoverEnabled: true
        Accessible.name: MeoI18n.translator.i18n("All apps")
        onClicked: launcherPopup.toggleFullLauncher()

        // The Meo entry sits in a small pill, a little darker than the Shelf,
        // like the launcher group in the Googlebook taskbar.
        background: ShellTriggerSurface {
            hovered: launcherButton.hovered
            pressed: launcherButton.down
            focused: launcherButton.visualFocus
            restingColor: Qt.rgba(MeoTheme.onSurface.r, MeoTheme.onSurface.g,
                                  MeoTheme.onSurface.b, 0.10)
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                source: "meoarch-logo"
                width: 24 * MeoTheme.globalScale
                height: width
            }
        }
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
