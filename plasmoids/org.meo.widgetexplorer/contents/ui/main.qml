pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem
import MeoKDE 1.0

// Optional desktop applet host for the Meo widget browser. Meo Desktop does
// not place it by default: the browser opens from the desktop right-click /
// Edit Mode "Add Widgets" action of the org.meo.shell package. Users who want
// a visible button can still add this applet themselves. Panels, taskbar,
// wallpaper and containment configuration remain under Plasma ownership.
PlasmoidItem {
    id: root

    Plasmoid.title: MeoI18n.translator.i18n("Browse widgets")
    toolTipMainText: Plasmoid.title
    toolTipSubText: MeoI18n.translator.i18n("Add widgets to your Home screen")
    preferredRepresentation: compactRepresentation

    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth
                                                   : 48 * MeoTheme.globalScale
    Layout.minimumHeight: compactRepresentationItem ? compactRepresentationItem.implicitHeight
                                                    : 48 * MeoTheme.globalScale
    Layout.preferredWidth: Layout.minimumWidth
    Layout.preferredHeight: Layout.minimumHeight

    compactRepresentation: QQC2.AbstractButton {
        id: compactRepresentationItem
        implicitWidth: 48 * MeoTheme.globalScale
        implicitHeight: 48 * MeoTheme.globalScale
        hoverEnabled: true
        Accessible.name: MeoI18n.translator.i18n("Browse widgets")
        onClicked: root.expanded = !root.expanded

        background: MeoShape {
            type: "rect"
            radius: width / 2
            color: compactRepresentationItem.hovered || compactRepresentationItem.down || root.expanded
                   ? MeoTheme.secondaryContainer : "transparent"
            strokeWidth: 0
        }
        contentItem: MeoIcon {
            anchors.centerIn: parent
            icon: "widgets"
            size: 26
            color: compactRepresentationItem.hovered || compactRepresentationItem.down || root.expanded
                   ? MeoTheme.contentOnSecondaryContainer : MeoTheme.contentOnSurface
        }
    }

    fullRepresentation: DesktopWidgetExplorer {
        id: explorer
        containment: Plasmoid.containment
        placementOrigin: Qt.point(root.x + root.width + MeoTheme.space16, root.y)
        onCloseRequested: root.expanded = false
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    explorer.reset()
                    explorer.refresh()
                }
            }
        }
    }
}
