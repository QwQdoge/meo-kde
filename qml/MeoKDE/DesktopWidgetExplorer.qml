pragma ComponentBehavior: Bound

import QtQuick
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

// Shared body of the Meo widget browser. The desktop right-click / Edit Mode
// "Add Widgets" entry of the org.meo.shell package and the optional
// org.meo.widgetexplorer applet both host it; Plasma still owns placement,
// persistence and the applet lifecycle through Plasma::Containment.
Item {
    id: root

    // The real Plasma::Containment that receives new widgets.
    property QObject containment: null
    // Where the first new widget is placed, in containment coordinates.
    // Later additions cascade so they never land exactly on top of each other.
    property point placementOrigin: Qt.point(MeoTheme.space16 * 4, MeoTheme.space16 * 4)
    property int addedCount: 0
    property string feedbackText: ""
    property bool feedbackIsError: false
    readonly property var widgetCatalog: MeoSystem.DesktopWidgets.catalog
    property var contextWidget: null

    signal closeRequested()
    signal widgetAdded(var widget)

    implicitWidth: 1080 * MeoTheme.globalScale
    implicitHeight: 660 * MeoTheme.globalScale

    function refresh() {
        MeoSystem.DesktopWidgets.refreshPlasmaCatalog()
    }

    function reset() {
        addedCount = 0
        feedbackText = ""
        feedbackIsError = false
    }

    function suggestedGeometry(widget) {
        const width = widget.defaultWidth || 320
        const height = widget.defaultHeight || 220
        const step = MeoTheme.space16 * 2
        const offset = (addedCount % 6) * step
        return Qt.rect(Math.max(MeoTheme.space16, placementOrigin.x + offset),
                       Math.max(MeoTheme.space16, placementOrigin.y + offset), width, height)
    }

    function addDesktopWidget(widget) {
        if (!widget || !containment)
            return
        const added = widget.host === "meo"
                ? MeoSystem.DesktopWidgets.addMeoWidget(containment, widget.id, suggestedGeometry(widget))
                : MeoSystem.DesktopWidgets.addPlasmaWidget(containment, widget.pluginId,
                                                           suggestedGeometry(widget))
        if (added) {
            addedCount += 1
            feedbackText = MeoI18n.translator.i18n("Added %1 to the Home screen.", widget.title)
            feedbackIsError = false
            widgetAdded(widget)
        } else {
            feedbackText = MeoSystem.DesktopWidgets.lastError
            feedbackIsError = true
        }
    }

    function sourceLabel(widget) {
        if (widget.host === "meo")
            return MeoI18n.translator.i18n("Meo Widget")
        return widget.source === "user"
                ? MeoI18n.translator.i18n("Plasma Widget · User package")
                : MeoI18n.translator.i18n("Plasma Widget · Compatibility mode")
    }

    function openWidgetContext(widget, anchor, localX, localY) {
        contextWidget = widget
        const isMeo = widget.host === "meo"
        widgetActions.model = [
            {
                "label": MeoI18n.translator.i18n("Add to Home screen"),
                "icon": "add",
                "enabled": widget.available,
                "action": function() { root.addDesktopWidget(root.contextWidget) }
            },
            { "type": "separator" },
            {
                "label": root.sourceLabel(widget),
                "icon": isMeo ? "widgets" : "extension",
                "enabled": false
            },
            {
                "label": isMeo && widget.lockScreenEligible
                         ? MeoI18n.translator.i18n("Available on lock screen through a reviewed Meo adapter")
                         : MeoI18n.translator.i18n("Desktop only; generic Plasma packages never run in the lock screen"),
                "icon": isMeo && widget.lockScreenEligible ? "lock" : "desktop_windows",
                "enabled": false
            }
        ]
        widgetActions.openAtPoint(anchor, localX, localY)
    }

    Keys.onEscapePressed: root.closeRequested()

    MeoWidgetSheet {
        anchors.fill: parent
        catalog: root.widgetCatalog
        feedbackText: root.feedbackText
        feedbackIsError: root.feedbackIsError
        onWidgetActivated: function(widget) { root.addDesktopWidget(widget) }
        onWidgetContextRequested: function(widget, anchor) {
            root.openWidgetContext(widget, anchor, anchor.width / 2, anchor.height / 2)
        }
        onRefreshRequested: root.refresh()
        onCloseRequested: root.closeRequested()
    }

    MeoContextMenu {
        id: widgetActions
        parent: root
        z: 100
    }
}
