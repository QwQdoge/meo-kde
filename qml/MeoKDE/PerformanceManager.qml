import QtQuick
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    signal closeRequested()

    property int initialPage: 0
    property int currentPage: initialPage
    readonly property string clientId: "performance-manager-" + root.toString()
    readonly property real scaleFactor: MeoTheme.globalScale

    function syncSubscription() {
        if (!visible) {
            MeoSystem.Performance.unsubscribe(clientId)
            return
        }

        if (currentPage === 0) {
            MeoSystem.Performance.subscribe(clientId,
                ["cpu", "memory", "system", "processes"])
        } else {
            MeoSystem.Performance.subscribe(clientId,
                ["cpu", "memory", "network", "disk", "gpu", "system"])
        }
    }

    Component.onCompleted: syncSubscription()
    Component.onDestruction: MeoSystem.Performance.unsubscribe(clientId)
    onVisibleChanged: syncSubscription()
    onCurrentPageChanged: syncSubscription()

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoButton {
                text: MeoI18n.translator.i18n("Back")
                type: "text"
                size: "xs"
                icon.name: "arrow_back"
                onClicked: root.closeRequested()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    text: MeoI18n.translator.i18n("System monitor")
                    typeRole: "title"
                    typeSize: "large"
                    emphasized: true
                }

                MeoText {
                    Layout.fillWidth: true
                    text: root.currentPage === 0
                          ? MeoI18n.translator.i18n("%1 processes").arg(MeoSystem.Performance.processCount)
                          : MeoSystem.Performance.systemSummary
                    typeRole: "body"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            MeoButton {
                text: MeoI18n.translator.i18n("Refresh")
                type: "tonal"
                size: "xs"
                icon.name: "refresh"
                onClicked: MeoSystem.Performance.refreshNow()
            }
        }

        MeoTabs {
            Layout.fillWidth: true
            type: "secondary"
            style: "standard"
            currentIndex: root.currentPage
            model: [
                {
                    label: MeoI18n.translator.i18n("Processes"),
                    icon: "apps"
                },
                {
                    label: MeoI18n.translator.i18n("Performance"),
                    icon: "monitoring"
                }
            ]
            onClicked: function(index) {
                root.currentPage = index
            }
        }

        ProcessTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentPage === 0
        }

        PerformanceDashboard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentPage === 1
        }
    }
}
