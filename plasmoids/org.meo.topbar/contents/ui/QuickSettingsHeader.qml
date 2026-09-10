import QtQuick
import QtQuick.Layouts
import MeoUI 1.0

// Pure presentation of the live system header. Backend state stays in
// MeoKDE; the home page owns edit-mode and page composition.
RowLayout {
    id: root

    property bool editMode: false
    // The host supplies the real singleton; isolated smoke tests can provide
    // the same state contract without the presentation layer owning backend.
    required property var systemState

    Layout.fillWidth: true

    ColumnLayout {
        spacing: 0
        MeoText { id: timeText; typeRole: "title"; typeSize: "large"; emphasized: true; color: MeoTheme.onSurface }
        MeoText { id: dateText; typeRole: "body"; typeSize: "medium"; color: MeoTheme.onSurfaceVariant }
    }
    Item { Layout.fillWidth: true }
    MeoText {
        visible: root.editMode
        text: qsTr("Drag to reorder · use arrows to resize")
        typeRole: "label"
        typeSize: "small"
        color: MeoTheme.primary
    }
    RowLayout {
        visible: root.systemState.batteryAvailable && !root.editMode
        spacing: MeoTheme.space4
        MeoIcon { icon: root.systemState.batteryCharging ? "battery_charging_full" : "battery_full"; size: 20; color: MeoTheme.onSurfaceVariant }
        MeoText { text: root.systemState.batteryPercent + "%"; typeRole: "label"; typeSize: "medium"; emphasized: true; color: MeoTheme.onSurface }
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            timeText.text = Qt.formatDateTime(now, "hh:mm")
            dateText.text = Qt.formatDateTime(now, "dddd, MMMM d")
        }
    }
}
