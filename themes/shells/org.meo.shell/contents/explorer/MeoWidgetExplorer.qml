/*
    SPDX-FileCopyrightText: 2026 Meo Desktop Team
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.core as PlasmaCore
import MeoUI 1.0
import MeoKDE 1.0

// Floating Meo widget browser opened by the desktop right-click menu.
// `desktop` is the DesktopView context property provided by plasmashell.
PlasmaCore.Dialog {
    id: dialog

    property QtObject targetContainment: null
    property bool addedWidgets: false

    readonly property rect screenRect: desktop ? desktop.screenGeometry : Qt.rect(0, 0, 1280, 800)
    readonly property real gutter: MeoTheme.space16 * 2

    function openFor(containment) {
        targetContainment = containment
        addedWidgets = false
        browser.reset()
        browser.refresh()
        visible = true
        browser.forceActiveFocus()
    }

    function close() {
        visible = false
    }

    type: PlasmaCore.Dialog.Dock
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true
    visible: false

    x: screenRect.x + Math.round((screenRect.width - width) / 2)
    y: screenRect.y + Math.round((screenRect.height - height) / 2)

    onVisibleChanged: {
        // Plasma enters Edit Mode before opening any widget explorer. Leave it
        // again when nothing was added, so browsing feels like a menu; stay in
        // it after an addition so the new widget can be moved right away.
        if (!visible && !addedWidgets && targetContainment && targetContainment.corona)
            targetContainment.corona.editMode = false
    }

    mainItem: Item {
        width: Math.min(1080 * MeoTheme.globalScale, dialog.screenRect.width - dialog.gutter * 2)
        height: Math.min(660 * MeoTheme.globalScale, dialog.screenRect.height - dialog.gutter * 2)

        MeoShape {
            anchors.fill: parent
            type: "rect"
            radius: MeoTheme.dialogRadius
            color: MeoTheme.surfaceContainerLow
            strokeWidth: 0
        }

        DesktopWidgetExplorer {
            id: browser
            anchors.fill: parent
            containment: dialog.targetContainment
            placementOrigin: Qt.point(dialog.gutter * 2, dialog.gutter * 2)
            onCloseRequested: dialog.close()
            onWidgetAdded: dialog.addedWidgets = true
        }
    }
}
