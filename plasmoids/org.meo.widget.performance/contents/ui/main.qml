pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem
import MeoKDE 1.0

PlasmoidItem {
    id: root

    Plasmoid.title: MeoI18n.translator.i18n("Meo Performance")
    toolTipMainText: Plasmoid.title
    toolTipSubText: MeoI18n.translator.i18n("CPU, memory, GPU, disk and network")
    preferredRepresentation: fullRepresentation

    property bool managerOpen: false
    readonly property string clientId: "performance-widget-" + root.toString()

    Layout.minimumWidth: 320 * MeoTheme.globalScale
    Layout.minimumHeight: 220 * MeoTheme.globalScale
    Layout.preferredWidth: managerOpen ? 760 * MeoTheme.globalScale : 500 * MeoTheme.globalScale
    Layout.preferredHeight: managerOpen ? 560 * MeoTheme.globalScale : 330 * MeoTheme.globalScale

    function formatBytes(value) {
        const bytes = Math.max(0, Number(value) || 0)
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let size = bytes
        let unit = 0
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024
            ++unit
        }
        return (unit >= 3 ? size.toFixed(1) : size.toFixed(unit === 0 ? 0 : 1)) + " " + units[unit]
    }

    function formatRate(value) {
        return formatBytes(value) + "/s"
    }

    function syncSubscription() {
        if (visible) {
            MeoSystem.Performance.subscribe(clientId,
                ["cpu", "memory", "network", "disk", "gpu", "system"])
        } else {
            MeoSystem.Performance.unsubscribe(clientId)
        }
    }

    Component.onCompleted: syncSubscription()
    Component.onDestruction: MeoSystem.Performance.unsubscribe(clientId)
    onVisibleChanged: syncSubscription()

    fullRepresentation: Item {
        implicitWidth: root.managerOpen ? 760 * MeoTheme.globalScale : 500 * MeoTheme.globalScale
        implicitHeight: root.managerOpen ? 560 * MeoTheme.globalScale : 330 * MeoTheme.globalScale

        MeoWidget {
            anchors.fill: parent
            widgetId: "performance"
            preferredSize: root.managerOpen ? MeoWidget.SizeExtraLarge : MeoWidget.SizeLarge
            supportedSizes: [MeoWidget.SizeMedium, MeoWidget.SizeLarge, MeoWidget.SizeExtraLarge]
            privacy: MeoWidget.Local
            refreshPolicy: MeoWidget.Periodic
            supportedSurfaces: [MeoWidget.Desktop]
            frameMode: MeoWidget.Adaptive
            wantsOwnBackground: false
            accessibleName: Plasmoid.title
            accessibleDescription: MeoI18n.translator.i18n("Live local system performance")

            Loader {
                anchors.fill: parent
                sourceComponent: root.managerOpen ? managerComponent : summaryComponent
            }
        }
    }

    Component {
        id: managerComponent

        PerformanceManager {
            initialPage: 1
            onCloseRequested: root.managerOpen = false
        }
    }

    Component {
        id: summaryComponent

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MeoText {
                            text: MeoI18n.translator.i18n("Performance")
                            typeRole: "title"
                            typeSize: "large"
                            emphasized: true
                        }
                        MeoText {
                            Layout.fillWidth: true
                            text: MeoSystem.Performance.cpuModel
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    MeoButton {
                        text: MeoI18n.translator.i18n("Details")
                        type: "tonal"
                        size: "xs"
                        icon.name: "monitoring"
                        onClicked: root.managerOpen = true
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: width >= 430 * MeoTheme.globalScale ? 2 : 1
                    rowSpacing: MeoTheme.space8
                    columnSpacing: MeoTheme.space8

                    MetricCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: "CPU"
                        iconName: "memory"
                        valueText: MeoSystem.Performance.cpuUsage.toFixed(0) + "%"
                        subtitle: MeoSystem.Performance.cpuTemperature > 0
                                  ? Math.round(MeoSystem.Performance.cpuTemperature) + "°C"
                                  : (MeoSystem.Performance.cpuFrequencyMHz > 0
                                     ? Math.round(MeoSystem.Performance.cpuFrequencyMHz) + " MHz"
                                     : "")
                        progressValue: MeoSystem.Performance.cpuUsage
                        history: MeoSystem.Performance.cpuHistory
                        accentColor: MeoTheme.primary
                    }

                    MetricCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: MeoI18n.translator.i18n("Memory")
                        iconName: "memory_alt"
                        valueText: MeoSystem.Performance.memoryUsage.toFixed(0) + "%"
                        subtitle: root.formatBytes(MeoSystem.Performance.memoryUsedBytes)
                                  + " / " + root.formatBytes(MeoSystem.Performance.memoryTotalBytes)
                        progressValue: MeoSystem.Performance.memoryUsage
                        history: MeoSystem.Performance.memoryHistory
                        accentColor: MeoTheme.secondary
                    }

                    MetricCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: MeoI18n.translator.i18n("Network")
                        iconName: "swap_horiz"
                        valueText: "↓ " + root.formatRate(MeoSystem.Performance.networkRxBytesPerSecond)
                        subtitle: "↑ " + root.formatRate(MeoSystem.Performance.networkTxBytesPerSecond)
                        progressValue: -1
                        history: MeoSystem.Performance.networkRxHistory
                        secondaryHistory: MeoSystem.Performance.networkTxHistory
                        accentColor: MeoTheme.primary
                        secondaryAccentColor: MeoTheme.tertiary
                    }

                    MetricCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: MeoI18n.translator.i18n("GPU")
                        iconName: "developer_board"
                        valueText: MeoSystem.Performance.gpuUsage >= 0
                                   ? MeoSystem.Performance.gpuUsage.toFixed(0) + "%"
                                   : "—"
                        subtitle: MeoSystem.Performance.gpuTemperature > 0
                                  ? Math.round(MeoSystem.Performance.gpuTemperature) + "°C"
                                  : MeoSystem.Performance.gpuName
                        progressValue: MeoSystem.Performance.gpuUsage
                        history: MeoSystem.Performance.gpuHistory
                        accentColor: MeoTheme.tertiary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space12
                    MeoText {
                        Layout.fillWidth: true
                        text: MeoI18n.translator.i18n("Disk R %1 · W %2")
                              .arg(root.formatRate(MeoSystem.Performance.diskReadBytesPerSecond))
                              .arg(root.formatRate(MeoSystem.Performance.diskWriteBytesPerSecond))
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                    MeoText {
                        text: MeoSystem.Platform.powerProfilesAvailable
                              ? (MeoSystem.Platform.activePowerProfile === "performance"
                                 ? MeoI18n.translator.i18n("Performance")
                                 : MeoSystem.Platform.activePowerProfile === "power-saver"
                                   ? MeoI18n.translator.i18n("Power saver")
                                   : MeoI18n.translator.i18n("Balanced"))
                              : ""
                        typeRole: "label"
                        typeSize: "small"
                        emphasized: true
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }
            }
        }
    }
}
