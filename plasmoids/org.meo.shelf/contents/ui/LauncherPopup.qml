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

    // Plasma/Kicker remains the launcher backend. Meo only owns presentation,
    // motion and the small amount of glue needed to expose KDE actions through
    // MeoUI surfaces.
    property var shellApplet: null
    property int appModelRevision: 0
    property int browseMode: 0
    property string defaultPage: "home"
    property string widthPreset: "standard"
    property bool showFavoritesSection: true
    property bool showRecentSection: true
    // -1 keeps the canonical KICKER_ALL_MODEL selected. Positive rows point
    // directly at RootModel category models; no duplicate app index is kept.
    property int appsModelRow: -1
    property string appsCategoryName: ""
    property bool modelsPrimed: false
    property bool favoritesInitialized: false
    property bool refreshInFlight: false
    property double lastRefreshMs: 0
    property double openStartedMs: 0
    property int lastReadyLatencyMs: -1

    // One implementation, two entry surfaces:
    // - Shelf activation opens the complete Home / All apps launcher.
    // - Alt+Space can reuse this popup in quickSearchMode: a centered,
    //   Spotlight-like search pill that expands only after the user types.
    property bool quickSearchMode: false

    // Meo Settings writes the Shelf applet's launcherPlacement KConfig value;
    // main.qml validates it and passes the normalized value here.
    property string placementMode: "center" // "center" | "top"

    // The shell and search field should paint immediately. Browse content is
    // only considered ready once Plasma's canonical all-apps model has actual
    // entries. Slow first loads use MeoUI's anti-flash morphing feedback.
    readonly property int startupLoadingDelay: 900
    // KRunner exposes an explicit querying state. Give normal fast searches a
    // brief window to resolve, then use the same morphing feedback rather than
    // flashing a false "No results" state.
    readonly property int searchLoadingDelay: 500

    readonly property bool searching: searchField.text.trim() !== ""
    readonly property var favoritesModel: rootAppModel.favoritesModel
    readonly property var allAppsModel: {
        appModelRevision
        for (let row = 0; row < rootAppModel.count; ++row) {
            const candidate = rootAppModel.modelForRow(row)
            if (candidate && candidate.description === "KICKER_ALL_MODEL")
                return candidate
        }
        return null
    }
    readonly property var activeAppsModel: {
        appModelRevision
        if (appsModelRow < 0)
            return allAppsModel
        const candidate = rootAppModel.modelForRow(appsModelRow)
        return candidate || allAppsModel
    }
    readonly property var searchMatches: runnerModel.count > 0
                                       ? runnerModel.modelForRow(0) : null
    readonly property bool appContentReady: allAppsModel !== null
                                            && allAppsModel.count > 0
    readonly property real configuredWidth: widthPreset === "compact"
                                            ? 600 * MeoTheme.globalScale
                                            : (widthPreset === "wide"
                                               ? 840 * MeoTheme.globalScale
                                               : 736 * MeoTheme.globalScale)
    readonly property real availableLauncherHeight: Math.max(
        360 * MeoTheme.globalScale,
        Screen.height - ShellMetrics.shelfPanelHeight - 24 * MeoTheme.globalScale)
    // Keep the surface compact enough to feel like Caelestia rather than a
    // full application window, but leave enough room for Plasma's richer
    // KRunner results and a dense all-apps grid.
    readonly property real quickSearchCollapsedHeight: Math.max(
        80 * MeoTheme.globalScale,
        48 * MeoTheme.globalScale + 2 * ShellMetrics.popupContentMargin)
    readonly property real desiredLauncherHeight: quickSearchMode && !searching
                                                  ? quickSearchCollapsedHeight
                                                  : searching
                                                    ? 612 * MeoTheme.globalScale
                                                    : browseMode === 0
                                                      ? 548 * MeoTheme.globalScale
                                                      : 664 * MeoTheme.globalScale
    readonly property bool compactLayout: width < 620 * MeoTheme.globalScale

    // This plasmoid lives in the bottom Shelf, so popup coordinates are local
    // to that bottom-edge surface. Convert the desired screen-space positions
    // back into that local coordinate system.
    readonly property real topPlacementMargin: 96 * MeoTheme.globalScale
    readonly property real centeredPlacementY: parent
                                               ? parent.height - (Screen.height + height) / 2
                                               : -height - ShellMetrics.popupGap
    readonly property real topPlacementY: parent
                                          ? parent.height - Screen.height + topPlacementMargin
                                          : -height - ShellMetrics.popupGap

    y: placementMode === "top" ? topPlacementY : centeredPlacementY
    x: (parent.width - width) / 2
    width: Math.min(configuredWidth,
                    Screen.width - 24 * MeoTheme.globalScale)
    height: Math.min(desiredLauncherHeight, availableLauncherHeight)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape
    presentation: MeoMotionPopup.Dialog
    // Keep the KRunner-like immediacy, but center is the Meo default: the
    // surface fades/scales into place without pretending it came from a screen
    // edge. The optional top placement gets a very short downward settle.
    motionProfile: "pixel"
    entranceOffset: placementMode === "top" ? 12 * MeoTheme.globalScale : 0
    entranceScale: 0.975
    transformOrigin: placementMode === "top" ? Item.Top : Item.Center

    Behavior on height {
        enabled: !MeoTheme.reduceMotion
        NumberAnimation {
            duration: MeoMotion.stateChange
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }

    function toggleFullLauncher() {
        quickSearchMode = false
        browseMode = defaultPage === "apps" ? 1 : 0
        if (opened || visible) {
            close()
        } else {
            requestOpen()
        }
    }

    function openQuickSearch() {
        // Plasma's applet activation signal routes the configured global
        // shortcut here. Reuse this KRunner/Kicker instance; never spawn a
        // second runner process for quick search.
        quickSearchMode = true
        searchField.text = ""
        if (opened || visible) {
            searchField.forceSearchFocus()
            return
        }
        requestOpen()
    }

    function refreshModels(force) {
        if (!shellApplet)
            return

        const now = Date.now()
        if (!force && refreshInFlight)
            return
        if (!force && modelsPrimed && now - lastRefreshMs < 30000)
            return

        const favorites = rootAppModel.favoritesModel
        if (!favoritesInitialized && favorites
                && typeof favorites["initForClient"] === "function") {
            // Plasma Kickoff initializes its KActivities favorites client
            // before refreshing RootModel. Do the same so Home does not paint
            // once and then reshuffle when favorites attach a moment later.
            favorites["initForClient"]("org.meo.shelf.favorites")
            favoritesInitialized = true
        }

        refreshInFlight = true
        rootAppModel.refresh()
        lastRefreshMs = now
        if (appContentReady)
            modelsPrimed = true
    }

    function triggerModel(model, row) {
        if (!model || row < 0 || typeof model.trigger !== "function")
            return false
        const closeRequested = model.trigger(row, "", null)
        if (closeRequested)
            launcherPopup.close()
        return closeRequested
    }

    function triggerAction(model, row, actionId, actionArgument) {
        if (!model || row < 0 || !actionId || typeof model.trigger !== "function")
            return false
        const closeRequested = model.trigger(row, actionId, actionArgument)
        if (closeRequested)
            launcherPopup.close()
        return closeRequested
    }

    function transformActionList(model, row, sourceActions) {
        if (!sourceActions)
            return []

        let actions = []
        try {
            actions = Array.from(sourceActions)
        } catch (error) {
            return []
        }

        const mapped = []
        for (let index = 0; index < actions.length; ++index) {
            const sourceAction = actions[index]
            if (!sourceAction)
                continue

            if (sourceAction.type === "separator") {
                mapped.push({ "type": "separator" })
                continue
            }

            if (sourceAction.type === "title") {
                mapped.push({
                    "type": "label",
                    "label": sourceAction.text || ""
                })
                continue
            }

            const nested = sourceAction.subActions
                           ? transformActionList(model, row, sourceAction.subActions)
                           : []
            const actionId = sourceAction.actionId || ""
            const actionArgument = sourceAction.actionArgument
            const iconName = typeof sourceAction.icon === "string"
                             ? sourceAction.icon : ""

            mapped.push({
                "label": sourceAction.text || "",
                "icon": iconName,
                "enabled": sourceAction.enabled !== false,
                "checked": sourceAction.checkable ? !!sourceAction.checked : undefined,
                "subItems": nested,
                "action": function() {
                    launcherPopup.triggerAction(model, row, actionId, actionArgument)
                }
            })
        }
        return mapped
    }

    function contextEntries(model, row, itemModel) {
        if (!model || !itemModel)
            return []

        // Read the expensive Kicker action list only when a context menu is
        // actually requested, matching Plasma Kickoff's lazy action path.
        const entries = transformActionList(model, row, itemModel.actionList)

        const favoriteId = itemModel.favoriteId || ""
        const favorites = launcherPopup.favoritesModel
        if (favoriteId && favorites
                && favorites.enabled !== false
                && typeof favorites.isFavorite === "function") {
            let isFavorite = false
            try {
                isFavorite = favorites.isFavorite(favoriteId)
            } catch (error) {
                isFavorite = false
            }

            if (entries.length > 0)
                entries.push({ "type": "separator" })

            entries.push({
                "label": isFavorite
                         ? MeoI18n.translator.i18n("Remove from favorites")
                         : MeoI18n.translator.i18n("Add to favorites"),
                "icon": isFavorite ? "keep_off" : "keep",
                "action": function() {
                    if (isFavorite && typeof favorites.removeFavorite === "function")
                        favorites.removeFavorite(favoriteId)
                    else if (!isFavorite && typeof favorites.addFavorite === "function")
                        favorites.addFavorite(favoriteId)
                }
            })
        }

        return entries
    }

    function openContextMenu(anchor, localX, localY, model, row, itemModel) {
        const entries = contextEntries(model, row, itemModel)
        if (entries.length === 0)
            return false
        itemContextMenu.model = entries
        return itemContextMenu.openAtPoint(anchor, localX, localY)
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
        // Some KRunner providers refine or replace the active query. Keep the
        // visible field authoritative, matching Plasma Kickoff's native path.
        onRequestUpdateQuery: function(query) {
            searchField.text = query
        }
    }

    Kicker.RecentUsageModel {
        id: recentUsageModel
        favoritesModel: rootAppModel.favoritesModel
        shownItems: Kicker.RecentUsageModel.AppsAndDocs
        ordering: Kicker.RecentUsageModel.Recent
    }

    // Reuse Plasma's KActivities-backed popularity ranking instead of
    // maintaining a second DMS-style usage database in Meo.
    Kicker.RecentUsageModel {
        id: frequentUsageModel
        favoritesModel: rootAppModel.favoritesModel
        ordering: 1 // Popular / Frequently Used, same contract as Kickoff.
    }

    Connections {
        target: rootAppModel
        function onRefreshed() {
            launcherPopup.refreshInFlight = false
            launcherPopup.appModelRevision++
            if (launcherPopup.appsModelRow >= rootAppModel.count) {
                launcherPopup.appsModelRow = -1
                launcherPopup.appsCategoryName = ""
            }
        }
        function onCountChanged() {
            launcherPopup.appModelRevision++
            if (launcherPopup.appsModelRow >= rootAppModel.count) {
                launcherPopup.appsModelRow = -1
                launcherPopup.appsCategoryName = ""
            }
        }
    }

    onAppContentReadyChanged: {
        if (!appContentReady)
            return
        modelsPrimed = true
        refreshInFlight = false
        if (visible && openStartedMs > 0)
            lastReadyLatencyMs = Math.max(0, Math.round(Date.now() - openStartedMs))
    }

    onShellAppletChanged: {
        if (shellApplet)
            Qt.callLater(function() { launcherPopup.refreshModels(false) })
    }

    // Start the startup budget before the enter transition. Waiting for
    // onOpened would add the animation duration on top of the 900 ms gate and
    // could make a visibly slow first launch miss the one-second target.
    onAboutToShow: {
        openStartedMs = Date.now()
        lastReadyLatencyMs = appContentReady ? 0 : -1
        refreshModels(false)
    }

    onOpened: {
        searchField.forceSearchFocus()
    }

    onClosed: {
        openStartedMs = 0
        searchField.text = ""
        itemContextMenu.close()
    }

    Component.onCompleted: Qt.callLater(function() { launcherPopup.refreshModels(false) })

    contentItem: FocusScope {
        id: launcherContent
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (searchField.text !== "") {
                searchField.text = ""
                searchField.forceSearchFocus()
            } else {
                launcherPopup.close()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ShellMetrics.popupContentMargin
            spacing: MeoTheme.space12

            MeoSearchBar {
                id: searchField
                Layout.fillWidth: true
                Layout.maximumWidth: 640 * MeoTheme.globalScale
                Layout.alignment: Qt.AlignHCenter
                visualStyle: "launcher"
                placeholder: MeoI18n.translator.i18n("Search apps, files, settings and more…")
                trailingIcon: ""
                Accessible.name: MeoI18n.translator.i18n("Search apps, files, settings and more")

                onAccepted: {
                    if (paneLoader.item && typeof paneLoader.item.activateCurrent === "function")
                        paneLoader.item.activateCurrent()
                }

                Keys.onEscapePressed: {
                    if (text !== "")
                        text = ""
                    else
                        launcherPopup.close()
                }

                Keys.onDownPressed: {
                    if (paneLoader.item && typeof paneLoader.item.focusFirst === "function")
                        paneLoader.item.focusFirst()
                }
            }

            RowLayout {
                visible: !launcherPopup.searching && !launcherPopup.quickSearchMode
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 40 * MeoTheme.globalScale : 0
                spacing: MeoTheme.space8

                MeoSegmentedButtons {
                    id: modeTabs
                    Layout.preferredWidth: Math.min(
                        360 * MeoTheme.globalScale,
                        launcherContent.width - 120 * MeoTheme.globalScale)
                    Layout.alignment: Qt.AlignLeft
                    size: "s"
                    accessibleName: MeoI18n.translator.i18n("Launcher view")
                    model: [
                        {
                            "label": MeoI18n.translator.i18n("Home"),
                            "icon": "home"
                        },
                        {
                            "label": MeoI18n.translator.i18n("All apps"),
                            "icon": "apps"
                        }
                    ]
                    currentIndex: launcherPopup.browseMode
                    onSelected: function(index, data) {
                        launcherPopup.browseMode = index
                        Qt.callLater(function() {
                            if (paneLoader.item
                                    && typeof paneLoader.item.focusFirst === "function"
                                    && !searchField.activeFocus)
                                paneLoader.item.focusFirst()
                        })
                    }
                }

                Item { Layout.fillWidth: true }

                MeoText {
                    text: launcherPopup.browseMode === 0
                          ? MeoI18n.translator.i18n("Pinned + activity")
                          : (launcherPopup.activeAppsModel
                             ? MeoI18n.translator.i18n("%1 apps").arg(
                                   launcherPopup.activeAppsModel.count)
                             : MeoI18n.translator.i18n("Loading…"))
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }
            }

            Item {
                id: paneStage
                visible: !launcherPopup.quickSearchMode || launcherPopup.searching
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Instantiate browse panes only after Kicker has real app
                // content. This prevents Home's empty state from flashing
                // before the first model refresh finishes.
                Loader {
                    id: paneLoader
                    anchors.fill: parent
                    active: launcherPopup.searching || launcherPopup.appContentReady
                    sourceComponent: launcherPopup.searching
                                     ? searchPane
                                     : launcherPopup.browseMode === 0
                                       ? homePane
                                       : appsPane

                    // If the delayed loading indicator has already appeared,
                    // keep the completed pane hidden until MeoLoadingFeedback
                    // releases its minimum-visible hold. The two then
                    // cross-fade instead of blank -> loader -> content.
                    opacity: active
                             && (launcherPopup.searching
                                 || !startupFeedback.feedbackVisible)
                             ? 1 : 0
                    scale: opacity > 0 ? 1 : 0.985

                    Behavior on opacity {
                        enabled: !MeoTheme.reduceMotion
                        NumberAnimation {
                            duration: MeoTheme.motionDurationLoadingFeedbackFade
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingStandard
                        }
                    }

                    Behavior on scale {
                        enabled: !MeoTheme.reduceMotion
                        NumberAnimation {
                            duration: MeoMotion.pageEnter
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }

                MeoLoadingFeedback {
                    id: startupFeedback
                    anchors.fill: parent
                    active: launcherPopup.openStartedMs > 0
                            && !launcherPopup.searching
                            && !launcherPopup.appContentReady
                    // Fast paths never show a spinner. If Kicker still has not
                    // populated by ~1 second, use the existing M3 Expressive
                    // morphing indicator and hold it long enough to avoid a
                    // one-frame flash when the model finishes immediately
                    // afterwards.
                    delay: launcherPopup.startupLoadingDelay
                    minimumVisibleDuration: 300
                    indicatorVariant: "contained"
                    accessibleName: MeoI18n.translator.i18n("Loading applications")
                }
            }
        }

        MeoContextMenu {
            id: itemContextMenu
        }
    }

    Component {
        id: searchPane

        FocusScope {
            id: searchPaneRoot

            function focusFirst() {
                if (searchResultList.count <= 0)
                    return false
                searchResultList.currentIndex = 0
                searchResultList.forceActiveFocus(Qt.TabFocusReason)
                return true
            }

            function activateCurrent() {
                if (searchResultList.currentIndex < 0 && searchResultList.count > 0)
                    searchResultList.currentIndex = 0
                if (searchResultList.currentIndex >= 0)
                    return launcherPopup.triggerModel(
                        launcherPopup.searchMatches,
                        searchResultList.currentIndex)
                return false
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: MeoTheme.space8

                ListView {
                    id: searchResultList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: MeoTheme.space4
                    model: launcherPopup.searchMatches
                    reuseItems: true
                    keyNavigationWraps: false
                    currentIndex: count > 0 ? 0 : -1
                    section.property: "group"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        required property string section
                        width: searchResultList.width
                        height: section.trim() === "" ? 0 : 30 * MeoTheme.globalScale
                        visible: height > 0

                        MeoText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: MeoTheme.space4
                            text: parent.section
                            typeRole: "label"
                            typeSize: "small"
                            emphasized: true
                            color: MeoTheme.contentOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                    Accessible.name: MeoI18n.translator.i18n("Search results")
                    opacity: searchFeedback.feedbackVisible ? 0 : 1

                    Behavior on opacity {
                        enabled: !MeoTheme.reduceMotion
                        NumberAnimation {
                            duration: MeoTheme.motionDurationLoadingFeedbackFade
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingStandard
                        }
                    }

                    onCountChanged: {
                        if (count > 0 && currentIndex < 0)
                            currentIndex = 0
                    }

                    delegate: MeoListItem {
                        id: resultItem
                        required property int index
                        required property var model
                        required property string display
                        required property string description
                        required property var decoration

                        width: searchResultList.width
                        headline: resultItem.display || ""
                        supportingText: resultItem.description || ""
                        supportingTextLines: 1
                        leadingComponentSize: 32
                        leadingComponent: Component {
                            Kirigami.Icon {
                                implicitWidth: 32 * MeoTheme.globalScale
                                implicitHeight: implicitWidth
                                source: resultItem.decoration || "application-x-executable"
                            }
                        }
                        isDense: true
                        isSegmented: true
                        roundingStrategy: "all"
                        outerCornerRadius: MeoTheme.shapeLarge
                        selected: searchResultList.currentIndex === resultItem.index
                        isEmphasized: selected

                        onActiveFocusChanged: {
                            if (activeFocus)
                                searchResultList.currentIndex = resultItem.index
                        }
                        onClicked: {
                            searchResultList.currentIndex = resultItem.index
                            launcherPopup.triggerModel(
                                launcherPopup.searchMatches,
                                resultItem.index)
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: function(eventPoint) {
                                searchResultList.currentIndex = resultItem.index
                                launcherPopup.openContextMenu(
                                    resultItem,
                                    eventPoint.position.x,
                                    eventPoint.position.y,
                                    launcherPopup.searchMatches,
                                    resultItem.index,
                                    resultItem.model)
                            }
                        }
                    }

                    Keys.onReturnPressed: searchPaneRoot.activateCurrent()
                    Keys.onEnterPressed: searchPaneRoot.activateCurrent()
                    Keys.onDownPressed: {
                        if (count > 0)
                            currentIndex = Math.min(count - 1, currentIndex + 1)
                    }
                    Keys.onUpPressed: {
                        if (currentIndex <= 0) {
                            searchField.forceSearchFocus()
                        } else {
                            currentIndex--
                        }
                    }
                    Keys.onPressed: function(event) {
                        if ((event.key === Qt.Key_Menu || event.key === Qt.Key_F10)
                                && currentIndex >= 0) {
                            const item = itemAtIndex(currentIndex)
                            if (item) {
                                launcherPopup.openContextMenu(
                                    item, item.width / 2, item.height / 2,
                                    launcherPopup.searchMatches,
                                    currentIndex, item.model)
                            }
                            event.accepted = true
                        }
                    }

                    QQC2.ScrollBar.vertical: MeoScrollBar {}
                }

                MeoEmptyState {
                    visible: searchResultList.count === 0
                             && !runnerModel.querying
                             && !searchFeedback.feedbackVisible
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "manage_search"
                    title: MeoI18n.translator.i18n("No results")
                    description: MeoI18n.translator.i18n("Try another app, file, setting or command.")
                }

                MeoText {
                    Layout.fillWidth: true
                    visible: searchResultList.count > 0
                    text: MeoI18n.translator.i18n("↑↓ Navigate   Enter Open   Esc Clear   Menu / Right-click More")
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MeoLoadingFeedback {
                id: searchFeedback
                anchors.fill: parent
                z: 2
                active: launcherPopup.searching
                        && runnerModel.querying
                        && !runnerModel.resultsPresent
                delay: launcherPopup.searchLoadingDelay
                minimumVisibleDuration: 300
                indicatorVariant: "contained"
                accessibleName: MeoI18n.translator.i18n("Searching")
            }
        }
    }

    Component {
        id: homePane

        FocusScope {
            id: homePaneRoot

            readonly property bool hasFavorites: launcherPopup.showFavoritesSection
                                                 && launcherPopup.favoritesModel
                                                 && launcherPopup.favoritesModel.count > 0
            readonly property bool hasFrequent: frequentUsageModel.count > 0
            readonly property bool hasRecents: launcherPopup.showRecentSection
                                               && recentUsageModel.count > 0

            function focusFirst() {
                if (hasFavorites) {
                    favoriteList.currentIndex = 0
                    favoriteList.forceActiveFocus(Qt.TabFocusReason)
                    return true
                }
                if (hasFrequent) {
                    frequentList.currentIndex = 0
                    frequentList.forceActiveFocus(Qt.TabFocusReason)
                    return true
                }
                if (hasRecents) {
                    recentList.currentIndex = 0
                    recentList.forceActiveFocus(Qt.TabFocusReason)
                    return true
                }
                return false
            }

            function activateCurrent() {
                if (favoriteList.activeFocus && favoriteList.currentIndex >= 0)
                    return launcherPopup.triggerModel(
                        launcherPopup.favoritesModel,
                        favoriteList.currentIndex)
                if (frequentList.activeFocus && frequentList.currentIndex >= 0)
                    return launcherPopup.triggerModel(
                        frequentUsageModel,
                        frequentList.currentIndex)
                if (recentList.activeFocus && recentList.currentIndex >= 0)
                    return launcherPopup.triggerModel(
                        recentUsageModel,
                        recentList.currentIndex)
                return false
            }

            QQC2.ScrollView {
                id: homeScroll
                anchors.fill: parent
                clip: true
                QQC2.ScrollBar.vertical: MeoScrollBar {}

                ColumnLayout {
                    width: homeScroll.availableWidth
                    spacing: MeoTheme.space16

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: homePaneRoot.hasFavorites
                        spacing: MeoTheme.space8

                        RowLayout {
                            Layout.fillWidth: true

                            MeoText {
                                text: MeoI18n.translator.i18n("Pinned")
                                typeRole: "title"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.contentOnSurface
                            }

                            Item { Layout.fillWidth: true }

                            MeoText {
                                text: launcherPopup.favoritesModel
                                      ? launcherPopup.favoritesModel.count : 0
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }

                        ListView {
                            id: favoriteList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96 * MeoTheme.globalScale
                            orientation: ListView.Horizontal
                            spacing: MeoTheme.space4
                            clip: true
                            model: launcherPopup.favoritesModel
                            reuseItems: true
                            keyNavigationWraps: false
                            currentIndex: count > 0 ? 0 : -1
                            Accessible.name: MeoI18n.translator.i18n("Pinned applications")

                            delegate: MeoAppGridItem {
                                id: favoriteItem
                                required property int index
                                required property var model
                                required property string display
                                required property var decoration

                                width: 92 * MeoTheme.globalScale
                                height: favoriteList.height
                                compact: true
                                title: favoriteItem.display || ""
                                selected: favoriteList.currentIndex === favoriteItem.index
                                          && (favoriteList.activeFocus || favoriteItem.activeFocus)
                                iconContent: Component {
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: favoriteItem.decoration
                                                || "application-x-executable"
                                    }
                                }
                                onTriggered: {
                                    favoriteList.currentIndex = favoriteItem.index
                                    launcherPopup.triggerModel(
                                        launcherPopup.favoritesModel,
                                        favoriteItem.index)
                                }

                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: function(eventPoint) {
                                        favoriteList.currentIndex = favoriteItem.index
                                        launcherPopup.openContextMenu(
                                            favoriteItem,
                                            eventPoint.position.x,
                                            eventPoint.position.y,
                                            launcherPopup.favoritesModel,
                                            favoriteItem.index,
                                            favoriteItem.model)
                                    }
                                }
                            }

                            Keys.onReturnPressed: homePaneRoot.activateCurrent()
                            Keys.onEnterPressed: homePaneRoot.activateCurrent()
                            Keys.onDownPressed: {
                                if (frequentList.count > 0) {
                                    frequentList.currentIndex = 0
                                    frequentList.forceActiveFocus(Qt.TabFocusReason)
                                } else if (recentList.count > 0) {
                                    recentList.currentIndex = 0
                                    recentList.forceActiveFocus(Qt.TabFocusReason)
                                }
                            }
                            Keys.onUpPressed: searchField.forceSearchFocus()
                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Menu || event.key === Qt.Key_F10)
                                        && currentIndex >= 0) {
                                    const item = itemAtIndex(currentIndex)
                                    if (item) {
                                        launcherPopup.openContextMenu(
                                            item, item.width / 2, item.height / 2,
                                            launcherPopup.favoritesModel,
                                            currentIndex, item.model)
                                    }
                                    event.accepted = true
                                }
                            }

                            QQC2.ScrollBar.horizontal: MeoScrollBar {}
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: homePaneRoot.hasFrequent
                        spacing: MeoTheme.space8

                        RowLayout {
                            Layout.fillWidth: true

                            MeoText {
                                text: MeoI18n.translator.i18n("Frequently used")
                                typeRole: "title"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.contentOnSurface
                            }

                            Item { Layout.fillWidth: true }

                            MeoText {
                                text: frequentUsageModel.count
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                            }
                        }

                        ListView {
                            id: frequentList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96 * MeoTheme.globalScale
                            orientation: ListView.Horizontal
                            spacing: MeoTheme.space4
                            clip: true
                            reuseItems: true
                            model: frequentUsageModel
                            keyNavigationWraps: false
                            currentIndex: count > 0 ? 0 : -1
                            Accessible.name: MeoI18n.translator.i18n("Frequently used applications")

                            delegate: MeoAppGridItem {
                                id: frequentItem
                                required property int index
                                required property var model
                                required property string display
                                required property var decoration

                                width: 92 * MeoTheme.globalScale
                                height: frequentList.height
                                compact: true
                                title: frequentItem.display || ""
                                selected: frequentList.currentIndex === frequentItem.index
                                          && (frequentList.activeFocus || frequentItem.activeFocus)
                                iconContent: Component {
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: frequentItem.decoration
                                                || "application-x-executable"
                                    }
                                }

                                onTriggered: {
                                    frequentList.currentIndex = frequentItem.index
                                    launcherPopup.triggerModel(
                                        frequentUsageModel,
                                        frequentItem.index)
                                }

                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: function(eventPoint) {
                                        frequentList.currentIndex = frequentItem.index
                                        launcherPopup.openContextMenu(
                                            frequentItem,
                                            eventPoint.position.x,
                                            eventPoint.position.y,
                                            frequentUsageModel,
                                            frequentItem.index,
                                            frequentItem.model)
                                    }
                                }
                            }

                            Keys.onReturnPressed: homePaneRoot.activateCurrent()
                            Keys.onEnterPressed: homePaneRoot.activateCurrent()
                            Keys.onUpPressed: {
                                if (favoriteList.count > 0) {
                                    favoriteList.currentIndex = 0
                                    favoriteList.forceActiveFocus(Qt.TabFocusReason)
                                } else {
                                    searchField.forceSearchFocus()
                                }
                            }
                            Keys.onDownPressed: {
                                if (recentList.count > 0) {
                                    recentList.currentIndex = 0
                                    recentList.forceActiveFocus(Qt.TabFocusReason)
                                }
                            }
                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Menu || event.key === Qt.Key_F10)
                                        && currentIndex >= 0) {
                                    const item = itemAtIndex(currentIndex)
                                    if (item) {
                                        launcherPopup.openContextMenu(
                                            item, item.width / 2, item.height / 2,
                                            frequentUsageModel,
                                            currentIndex, item.model)
                                    }
                                    event.accepted = true
                                }
                            }

                            QQC2.ScrollBar.horizontal: MeoScrollBar {}
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: homePaneRoot.hasRecents
                        spacing: MeoTheme.space8

                        MeoText {
                            Layout.fillWidth: true
                            text: MeoI18n.translator.i18n("Recent")
                            typeRole: "title"
                            typeSize: "small"
                            emphasized: true
                            color: MeoTheme.contentOnSurface
                        }

                        ListView {
                            id: recentList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(
                                4, recentUsageModel.count)
                                * (52 * MeoTheme.globalScale)
                            model: recentUsageModel
                            reuseItems: true
                            spacing: MeoTheme.space4
                            clip: true
                            interactive: false
                            keyNavigationWraps: false
                            currentIndex: count > 0 ? 0 : -1
                            Accessible.name: MeoI18n.translator.i18n("Recent items")

                            delegate: MeoListItem {
                                id: recentItem
                                required property int index
                                required property var model
                                required property string display
                                required property var decoration

                                width: recentList.width
                                height: 48 * MeoTheme.globalScale
                                headline: recentItem.display || ""
                                leadingComponentSize: 30
                                leadingComponent: Component {
                                    Kirigami.Icon {
                                        implicitWidth: 30 * MeoTheme.globalScale
                                        implicitHeight: implicitWidth
                                        source: recentItem.decoration
                                                || "application-x-executable"
                                    }
                                }
                                isDense: true
                                isSegmented: true
                                roundingStrategy: "all"
                                outerCornerRadius: MeoTheme.shapeLarge
                                selected: recentList.currentIndex === recentItem.index
                                          && (recentList.activeFocus || recentItem.activeFocus)

                                onActiveFocusChanged: {
                                    if (activeFocus)
                                        recentList.currentIndex = recentItem.index
                                }
                                onClicked: {
                                    recentList.currentIndex = recentItem.index
                                    launcherPopup.triggerModel(
                                        recentUsageModel,
                                        recentItem.index)
                                }

                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: function(eventPoint) {
                                        recentList.currentIndex = recentItem.index
                                        launcherPopup.openContextMenu(
                                            recentItem,
                                            eventPoint.position.x,
                                            eventPoint.position.y,
                                            recentUsageModel,
                                            recentItem.index,
                                            recentItem.model)
                                    }
                                }
                            }

                            Keys.onReturnPressed: homePaneRoot.activateCurrent()
                            Keys.onEnterPressed: homePaneRoot.activateCurrent()
                            Keys.onUpPressed: {
                                if (currentIndex <= 0) {
                                    if (frequentList.count > 0) {
                                        frequentList.currentIndex = 0
                                        frequentList.forceActiveFocus(Qt.TabFocusReason)
                                    } else if (favoriteList.count > 0) {
                                        favoriteList.currentIndex = 0
                                        favoriteList.forceActiveFocus(Qt.TabFocusReason)
                                    } else {
                                        searchField.forceSearchFocus()
                                    }
                                } else {
                                    currentIndex--
                                }
                            }
                            Keys.onDownPressed: {
                                if (currentIndex < Math.min(count - 1, 3))
                                    currentIndex++
                            }
                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Menu || event.key === Qt.Key_F10)
                                        && currentIndex >= 0) {
                                    const item = itemAtIndex(currentIndex)
                                    if (item) {
                                        launcherPopup.openContextMenu(
                                            item, item.width / 2, item.height / 2,
                                            recentUsageModel,
                                            currentIndex, item.model)
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    MeoEmptyState {
                        visible: !homePaneRoot.hasFavorites
                                 && !homePaneRoot.hasFrequent
                                 && !homePaneRoot.hasRecents
                        Layout.fillWidth: true
                        Layout.preferredHeight: 260 * MeoTheme.globalScale
                        icon: "apps"
                        title: MeoI18n.translator.i18n("Ready when you are")
                        description: MeoI18n.translator.i18n("Pinned, frequently used, and recent items will appear here.")
                    }
                }
            }
        }
    }

    Component {
        id: appsPane

        FocusScope {
            id: appsPaneRoot

            function focusFirst() {
                if (allAppsGrid.count <= 0)
                    return false
                allAppsGrid.currentIndex = 0
                allAppsGrid.forceActiveFocus(Qt.TabFocusReason)
                return true
            }

            function activateCurrent() {
                if (allAppsGrid.currentIndex < 0 && allAppsGrid.count > 0)
                    allAppsGrid.currentIndex = 0
                if (allAppsGrid.currentIndex >= 0)
                    return launcherPopup.triggerModel(
                        launcherPopup.activeAppsModel,
                        allAppsGrid.currentIndex)
                return false
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: MeoTheme.space8

                RowLayout {
                    Layout.fillWidth: true

                    MeoText {
                        text: launcherPopup.appsModelRow < 0
                              ? MeoI18n.translator.i18n("All apps")
                              : launcherPopup.appsCategoryName
                        typeRole: "title"
                        typeSize: "small"
                        emphasized: true
                        color: MeoTheme.contentOnSurface
                    }

                    Item { Layout.fillWidth: true }

                    MeoText {
                        visible: launcherPopup.activeAppsModel !== null
                        text: launcherPopup.activeAppsModel
                              ? launcherPopup.activeAppsModel.count : ""
                        typeRole: "label"
                        typeSize: "small"
                        color: MeoTheme.contentOnSurfaceVariant
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * MeoTheme.globalScale
                    spacing: MeoTheme.space6

                    MeoChip {
                        id: allAppsChip
                        type: "assist"
                        size: "s"
                        label: MeoI18n.translator.i18n("All")
                        selected: launcherPopup.appsModelRow < 0
                        Accessible.name: MeoI18n.translator.i18n("Show all applications")
                        onClicked: {
                            launcherPopup.appsModelRow = -1
                            launcherPopup.appsCategoryName = ""
                            allAppsGrid.currentIndex = allAppsGrid.count > 0 ? 0 : -1
                            allAppsGrid.positionViewAtBeginning()
                        }
                    }

                    ListView {
                        id: appCategoryList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        spacing: MeoTheme.space6
                        clip: true
                        reuseItems: true
                        model: rootAppModel
                        boundsBehavior: Flickable.StopAtBounds
                        Accessible.name: MeoI18n.translator.i18n("Application categories")

                        // RootModel rows 0 and 1 are Favorites and All Apps in
                        // Plasma Kickoff. Rows 2+ are KDE's category models.
                        delegate: MeoChip {
                            id: categoryChip
                            required property int index
                            required property string display

                            readonly property bool isCategory:
                                index >= 2 && display.trim() !== ""

                            width: isCategory ? implicitWidth : 0
                            height: appCategoryList.height
                            visible: isCategory
                            enabled: isCategory
                            type: "assist"
                            size: "s"
                            label: display
                            selected: launcherPopup.appsModelRow === index
                            Accessible.name: display

                            onClicked: {
                                launcherPopup.appsModelRow = index
                                launcherPopup.appsCategoryName = display
                                allAppsGrid.currentIndex = allAppsGrid.count > 0 ? 0 : -1
                                allAppsGrid.positionViewAtBeginning()
                            }
                        }

                        QQC2.ScrollBar.horizontal: MeoScrollBar {}
                    }
                }

                GridView {
                    id: allAppsGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    readonly property int columnCount: Math.max(
                        launcherPopup.compactLayout ? 4 : 5,
                        Math.floor(width / (104 * MeoTheme.globalScale)))
                    cellWidth: width / columnCount
                    cellHeight: 104 * MeoTheme.globalScale
                    model: launcherPopup.activeAppsModel
                    reuseItems: true
                    currentIndex: count > 0 ? 0 : -1
                    keyNavigationWraps: false
                    Accessible.name: MeoI18n.translator.i18n("All applications")

                    delegate: MeoAppGridItem {
                        id: appTile
                        required property int index
                        required property var model
                        required property string display
                        required property var decoration

                        width: allAppsGrid.cellWidth
                        height: allAppsGrid.cellHeight
                        compact: false
                        title: appTile.display || ""
                        selected: allAppsGrid.currentIndex === appTile.index
                                  && allAppsGrid.activeFocus
                        iconContent: Component {
                            Kirigami.Icon {
                                anchors.fill: parent
                                source: appTile.decoration
                                        || "application-x-executable"
                            }
                        }

                        onTriggered: {
                            allAppsGrid.currentIndex = appTile.index
                            launcherPopup.triggerModel(
                                launcherPopup.activeAppsModel,
                                appTile.index)
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: function(eventPoint) {
                                allAppsGrid.currentIndex = appTile.index
                                launcherPopup.openContextMenu(
                                    appTile,
                                    eventPoint.position.x,
                                    eventPoint.position.y,
                                    launcherPopup.activeAppsModel,
                                    appTile.index,
                                    appTile.model)
                            }
                        }
                    }

                    Keys.onReturnPressed: appsPaneRoot.activateCurrent()
                    Keys.onEnterPressed: appsPaneRoot.activateCurrent()
                    Keys.onUpPressed: {
                        const previous = currentIndex - columnCount
                        if (previous < 0)
                            searchField.forceSearchFocus()
                        else
                            currentIndex = previous
                    }
                    Keys.onDownPressed: {
                        const next = currentIndex + columnCount
                        if (next < count)
                            currentIndex = next
                    }
                    Keys.onLeftPressed: {
                        if (currentIndex > 0)
                            currentIndex--
                    }
                    Keys.onRightPressed: {
                        if (currentIndex + 1 < count)
                            currentIndex++
                    }
                    Keys.onPressed: function(event) {
                        if ((event.key === Qt.Key_Menu || event.key === Qt.Key_F10)
                                && currentIndex >= 0) {
                            const item = itemAtIndex(currentIndex)
                            if (item) {
                                launcherPopup.openContextMenu(
                                    item, item.width / 2, item.height / 2,
                                    launcherPopup.activeAppsModel,
                                    currentIndex, item.model)
                            }
                            event.accepted = true
                        }
                    }

                    QQC2.ScrollBar.vertical: MeoScrollBar {}
                }

                MeoText {
                    Layout.fillWidth: true
                    visible: launcherPopup.activeAppsModel === null
                    text: MeoI18n.translator.i18n("Loading applications…")
                    typeRole: "body"
                    typeSize: "medium"
                    color: MeoTheme.contentOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }

                MeoText {
                    Layout.fillWidth: true
                    visible: launcherPopup.activeAppsModel !== null
                    text: MeoI18n.translator.i18n("Arrow keys Navigate   Enter Open   Menu / Right-click More")
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.contentOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
