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
        id: windowSettings
        category: "Window"
        property alias width: window.width
        property alias height: window.height
        property int page: 0
    }

    // Standard desktop close shortcut for the standalone window.
    Shortcut {
        sequence: "Ctrl+W"
        context: Qt.WindowShortcut
        onActivated: window.close()
    }

    // The window frame paints first; the monitor itself is created
    // asynchronously so Ctrl+Shift+Esc shows a window immediately even on a
    // busy system.
    Loader {
        id: content
        anchors.fill: parent
        anchors.margins: MeoTheme.space16
        asynchronous: true
        sourceComponent: Component {
            PerformanceManager {
                id: manager
                initialPage: 0
                showBackButton: false
                onCloseRequested: window.close()
                onCurrentPageChanged: windowSettings.page = currentPage
                Component.onCompleted: currentPage = Math.max(0, Math.min(5, windowSettings.page))
            }
        }
    }

    MeoLoadingFeedback {
        anchors.centerIn: parent
        width: 200 * MeoTheme.globalScale
        height: 72 * MeoTheme.globalScale
        active: content.status !== Loader.Ready
        delay: 150
        accessibleName: MeoI18n.translator.i18n("Loading system monitor")
    }
}
