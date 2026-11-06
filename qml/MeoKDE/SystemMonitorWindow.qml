import QtQuick
import QtQuick.Controls
import QtCore
import MeoUI 1.0

ApplicationWindow {
    id: window

    width: 1100 * MeoTheme.globalScale
    height: 760 * MeoTheme.globalScale
    minimumWidth: 420 * MeoTheme.globalScale
    minimumHeight: 520 * MeoTheme.globalScale
    visible: true
    title: MeoI18n.translator.i18n("System monitor")
    color: MeoTheme.surface

    // Reopen at the size and on the page the user left, like a desktop task
    // manager (stored in the app's own config, not in shell settings).
    Settings {
        category: "Window"
        property alias width: window.width
        property alias height: window.height
        property alias page: manager.currentPage
    }

    // Standard desktop close shortcut for the standalone window.
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.WindowShortcut
        onActivated: window.close()
    }

    PerformanceManager {
        id: manager
        anchors.fill: parent
        anchors.margins: MeoTheme.space16
        initialPage: 0
        showBackButton: false
        onCloseRequested: window.close()
    }
}
