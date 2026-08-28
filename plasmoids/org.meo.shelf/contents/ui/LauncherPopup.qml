pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import MeoUI 1.0
import MeoKDE 1.0

QQC2.Popup {
    id: launcherPopup

    // `shellApplet` is the actual PlasmoidItem, supplied by main.qml. Kicker
    // uses it for favorites and service ownership; using the Popup itself
    // gives a visually plausible but non-functional launcher.
    property var shellApplet: null
    property int appModelRevision: 0
    readonly property var allAppsModel: {
        appModelRevision
        for (let row = 0; row < rootAppModel.count; ++row) {
            const candidate = rootAppModel.modelForRow(row)
            if (candidate && candidate.description === "KICKER_ALL_MODEL")
                return candidate
        }
        return null
    }
    readonly property var searchMatches: runnerModel.count > 0
                                       ? runnerModel.modelForRow(0) : null

    y: -height - 8 * MeoTheme.globalScale
    x: (parent.width - width) / 2
    width: Math.min(640 * MeoTheme.globalScale,
                    Screen.width - 16 * MeoTheme.globalScale)
    height: Math.min(688 * MeoTheme.globalScale,
                     Screen.height - ShellMetrics.shelfPanelHeight - 16 * MeoTheme.globalScale)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape

    transformOrigin: Item.Bottom

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.97; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
    }

    background: FrostedSurface {}

    function triggerModel(model, row) {
        if (!model || row < 0 || typeof model.trigger !== "function")
            return
        if (model.trigger(row, "", null))
            launcherPopup.close()
    }

    Kicker.RootModel {
        id: rootAppModel
        appletInterface: launcherPopup.shellApplet
        autoPopulate: false
        flat: true
        sorted: true
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        showRootSeparator: false
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: launcherPopup.shellApplet
        favoritesModel: rootAppModel.favoritesModel
        mergeResults: true
        query: searchField.text.trim()
    }

    // The Chromium reference calls this area “Continue where you left off”.
    // This model is real recent-usage data, not a relabelled favorites list.
    Kicker.RecentUsageModel {
        id: recentUsageModel
        shownItems: Kicker.RecentUsageModel.AppsAndDocs
        ordering: Kicker.RecentUsageModel.Recent
    }

    Connections {
        target: rootAppModel
        function onRefreshed() { launcherPopup.appModelRevision++ }
        function onCountChanged() { launcherPopup.appModelRevision++ }
    }

    onOpened: {
        rootAppModel.refresh()
        const favorites = rootAppModel.favoritesModel
        if (favorites && typeof favorites["initForClient"] === "function")
            favorites["initForClient"]("org.meo.shelf.favorites")
        searchField.forceSearchFocus()
    }

    contentItem: FocusScope {
        anchors.fill: parent
        focus: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * MeoTheme.globalScale
            spacing: MeoTheme.space16

            MeoSearchBar {
                id: searchField
                Layout.fillWidth: true
                visualStyle: "launcher"
                placeholder: qsTr("Search your tabs, files, apps, and more…")
                trailingIcon: ""
                Accessible.name: qsTr("Search your tabs, files, apps, and more")
                onAccepted: {
                    if (launcherPopup.searchMatches && searchResultList.currentIndex >= 0)
                        launcherPopup.triggerModel(launcherPopup.searchMatches,
                                                   searchResultList.currentIndex)
                }

                Keys.onEscapePressed: {
                    if (text !== "")
                        text = ""
                    else
                        launcherPopup.close()
                }
                Keys.onDownPressed: {
                    if (searchResultList.visible && searchResultList.count > 0) {
                        searchResultList.forceActiveFocus()
                        searchResultList.currentIndex = 0
                    } else if (allAppsGrid.visible && allAppsGrid.count > 0) {
                        allAppsGrid.forceActiveFocus()
                        allAppsGrid.currentIndex = 0
                    }
                }
            }

            ListView {
                id: searchResultList
                visible: searchField.text.trim() !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: MeoTheme.space4
                model: launcherPopup.searchMatches
                Accessible.name: qsTr("Search results")

                delegate: Rectangle {
                    id: resultRow
                    required property int index
                    required property string display
                    required property string description
                    required property var decoration

                    width: searchResultList.width
                    height: 56 * MeoTheme.globalScale
                    radius: ShellMetrics.radiusControl
                    color: searchResultList.currentIndex === index
                           ? MeoTheme.secondaryContainer
                           : (resultPointer.containsMouse ? MeoTheme.surfaceContainerHigh : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: MeoTheme.space12
                        anchors.rightMargin: MeoTheme.space12
                        spacing: MeoTheme.space12

                        Kirigami.Icon {
                            source: resultRow.decoration || "application-x-executable"
                            implicitWidth: 32 * MeoTheme.globalScale
                            implicitHeight: implicitWidth
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MeoText {
                                Layout.fillWidth: true
                                text: resultRow.display || ""
                                typeRole: "body"
                                typeSize: "medium"
                                emphasized: true
                                color: MeoTheme.contentOnSurface
                                elide: Text.ElideRight
                            }
                            MeoText {
                                Layout.fillWidth: true
                                text: resultRow.description || ""
                                visible: text !== ""
                                typeRole: "body"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: resultPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: launcherPopup.triggerModel(launcherPopup.searchMatches, resultRow.index)
                    }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0)
                        launcherPopup.triggerModel(launcherPopup.searchMatches, currentIndex)
                }
            }

            QQC2.ScrollView {
                visible: searchField.text.trim() === ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: MeoTheme.space16

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: recentUsageModel.count > 0
                        spacing: MeoTheme.space8

                        MeoText {
                            Layout.fillWidth: true
                            text: qsTr("Continue where you left off")
                            typeRole: "body"
                            typeSize: "medium"
                            color: MeoTheme.contentOnSurfaceVariant
                        }

                        ListView {
                            id: recentList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 112 * MeoTheme.globalScale)
                            clip: true
                            model: recentUsageModel
                            spacing: MeoTheme.space4

                            delegate: Rectangle {
                                id: recentRow
                                required property int index
                                required property string display
                                required property string description
                                required property var decoration

                                width: recentList.width
                                height: 52 * MeoTheme.globalScale
                                radius: ShellMetrics.radiusControl
                                color: recentPointer.containsMouse ? MeoTheme.surfaceContainerHigh : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: MeoTheme.space8
                                    anchors.rightMargin: MeoTheme.space8
                                    spacing: MeoTheme.space12

                                    Kirigami.Icon {
                                        source: recentRow.decoration || "application-x-executable"
                                        implicitWidth: 32 * MeoTheme.globalScale
                                        implicitHeight: implicitWidth
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        MeoText {
                                            Layout.fillWidth: true
                                            text: recentRow.display || ""
                                            typeRole: "body"
                                            typeSize: "medium"
                                            color: MeoTheme.contentOnSurface
                                            elide: Text.ElideRight
                                        }
                                        MeoText {
                                            Layout.fillWidth: true
                                            text: recentRow.description || ""
                                            visible: text !== ""
                                            typeRole: "body"
                                            typeSize: "small"
                                            color: MeoTheme.contentOnSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: recentPointer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: launcherPopup.triggerModel(recentUsageModel, recentRow.index)
                                }
                            }
                        }
                    }

                    GridView {
                        id: allAppsGrid
                        Layout.fillWidth: true
                        readonly property int columnCount: 5
                        implicitHeight: Math.ceil(count / columnCount) * (104 * MeoTheme.globalScale)
                        cellWidth: Math.floor(width / columnCount)
                        cellHeight: 104 * MeoTheme.globalScale
                        model: launcherPopup.allAppsModel
                        Accessible.name: qsTr("All apps")

                        delegate: MeoAppGridItem {
                            id: appTile
                            required property int index
                            required property string display
                            required property var decoration

                            width: allAppsGrid.cellWidth
                            height: allAppsGrid.cellHeight
                            title: appTile.display || ""
                            enabled: true
                            iconContent: Component {
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: appTile.decoration || "application-x-executable"
                                }
                            }
                            onTriggered: launcherPopup.triggerModel(launcherPopup.allAppsModel, appTile.index)
                        }

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0)
                                launcherPopup.triggerModel(launcherPopup.allAppsModel, currentIndex)
                        }
                    }

                    MeoText {
                        Layout.fillWidth: true
                        visible: launcherPopup.allAppsModel === null
                        text: qsTr("Loading applications…")
                        typeRole: "body"
                        typeSize: "medium"
                        color: MeoTheme.contentOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
