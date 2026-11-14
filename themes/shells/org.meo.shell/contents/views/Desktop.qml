/*
    SPDX-FileCopyrightText: 2026 Meo Desktop Team
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

// Meo Desktop view adapter.
//
// The desktop itself (containment, Edit Mode, activity switcher) stays the
// unmodified org.kde.plasma.desktop view, loaded below. Only the widget
// explorer that plasmashell opens from the desktop right-click menu or the
// Edit Mode toolbar ("Add or Manage Widgets…") is replaced with the Meo widget
// browser. If the Meo modules cannot be loaded, the stock KDE explorer opens
// instead, so the desktop never loses its widget entry point.
Item {
    id: root

    // Set by PlasmaQuick::ContainmentView.
    property Item containment
    // Kept for API compatibility with the upstream view.
    property QtObject widgetExplorer: upstream.item ? upstream.item.widgetExplorer : null

    // The fallback shell package normally sits next to this one; the second
    // entry covers a per-user (~/.local) installation of org.meo.shell.
    readonly property var upstreamCandidates: [
        Qt.resolvedUrl("../../../org.kde.plasma.desktop/contents/views/Desktop.qml"),
        "file:///usr/share/plasma/shells/org.kde.plasma.desktop/contents/views/Desktop.qml"
    ]
    property int upstreamIndex: 0

    function toggleWidgetExplorer(requestingContainment) {
        if (meoExplorer.item && meoExplorer.item.visible) {
            meoExplorer.item.close()
            return
        }
        meoExplorer.active = true
        if (meoExplorer.status === Loader.Ready && meoExplorer.item) {
            meoExplorer.item.openFor(requestingContainment || (root.containment ? root.containment.plasmoid : null))
        } else if (upstream.item) {
            // Meo widget browser unavailable: keep the KDE explorer working.
            upstream.item.toggleWidgetExplorer(requestingContainment)
        }
    }

    function toggleActivityManager() {
        if (upstream.item)
            upstream.item.toggleActivityManager()
    }

    Loader {
        id: upstream
        anchors.fill: parent
        source: root.upstreamCandidates[root.upstreamIndex]
        onStatusChanged: {
            if (status === Loader.Error && root.upstreamIndex + 1 < root.upstreamCandidates.length)
                root.upstreamIndex += 1
        }
        onLoaded: item.containment = Qt.binding(function() { return root.containment })
    }

    Loader {
        id: meoExplorer
        active: false
        source: Qt.resolvedUrl("../explorer/MeoWidgetExplorer.qml")
    }
}
