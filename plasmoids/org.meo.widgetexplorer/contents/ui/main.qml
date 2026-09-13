pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

// A self-contained desktop utility, not a replacement for Plasma Edit Mode.
// Meo entries use the MeoWidget registry. Plasma entries remain actual Plasma
// packages, created by the current desktop containment through libplasma.
// Panels, taskbar, Dock, wallpaper, and containment configuration all stay
// under Plasma's normal ownership.
PlasmoidItem {
    id: root

    Plasmoid.title: qsTr("Meo Widget Explorer")
    toolTipMainText: Plasmoid.title
    toolTipSubText: qsTr("Add Meo and Plasma desktop widgets")
    preferredRepresentation: compactRepresentation

    property var contextWidget: null
    property alias widgetActionsSurface: widgetActions
    property string feedbackText: ""
    property bool feedbackIsError: false
    // One ordered catalogue keeps the two implementation sources in the same
    // user-facing picker.  The native bridge remains the authority for both
    // discovery and the later real Containment::createApplet() call.
    readonly property var widgetCatalog: MeoSystem.DesktopWidgets.catalog

    Layout.minimumWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth
                                                   : 56 * MeoTheme.globalScale
    Layout.minimumHeight: compactRepresentationItem ? compactRepresentationItem.implicitHeight
                                                    : 56 * MeoTheme.globalScale
    Layout.preferredWidth: Layout.minimumWidth
    Layout.preferredHeight: Layout.minimumHeight

    onExpandedChanged: {
        if (expanded)
            MeoSystem.DesktopWidgets.refreshPlasmaCatalog()
    }

    function suggestedGeometry(widget) {
        const width = widget.defaultWidth || 320
        const height = widget.defaultHeight || 220
        // The bridge clamps geometry and Plasma remains authoritative if this
        // hint collides with another desktop applet.
        return Qt.rect(Math.max(16, root.x + root.width + MeoTheme.space16),
                       Math.max(16, root.y), width, height)
    }

    function addDesktopWidget(widget) {
        if (!widget)
            return
        const added = widget.host === "meo"
                ? MeoSystem.DesktopWidgets.addMeoWidget(Plasmoid.containment, widget.id,
                                                        suggestedGeometry(widget))
                : MeoSystem.DesktopWidgets.addPlasmaWidget(Plasmoid.containment, widget.pluginId,
                                                           suggestedGeometry(widget))
        if (added) {
            feedbackText = qsTr("Added %1 to the desktop.").arg(widget.title)
            feedbackIsError = false
        } else {
            feedbackText = MeoSystem.DesktopWidgets.lastError
            feedbackIsError = true
        }
    }

    function sourceLabel(widget) {
        if (widget.host === "meo")
            return qsTr("Meo Widget")
        return widget.source === "user"
                ? qsTr("Plasma Widget · User package")
                : qsTr("Plasma Widget · Compatibility mode")
    }

    function openWidgetContext(widget, anchor, localX, localY) {
        contextWidget = widget
        const isMeo = widget.host === "meo"
        root.widgetActionsSurface.model = [
            {
                "label": qsTr("Add to desktop"),
                "icon": "add",
                "enabled": widget.available,
                "action": function() { root.addDesktopWidget(root.contextWidget) }
            },
            {
                "type": "separator"
            },
            {
                "label": root.sourceLabel(widget),
                "icon": isMeo ? "widgets" : "extension",
                "enabled": false
            },
            {
                "label": isMeo && widget.lockScreenEligible
                         ? qsTr("Available on lock screen through a reviewed Meo adapter")
                         : qsTr("Desktop only; generic Plasma packages never run in the lock screen"),
                "icon": isMeo && widget.lockScreenEligible ? "lock" : "desktop_windows",
                "enabled": false
            }
        ]
        root.widgetActionsSurface.openAtPoint(anchor, localX, localY)
    }

    compactRepresentation: QQC2.AbstractButton {
        id: compactRepresentationItem
        implicitWidth: 56 * MeoTheme.globalScale
        implicitHeight: 56 * MeoTheme.globalScale
        hoverEnabled: true
        Accessible.name: qsTr("Open Meo Widget Explorer")
        onClicked: root.expanded = !root.expanded

        background: MeoShape {
            type: "rect"
            radius: compactRepresentationItem.hovered || compactRepresentationItem.down
                    ? MeoTheme.shapeLarge : MeoTheme.shapeExtraLarge
            color: compactRepresentationItem.hovered || compactRepresentationItem.down || root.expanded
                   ? MeoTheme.secondaryContainer : MeoTheme.surfaceContainerLow
            strokeWidth: MeoTheme.strokeWidthThin
            strokeColor: MeoTheme.outlineVariant
        }
        contentItem: MeoIcon {
            anchors.centerIn: parent
            icon: "widgets"
            size: 28
            color: MeoTheme.contentOnSecondaryContainer
        }
    }

    fullRepresentation: Item {
        id: explorerSurface
        // This follows the ChromeOS-style broad sheet composition. The
        // eventual shell overlay may add the desktop blur/dim backdrop, but
        // this applet remains deliberately scoped to its own safe surface.
        implicitWidth: 1120 * MeoTheme.globalScale
        implicitHeight: 680 * MeoTheme.globalScale

        MeoWidgetSheet {
            anchors.fill: parent
            catalog: root.widgetCatalog
            feedbackText: root.feedbackText
            feedbackIsError: root.feedbackIsError
            onWidgetActivated: function(widget) {
                root.addDesktopWidget(widget)
            }
            onWidgetContextRequested: function(widget, anchor) {
                root.openWidgetContext(widget, anchor, anchor.width / 2, anchor.height / 2)
            }
            onRefreshRequested: MeoSystem.DesktopWidgets.refreshPlasmaCatalog()
            onCloseRequested: root.expanded = false
        }

    }

    MeoContextMenu {
        id: widgetActions
        parent: root
        z: 100
    }
}
