pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import MeoUI 1.0
import MeoKDE 1.0

MeoMotionPopup {
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
    readonly property bool searching: searchField.text.trim() !== ""

    y: -height - 8 * MeoTheme.globalScale
    x: (parent.width - width) / 2
    width: Math.min(680 * MeoTheme.globalScale,
                    Screen.width - 24 * MeoTheme.globalScale)
    height: Math.min(704 * MeoTheme.globalScale,
                     Screen.height - ShellMetrics.shelfPanelHeight - 24 * MeoTheme.globalScale)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape
    presentation: MeoMotionPopup.Dialog
    transformOrigin: Item.Bottom

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
        searchResultList.currentIndex = 0
        allAppsGrid.currentIndex = 0
        searchField.forceSearchFocus()
    }

    onClosed: {
        searchField.text = ""
        searchResultList.currentIndex = 0
        allAppsGrid.currentIndex = 0
    }

    // Interaction patterns are informed by Caelestia Shell's animated
    // selection/bottom-search composition and DMS Launcher V2's keyboard-first
    // navigation. KDE Kicker/KRunner remain the data and execution authority.
    contentItem: FocusScope {
        id: launcherContent

        anchors.fill: parent
        focus: true

        function selectSearch(delta) {
            if (!launcherPopup.searchMatches || searchResultList.count <= 0)
                return
            const next = Math.max(0, Math.min(searchResultList.count - 1,
                                              searchResultList.currentIndex + delta))
            searchResultList.currentIndex = next
            searchResultList.positionViewAtIndex(next, ListView.Contain)
        }

        function selectSearchPage(delta) {
            selectSearch(delta * 6)
        }

        function forwardTyping(event) {
            const blocked = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
            if (!blocked && event.text && event.text.length > 0) {
                searchField.text += event.text
                searchField.forceSearchFocus()
                event.accepted = true
                return true
            }
            return false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18 * MeoTheme.globalScale
            spacing: MeoTheme.space12

            Item {
                id: contentHost

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: searchResultList

                    anchors.fill: parent
                    enabled: launcherPopup.searching
                    visible: opacity > 0.01
                    opacity: launcherPopup.searching ? 1 : 0
                    scale: launcherPopup.searching ? 1 : 0.975
                    clip: true
                    spacing: MeoTheme.space4
                    model: launcherPopup.searchMatches
                    currentIndex: 0
                    Accessible.name: MeoI18n.translator.i18n("Search results")

                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        width: searchResultList.width
                        height: searchResultList.currentItem
                                ? searchResultList.currentItem.height
                                : 60 * MeoTheme.globalScale
                        y: searchResultList.currentItem ? searchResultList.currentItem.y : 0
                        radius: ShellMetrics.radiusControl
                        color: MeoTheme.secondaryContainer
                        opacity: searchResultList.currentIndex >= 0 ? 1 : 0
                        z: -1

                        Behavior on y {
                            NumberAnimation {
                                duration: MeoMotion.stateChange
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: MeoMotion.hover
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: MeoTheme.motionEasingStandard
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: MeoMotion.hover }
                        }
                    }

                    onCountChanged: {
                        if (count <= 0)
                            currentIndex = -1
                        else if (launcherPopup.searching)
                            currentIndex = 0
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }

                    delegate: Rectangle {
                        id: resultRow

                        required property int index
                        required property string display
                        required property string description
                        required property var decoration

                        readonly property bool selected: searchResultList.currentIndex === resultRow.index

                        width: searchResultList.width
                        height: 60 * MeoTheme.globalScale
                        radius: ShellMetrics.radiusControl
                        color: "transparent"
                        activeFocusOnTab: false
                        Accessible.role: Accessible.ListItem
                        Accessible.name: resultRow.display
                        Accessible.description: resultRow.description
                        Accessible.focusable: true
                        Accessible.onPressAction: launcherPopup.triggerModel(
                                                      launcherPopup.searchMatches,
                                                      resultRow.index)

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: MeoTheme.surfaceContainerHighest
                            opacity: resultPointer.containsMouse && !resultRow.selected ? 0.62 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: MeoMotion.hover }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: MeoTheme.space12
                            anchors.rightMargin: MeoTheme.space12
                            spacing: MeoTheme.space12

                            Kirigami.Icon {
                                source: resultRow.decoration || "application-x-executable"
                                implicitWidth: 36 * MeoTheme.globalScale
                                implicitHeight: implicitWidth
                                scale: resultRow.selected ? 1 : 0.92

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: MeoMotion.stateChange
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                MeoText {
                                    Layout.fillWidth: true
                                    text: resultRow.display || ""
                                    typeRole: "body"
                                    typeSize: "medium"
                                    emphasized: resultRow.selected
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
                            onEntered: searchResultList.currentIndex = resultRow.index
                            onClicked: launcherPopup.triggerModel(
                                           launcherPopup.searchMatches,
                                           resultRow.index)
                        }
                    }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: MeoMotion.hover
                            }
                            NumberAnimation {
                                property: "scale"
                                from: 0.97
                                to: 1
                                duration: MeoMotion.stateChange
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                            }
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: MeoMotion.stateChange
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: MeoMotion.hover }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: MeoMotion.stateChange
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }

                Item {
                    id: emptySearchState

                    anchors.centerIn: parent
                    width: Math.min(parent.width, 360 * MeoTheme.globalScale)
                    implicitHeight: emptySearchColumn.implicitHeight
                    visible: opacity > 0.01
                    enabled: false
                    opacity: launcherPopup.searching && searchResultList.count === 0 ? 1 : 0
                    scale: opacity > 0 ? 1 : 0.92

                    ColumnLayout {
                        id: emptySearchColumn

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        spacing: MeoTheme.space8

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            source: "system-search"
                            implicitWidth: 40 * MeoTheme.globalScale
                            implicitHeight: implicitWidth
                            opacity: 0.75
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("No results")
                            typeRole: "body"
                            typeSize: "medium"
                            emphasized: true
                            color: MeoTheme.contentOnSurface
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Try another app, file, setting, or command")
                            typeRole: "body"
                            typeSize: "small"
                            color: MeoTheme.contentOnSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: MeoMotion.hover }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: MeoMotion.stateChange
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }

                QQC2.ScrollView {
                    id: homeScroll

                    anchors.fill: parent
                    enabled: !launcherPopup.searching
                    visible: opacity > 0.01
                    opacity: launcherPopup.searching ? 0 : 1
                    scale: launcherPopup.searching ? 0.985 : 1
                    clip: true
                    QQC2.ScrollBar.vertical: MeoScrollBar {}

                    ColumnLayout {
                        width: homeScroll.availableWidth
                        spacing: MeoTheme.space16

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: recentUsageModel.count > 0
                            spacing: MeoTheme.space8

                            MeoText {
                                Layout.fillWidth: true
                                text: MeoI18n.translator.i18n("Recent")
                                typeRole: "body"
                                typeSize: "medium"
                                emphasized: true
                                color: MeoTheme.contentOnSurfaceVariant
                            }

                            ListView {
                                id: recentList

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight,
                                                                 120 * MeoTheme.globalScale)
                                interactive: false
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
                                    height: 56 * MeoTheme.globalScale
                                    radius: ShellMetrics.radiusControl
                                    color: recentPointer.containsMouse
                                           ? MeoTheme.surfaceContainerHigh
                                           : "transparent"
                                    Accessible.role: Accessible.ListItem
                                    Accessible.name: recentRow.display
                                    Accessible.description: recentRow.description
                                    Accessible.focusable: true
                                    Accessible.onPressAction: launcherPopup.triggerModel(
                                                                  recentUsageModel,
                                                                  recentRow.index)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: MeoTheme.space8
                                        anchors.rightMargin: MeoTheme.space8
                                        spacing: MeoTheme.space12

                                        Kirigami.Icon {
                                            source: recentRow.decoration || "application-x-executable"
                                            implicitWidth: 32 * MeoTheme.globalScale
                                            implicitHeight: implicitWidth
                                            scale: recentPointer.containsMouse ? 1 : 0.94

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: MeoMotion.hover
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                                                }
                                            }
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
                                        onClicked: launcherPopup.triggerModel(
                                                       recentUsageModel,
                                                       recentRow.index)
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: MeoMotion.hover }
                                    }
                                }
                            }
                        }

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("All apps")
                            typeRole: "body"
                            typeSize: "medium"
                            emphasized: true
                            color: MeoTheme.contentOnSurfaceVariant
                        }

                        GridView {
                            id: allAppsGrid

                            Layout.fillWidth: true
                            readonly property int columnCount: width >= 620 * MeoTheme.globalScale ? 5 : 4
                            implicitHeight: Math.ceil(count / columnCount) * cellHeight
                            cellWidth: Math.floor(width / columnCount)
                            cellHeight: 100 * MeoTheme.globalScale
                            interactive: false
                            model: launcherPopup.allAppsModel
                            Accessible.name: MeoI18n.translator.i18n("All apps")

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
                                onTriggered: launcherPopup.triggerModel(
                                                 launcherPopup.allAppsModel,
                                                 appTile.index)
                            }

                            Keys.onReturnPressed: {
                                if (currentIndex >= 0)
                                    launcherPopup.triggerModel(launcherPopup.allAppsModel,
                                                               currentIndex)
                            }
                            Keys.onEnterPressed: {
                                if (currentIndex >= 0)
                                    launcherPopup.triggerModel(launcherPopup.allAppsModel,
                                                               currentIndex)
                            }
                            Keys.onEscapePressed: launcherPopup.close()
                            Keys.onPressed: (event) => {
                                if (!launcherContent.forwardTyping(event))
                                    event.accepted = false
                            }
                        }

                        MeoText {
                            Layout.fillWidth: true
                            visible: launcherPopup.allAppsModel === null
                            text: MeoI18n.translator.i18n("Loading applications…")
                            typeRole: "body"
                            typeSize: "medium"
                            color: MeoTheme.contentOnSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: MeoMotion.hover }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: MeoMotion.stateChange
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: MeoTheme.space4

                MeoSearchBar {
                    id: searchField

                    Layout.fillWidth: true
                    visualStyle: "launcher"
                    placeholder: MeoI18n.translator.i18n("Search apps, files, settings, and more…")
                    trailingIcon: ""
                    Accessible.name: MeoI18n.translator.i18n("Search apps, files, settings, and more")

                    onTextChanged: {
                        if (text.trim() !== "" && searchResultList.count > 0)
                            searchResultList.currentIndex = 0
                    }

                    onAccepted: {
                        if (launcherPopup.searching
                                && launcherPopup.searchMatches
                                && searchResultList.currentIndex >= 0) {
                            launcherPopup.triggerModel(launcherPopup.searchMatches,
                                                       searchResultList.currentIndex)
                        }
                    }

                    Keys.onEscapePressed: launcherPopup.close()

                    Keys.onDownPressed: {
                        if (launcherPopup.searching) {
                            launcherContent.selectSearch(1)
                        } else if (allAppsGrid.count > 0) {
                            allAppsGrid.forceActiveFocus()
                            allAppsGrid.currentIndex = 0
                        }
                    }

                    Keys.onUpPressed: {
                        if (launcherPopup.searching)
                            launcherContent.selectSearch(-1)
                    }

                    Keys.onPressed: (event) => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                            launcherContent.selectSearch(1)
                            event.accepted = true
                        } else if (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                            launcherContent.selectSearch(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageDown) {
                            launcherContent.selectSearchPage(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp) {
                            launcherContent.selectSearchPage(-1)
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MeoTheme.space12

                    MeoText {
                        Layout.fillWidth: true
                        text: launcherPopup.searching
                              ? MeoI18n.translator.i18n("↑↓ navigate  •  Enter open  •  Esc close")
                              : MeoI18n.translator.i18n("Type to search  •  ↓ browse apps  •  Esc close")
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        opacity: 0.72
                    }

                    MeoText {
                        text: MeoI18n.translator.i18n("Plasma search")
                        typeRole: "body"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                        opacity: 0.55
                    }
                }
            }
        }
    }

