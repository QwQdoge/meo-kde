import QtQuick
import QtQuick.Controls
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

    PerformanceManager {
        anchors.fill: parent
        anchors.margins: MeoTheme.space16
        initialPage: 0
        onCloseRequested: window.close()
    }
}
