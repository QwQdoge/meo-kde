import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import MeoUI 1.0
import Meo.System 1.0 as MeoSystem

Item {
    id: root

    readonly property real scaleFactor: MeoTheme.globalScale

    function filteredApps() {
        const query = search.text.trim().toLowerCase()
        const source = MeoSystem.Tasks.startupApps || []
        const result = []
        for (let i = 0; i < source.length; ++i) {
            const app = source[i]
            const text = [
                app.name || "",
                app.exec || "",
                app.description || "",
                app.source || ""
            ].join(" ").toLowerCase()
            if (query === "" || text.indexOf(query) !== -1)
                result.push(app)
        }
        return result
    }

    readonly property var apps: filteredApps()

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: MeoTheme.space8

            MeoTextField {
                id: search
                Layout.fillWidth: true
                size: "s"
                type: "filled"
                placeholder: MeoI18n.translator.i18n("Search startup apps")
                leadingIcon: "search"
                showClearButton: true
            }

            MeoButton {
                text: MeoI18n.translator.i18n("Refresh")
                type: "text"
                size: "xs"
                icon.name: "refresh"
                onClicked: MeoSystem.Tasks.refreshStartupApps()
            }
        }

        PopupInlineMessage {
            Layout.fillWidth: true
            visible: MeoSystem.Tasks.actionError !== ""
            text: MeoSystem.Tasks.actionError
            tone: "warning"
            dismissible: true
            onDismissed: MeoSystem.Tasks.clearActionError()
        }

        MeoCard {
            Layout.fillWidth: true
            type: "filled"
            radius: MeoTheme.shapeLargeIncreased

            RowLayout {
                anchors.fill: parent
                anchors.margins: MeoTheme.space12
                spacing: MeoTheme.space12

                Rectangle {
                    width: 48 * root.scaleFactor
                    height: width
                    radius: 16 * root.scaleFactor
                    color: MeoTheme.tertiaryContainer

                    MeoIcon {
                        anchors.centerIn: parent
                        icon: "rocket_launch"
                        size: 26
                        fill: true
                        color: MeoTheme.contentOnTertiaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    MeoText {
                        text: MeoI18n.translator.i18n("Startup apps")
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                    }

                    MeoText {
                        Layout.fillWidth: true
                        text: MeoI18n.translator.i18n("%1 entries · XDG autostart").arg(root.apps.length)
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 2 * root.scaleFactor

                PopupEmptyState {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240 * root.scaleFactor
                    visible: root.apps.length === 0
                    iconName: "rocket_launch"
                    title: search.text.length > 0
                           ? MeoI18n.translator.i18n("No matching startup apps")
                           : MeoI18n.translator.i18n("No startup apps")
                    description: MeoI18n.translator.i18n("XDG autostart entries will appear here.")
                }

                Repeater {
                    model: root.apps

                    delegate: MeoListItem {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        headline: modelData.name || modelData.id
                        supportingText: modelData.description
                                        ? modelData.description + " · " + (modelData.exec || "")
                                        : (modelData.exec || "")
                        supportingTextLines: 2
                        leadingIcon: modelData.enabled ? "rocket_launch" : "block"
                        isSegmented: true
                        isEmphasized: modelData.enabled
                        selected: modelData.enabled
                        vibrant: false
                        roundingStrategy: root.apps.length === 1 ? "all"
                                          : index === 0 ? "top"
                                          : index === root.apps.length - 1 ? "bottom" : "middle"
                        onClicked: MeoSystem.Tasks.setStartupEnabled(modelData.id, !modelData.enabled)

                        trailingComponent: Component {
                            Row {
                                spacing: MeoTheme.space8

                                MeoChip {
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: modelData.source === "user"
                                           ? MeoI18n.translator.i18n("User")
                                           : MeoI18n.translator.i18n("System")
                                    leadingIcon: modelData.source === "user" ? "person" : "computer"
                                    type: "assist"
                                    shape: "pill"
                                    visualStyle: "outlined"
                                }

                                MeoSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: "s"
                                    checked: !!modelData.enabled
                                    Accessible.name: MeoI18n.translator.i18n("Run %1 at sign in").arg(modelData.name || modelData.id)
                                    onToggled: function(checked) {
                                        if (checked !== !!modelData.enabled)
                                            MeoSystem.Tasks.setStartupEnabled(modelData.id, checked)
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: MeoTheme.space8 }
            }
        }
    }
}
