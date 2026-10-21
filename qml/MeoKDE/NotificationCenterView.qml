pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.notificationmanager as NotificationManager
import org.kde.kirigami as Kirigami
import MeoUI 1.0

Item {
    id: root

    property var notifications: null
    property date currentDateTime: new Date()
    property bool showTitle: true
    property bool showHeader: true
    property bool showEmptyState: true
    property int modelRevision: 0
    Connections {
        target: root.notifications
        ignoreUnknownSignals: true
        function changed() { Qt.callLater(function() { root.modelRevision++ }) }
        function onRowsInserted() { changed() }
        function onRowsRemoved() { changed() }
        function onDataChanged() { changed() }
        function onModelReset() { changed() }
        function onCountChanged() { changed() }
    }
    readonly property real renderedHeight: notificationList.contentHeight
    property bool showSettingsAction: true
    property bool showJobs: true
    // Presentation choices are normalized once at the shared notification
    // surface.  They change only the view; NotificationManager remains the
    // data and action authority for every variant.
    property string notificationView: "cards"
    property string notificationPreview: "full"
    property bool showHistory: true
    property string density: "comfortable"
    readonly property bool compactView: notificationView === "compact"
    readonly property bool compactDensity: density === "compact"
    readonly property string normalizedPreview: notificationPreview === "summary"
                                               || notificationPreview === "hidden"
                                             ? notificationPreview : "full"
    readonly property real cardPadding: (compactView || compactDensity)
                                      ? MeoTheme.space8 : MeoTheme.space12

    readonly property int notificationCount: {
        root.modelRevision
        return notifications && typeof notifications.count === "number" ? notifications.count : 0
    }
    readonly property int unreadCount: notifications && typeof notifications.unreadNotificationsCount === "number"
                                       ? notifications.unreadNotificationsCount : 0
    readonly property int activeJobsCount: showJobs && notifications && typeof notifications.activeJobsCount === "number"
                                           ? notifications.activeJobsCount : 0
    readonly property int liveNotificationCount: notifications && typeof notifications.activeNotificationsCount === "number"
                                                 ? notifications.activeNotificationsCount : 0
    readonly property int historyNotificationCount: notifications && typeof notifications.expiredNotificationsCount === "number"
                                                    ? notifications.expiredNotificationsCount : 0
    readonly property int visibleNotificationCount: {
        root.modelRevision
        root.notificationCount
        root.showHistory
        root.showJobs
        let visibleCount = 0
        for (let row = 0; row < root.notificationCount; ++row) {
            if (root.isModelRowVisible(row))
                ++visibleCount
        }
        return visibleCount
    }
    readonly property int closableCount: {
        root.modelRevision
        root.notificationCount
        let count = 0
        for (let row = 0; row < root.notificationCount; ++row) {
            if (root.isModelRowVisible(row)
                    && Boolean(root.modelRoleValue(row,
                               NotificationManager.Notifications.ClosableRole,
                               "closable", false)))
                ++count
        }
        return count
    }
    property bool clearPending: false

    signal settingsRequested()

    function modelIndex(row) {
        return root.notifications && root.notifications.index
                ? root.notifications.index(row, 0) : null
    }

    function modelRoleValue(row, role, roleName, fallbackValue) {
        if (!root.notifications || row < 0 || row >= root.notificationCount)
            return fallbackValue
        if (root.notifications.data && root.notifications.index) {
            const value = root.notifications.data(root.notifications.index(row, 0), role)
            if (value !== undefined && value !== null)
                return value
        }
        if (root.notifications.get) {
            const entry = root.notifications.get(row)
            if (entry && entry[roleName] !== undefined && entry[roleName] !== null)
                return entry[roleName]
        }
        return fallbackValue
    }

    function isModelRowVisible(row) {
        const expired = Boolean(root.modelRoleValue(row,
                                NotificationManager.Notifications.ExpiredRole,
                                "expired", false))
        const type = Number(root.modelRoleValue(row,
                            NotificationManager.Notifications.TypeRole,
                            "type", NotificationManager.Notifications.NotificationType))
        return (root.showHistory || !expired)
                && (root.showJobs || type !== NotificationManager.Notifications.JobType)
    }

    function clearClosableNotifications() {
        if (!root.notifications || !root.notifications.data || !root.notifications.close)
            return
        if (root.closableCount <= 0)
            return
        root.clearPending = true
        clearFeedbackTimer.restart()
        for (let row = root.notifications.count - 1; row >= 0; --row) {
            const idx = root.notifications.index(row, 0)
            if (root.isModelRowVisible(row)
                    && root.notifications.data(idx, NotificationManager.Notifications.ClosableRole))
                root.notifications.close(idx)
        }
    }

    Timer {
        id: clearFeedbackTimer
        interval: MeoTheme.loadingFeedbackMinimumVisible
        repeat: false
        onTriggered: root.clearPending = false
    }

    function relativeTime(value) {
        if (!value)
            return ""
        const timestamp = new Date(value)
        if (isNaN(timestamp.getTime()))
            return ""
        const seconds = Math.max(0, Math.floor((root.currentDateTime.getTime() - timestamp.getTime()) / 1000))
        if (seconds < 60)
            return MeoI18n.translator.i18n("Now")
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60)
            return MeoI18n.translator.i18n("%1 min", minutes)
        const hours = Math.floor(minutes / 60)
        if (hours < 24)
            return MeoI18n.translator.i18n("%1 h", hours)
        if (hours < 48)
            return MeoI18n.translator.i18n("Yesterday")
        return Qt.formatDate(timestamp, Qt.locale().dateFormat(Locale.ShortFormat))
    }

    // Notification bodies may contain freedesktop markup. The shell deliberately
    // presents a bounded plain-text projection so notifications cannot load
    // remote content or inject interactive rich-text elements into the center.
    function plainText(value) {
        if (value === undefined || value === null)
            return ""
        return String(value).slice(0, 16384)
            .replace(/<br\s*\/?\s*>/gi, "\n")
            .replace(/<\/(p|div|li)>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&nbsp;/gi, " ")
            .replace(/&amp;/gi, "&")
            .replace(/&lt;/gi, "<")
            .replace(/&gt;/gi, ">")
            .replace(/&quot;/gi, "\"")
            .replace(/&#39;/gi, "'")
            .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
            .replace(/[\u202A-\u202E\u2066-\u2069]/g, "")
            .slice(0, 4096)
            .trim()
    }

    function buttonLabel(value) {
        // MeoButton deliberately owns its typography. Remove angle brackets
        // as well as markup before passing untrusted notification labels to it,
        // so Qt's AutoText heuristic cannot reinterpret decoded entities.
        return root.plainText(value).replace(/[<>]/g, "")
    }

    function displayBody(body, type, percentage) {
        const projectedBody = root.plainText(body)
        if (projectedBody !== "")
            return projectedBody
        if (type === NotificationManager.Notifications.JobType && percentage >= 0)
            return MeoI18n.translator.i18n("Progress: %1%", percentage)
        return ""
    }

    function formatBytes(value) {
        const bytes = Math.max(0, Number(value) || 0)
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let amount = bytes
        let unit = 0
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024
            ++unit
        }
        return (unit === 0 || amount >= 100 ? Math.round(amount) : amount.toFixed(1)) + " " + units[unit]
    }

    function formatRemaining(seconds) {
        const total = Math.max(0, Math.round(Number(seconds) || 0))
        if (total < 60)
            return MeoI18n.translator.i18n("%1 s left", total)
        const minutes = Math.floor(total / 60)
        if (minutes < 60)
            return MeoI18n.translator.i18n("%1 min left", minutes)
        return MeoI18n.translator.i18n("%1 h %2 min left", Math.floor(minutes / 60), minutes % 60)
    }

    function fileName(url) {
        const text = String(url)
        const trimmed = text.endsWith("/") ? text.slice(0, -1) : text
        const name = trimmed.slice(trimmed.lastIndexOf("/") + 1)
        try {
            return decodeURIComponent(name)
        } catch (error) {
            return name
        }
    }

    // Models hand attached URLs over as a JS array; accept a single URL and a
    // nested list model as well.
    function asList(value) {
        if (value === undefined || value === null || value === "")
            return []
        if (Array.isArray(value))
            return value
        if (typeof value === "string")
            return [value]
        if (typeof value.count === "number" && value.get) {
            const result = []
            for (let i = 0; i < value.count; ++i) {
                const entry = value.get(i)
                result.push(entry && entry.modelData !== undefined ? entry.modelData : entry)
            }
            return result
        }
        return []
    }

    function applicationUrl(entry) {
        const id = String(entry || "").replace(/\.desktop$/, "")
        return /^[A-Za-z0-9][A-Za-z0-9._+\-]*$/.test(id) ? "applications:" + id + ".desktop" : ""
    }

    function safeIconName(primary, fallback) {
        const candidate = String(primary || "").slice(0, 256)
        if (/^[A-Za-z0-9][A-Za-z0-9._+\-]*$/.test(candidate))
            return candidate
        const fallbackCandidate = String(fallback || "").slice(0, 256)
        if (/^[A-Za-z0-9][A-Za-z0-9._+\-]*$/.test(fallbackCandidate))
            return fallbackCandidate
        return "notifications"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space8

        NotificationCenterHeader {
            visible: root.showHeader
            showTitle: root.showTitle
            showSettingsAction: root.showSettingsAction
            notificationCount: root.notificationCount
            closableCount: root.closableCount
            unreadCount: root.unreadCount
            activeJobsCount: root.activeJobsCount
            liveNotificationCount: root.liveNotificationCount
            historyNotificationCount: root.historyNotificationCount
            clearPending: root.clearPending
            onClearRequested: root.clearClosableNotifications()
            onSettingsRequested: root.settingsRequested()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MeoListView {
                id: notificationList
                anchors.fill: parent
                visible: opacity > 0
                enabled: root.visibleNotificationCount > 0
                opacity: root.visibleNotificationCount > 0 ? 1 : 0
                clip: true
                spacing: root.compactView || root.compactDensity
                         ? MeoTheme.space4 : MeoTheme.space8
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                preserveScrollPosition: true
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoTheme.motionDurationListInsert; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandardDecelerate }
                }
                // The center has no single selected row. Leaving ListView's
                // implicit current item enabled can auto-position a growing
                // model to that delegate while the opening transition runs.
                currentIndex: -1
                cacheBuffer: Math.max(height, 320 * MeoTheme.globalScale)
                model: root.notifications
                Behavior on opacity {
                    NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
                }
                delegate: MeoMotionSurface {
                    id: notificationCard

                    required property int index
                    required property var model
                    required property string summary
                    required property string body
                    required property string applicationName
                    required property string originName
                    required property string iconName
                    required property string applicationIconName
                    required property bool closable
                    required property bool expired
                    required property bool configurable
                    required property bool hasDefaultAction
                    required property bool hasReplyAction
                    required property string replyActionLabel
                    required property string replyPlaceholderText
                    required property string replySubmitButtonText
                    required property var actionNames
                    required property var actionLabels
                    required property int urgency
                    required property int percentage
                    required property int jobState
                    required property bool suspendable
                    required property bool killable
                    required property var created
                    required property var updated

                    readonly property var sourceIndex: root.modelIndex(index)
                    readonly property string displayIcon: root.safeIconName(iconName, applicationIconName)
                    readonly property string displaySource: root.plainText(originName) !== ""
                                                            ? MeoI18n.translator.i18n("%1 · %2", root.plainText(applicationName), root.plainText(originName))
                                                            : root.plainText(applicationName)
                    readonly property int notificationType: Number(model.type)
                    readonly property bool isJob: notificationType === NotificationManager.Notifications.JobType
                    readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
                    readonly property bool historical: expired
                    readonly property bool contentAllowed: (root.showHistory || !historical)
                                                           && (root.showJobs || !isJob)
                    readonly property var effectiveTime: updated || created
                    // Optional roles are read through `model` so every NotificationManager
                    // feature is shown when present without requiring it of other models.
                    readonly property var jobDetails: isJob && model.jobDetails !== undefined
                                                      ? model.jobDetails : null
                    readonly property var notificationImage: model.image !== undefined ? model.image : null
                    readonly property bool hasImage: notificationImage !== null
                                                     && notificationImage !== undefined
                                                     && String(notificationImage) !== ""
                    readonly property string desktopEntry: model.desktopEntry !== undefined
                                                           ? String(model.desktopEntry) : ""
                    readonly property string applicationLaunchUrl: root.applicationUrl(desktopEntry)
                    readonly property var attachedUrls: root.asList(model.urls)
                    readonly property string defaultActionText: model.defaultActionLabel !== undefined
                                                                ? String(model.defaultActionLabel) : ""
                    readonly property int jobErrorCode: model.jobError !== undefined ? Number(model.jobError) : 0
                    readonly property string jobErrorText: jobDetails && jobDetails.errorText
                                                           ? String(jobDetails.errorText) : ""
                    readonly property bool jobSuspended: jobState === NotificationManager.Notifications.JobStateSuspended
                    readonly property bool jobFinished: isJob
                                                        && jobState === NotificationManager.Notifications.JobStateStopped
                    readonly property string jobOpenUrl: jobDetails && jobDetails.effectiveDestUrl
                                                         && String(jobDetails.effectiveDestUrl) !== ""
                                                         ? String(jobDetails.effectiveDestUrl) : ""
                    readonly property bool clickable: !historical
                                                      && (hasDefaultAction || applicationLaunchUrl !== "")
                    readonly property bool compact: root.compactView
                    readonly property bool showPreview: root.normalizedPreview !== "hidden"
                    readonly property int previewLines: root.normalizedPreview === "full"
                                                            ? (compact ? 2 : 4)
                                                            : 2
                    property bool replyExpanded: false
                    property bool animateLayoutChange: false

                    ListView.onReused: {
                        replyExpanded = false
                        animateLayoutChange = false
                        replyField.clear()
                    }

                    // The default action when the app provides one; otherwise open the
                    // application that posted the notification.
                    function activate() {
                        if (!notificationCard.clickable || !root.notifications)
                            return
                        if (notificationCard.hasDefaultAction) {
                            if (root.notifications.invokeDefaultAction)
                                root.notifications.invokeDefaultAction(notificationCard.sourceIndex)
                            return
                        }
                        Qt.openUrlExternally(notificationCard.applicationLaunchUrl)
                        if (notificationCard.closable && root.notifications.close)
                            root.notifications.close(notificationCard.sourceIndex)
                    }

                    function toggleReply() {
                        animateLayoutChange = true
                        replyExpanded = !replyExpanded
                        replyLayoutTimer.restart()
                        if (replyExpanded)
                            Qt.callLater(function() { replyField.forceActiveFocus() })
                    }

                    function submitReply() {
                        if (!root.notifications || !root.notifications.reply || replyField.text.trim() === "")
                            return
                        root.notifications.reply(notificationCard.sourceIndex, replyField.text.trim(),
                                                 NotificationManager.Notifications.Close)
                        replyField.clear()
                        animateLayoutChange = true
                        notificationCard.replyExpanded = false
                        replyLayoutTimer.restart()
                    }

                    Timer {
                        id: replyLayoutTimer
                        interval: notificationCard.replyExpanded
                                  ? MeoTheme.motionDurationDisclosureEnter
                                  : MeoTheme.motionDurationDisclosureExit
                        repeat: false
                        onTriggered: notificationCard.animateLayoutChange = false
                    }

                    width: notificationList.width
                    objectName: "notificationCard-" + index
                    visible: contentAllowed
                    enabled: contentAllowed
                    height: contentAllowed ? implicitHeight : 0
                    opacity: contentAllowed ? 1 : 0
                    implicitHeight: cardContent.implicitHeight + 2 * root.cardPadding
                    color: critical ? MeoTheme.errorContainer : MeoTheme.surfaceContainerHigh
                    // Notification cards share the popup's expressive corner
                    // token, so they morph with the same MeoUI shape scale as
                    // the surrounding status surface.
                    radius: root.compactView ? ShellMetrics.radiusMedium : ShellMetrics.radiusLarge
                    elevation: 0
                    showOutline: false
                    // The disclosure controls the card's real height.  This
                    // mirrors DMS's retained-content collapse rather than
                    // deleting long text before the contraction completes.
                    clip: bodyDisclosure.animating
                    Behavior on implicitHeight {
                        enabled: (bodyDisclosure.userInitiatedExpansion
                                  || notificationCard.animateLayoutChange)
                                 && !MeoTheme.reduceMotion
                        NumberAnimation {
                            duration: bodyDisclosure.expanded
                                      ? MeoTheme.motionDurationDisclosureEnter
                                      : MeoTheme.motionDurationDisclosureExit
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: bodyDisclosure.expanded ? MeoTheme.motionEasingEmphasizedDecelerate : MeoTheme.motionEasingEmphasizedAccelerate
                        }
                    }
                    activeFocusOnTab: clickable
                    Accessible.role: Accessible.ListItem
                    Accessible.name: root.plainText(summary !== "" ? summary : applicationName)
                    Accessible.description: root.displayBody(body, notificationType, percentage)
                                            + (historical ? MeoI18n.translator.i18n(" Earlier notification.") : "")
                    Accessible.focusable: clickable
                    Accessible.onPressAction: activate()
                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: activate()
                    Keys.onSpacePressed: activate()

                    HoverHandler { id: cardHover }

                    MouseArea {
                        id: notificationPointer
                        anchors.fill: parent
                        enabled: notificationCard.clickable
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: notificationCard.activate()
                    }

                    // Default notification actions are full-card actions. Keep
                    // their feedback on the same shared click-point state layer
                    // as every MeoUI button instead of a card-local color swap.
                    MeoStateLayer {
                        anchors.fill: parent
                        enabled: notificationPointer.enabled
                        internalPointerTrackingEnabled: false
                        hovered: notificationPointer.containsMouse
                        pressed: notificationPointer.pressed
                        focused: notificationCard.activeFocus
                        pressX: notificationPointer.mouseX
                        pressY: notificationPointer.mouseY
                        radius: notificationCard.radius
                        focusColor: notificationCard.critical
                                    ? MeoTheme.contentOnErrorContainer : MeoTheme.primary
                    }

                    ColumnLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: root.cardPadding
                        spacing: notificationCard.compact ? MeoTheme.space4 : MeoTheme.space8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: MeoTheme.space8

                            Kirigami.Icon {
                                source: notificationCard.displayIcon
                                Layout.preferredWidth: 20 * MeoTheme.globalScale
                                Layout.preferredHeight: Layout.preferredWidth
                                color: notificationCard.critical ? MeoTheme.contentOnErrorContainer
                                                                 : MeoTheme.contentOnSurfaceVariant
                            }
                            MeoText {
                                Layout.fillWidth: true
                                text: notificationCard.displaySource !== ""
                                      ? notificationCard.displaySource : MeoI18n.translator.i18n("System")
                                textFormat: Text.PlainText
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                elide: Text.ElideRight
                                color: notificationCard.critical ? MeoTheme.contentOnErrorContainer
                                                                 : MeoTheme.contentOnSurfaceVariant
                            }
                            MeoText {
                                visible: notificationCard.critical
                                text: MeoI18n.translator.i18n("Critical")
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.contentOnErrorContainer
                                Accessible.name: MeoI18n.translator.i18n("Critical notification")
                            }
                            MeoText {
                                visible: notificationCard.historical && !notificationCard.critical
                                text: MeoI18n.translator.i18n("Earlier")
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.contentOnSurfaceVariant
                                Accessible.name: MeoI18n.translator.i18n("Notification history")
                            }
                            MeoText {
                                text: root.relativeTime(notificationCard.effectiveTime)
                                typeRole: "label"
                                typeSize: "small"
                                color: notificationCard.critical ? MeoTheme.contentOnErrorContainer
                                                                 : MeoTheme.contentOnSurfaceVariant
                            }
                            MeoIconButton {
                                id: configureButton
                                // Per-app configuration is a secondary action:
                                // reveal it on hover/focus so every card is not
                                // two icon buttons wide. It keeps its space so
                                // the time and dismiss controls do not shift.
                                visible: notificationCard.configurable
                                opacity: cardHover.hovered || notificationCard.activeFocus
                                         || configureButton.activeFocus ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort2
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: MeoTheme.motionEasingStandard
                                    }
                                }
                                type: "standard"
                                size: "s"
                                icon.name: "settings"
                                Accessible.name: MeoI18n.translator.i18n("Configure notifications from %1", root.plainText(notificationCard.applicationName))
                                onClicked: if (root.notifications && root.notifications.configure)
                                               root.notifications.configure(notificationCard.sourceIndex)
                            }
                            MeoIconButton {
                                visible: notificationCard.closable
                                type: "standard"
                                size: "s"
                                icon.name: "close"
                                Accessible.name: MeoI18n.translator.i18n("Dismiss notification")
                                onClicked: if (root.notifications && root.notifications.close)
                                               root.notifications.close(notificationCard.sourceIndex)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: MeoTheme.space12

                            // Large image or avatar supplied by the application.
                            Kirigami.Icon {
                                visible: notificationCard.hasImage
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: (notificationCard.compact ? 40 : 48) * MeoTheme.globalScale
                                Layout.preferredHeight: Layout.preferredWidth
                                source: notificationCard.notificationImage
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: notificationCard.compact ? 0 : MeoTheme.space4

                                MeoText {
                                    Layout.fillWidth: true
                                    text: root.plainText(notificationCard.summary !== ""
                                                         ? notificationCard.summary
                                                         : notificationCard.applicationName)
                                    textFormat: Text.PlainText
                                    typeRole: "body"
                                    typeSize: notificationCard.compact ? "medium" : "large"
                                    emphasized: true
                                    wrapMode: Text.Wrap
                                    color: notificationCard.critical ? MeoTheme.contentOnErrorContainer : MeoTheme.contentOnSurface
                                }

                                NotificationBodyDisclosure {
                                    id: bodyDisclosure
                                    Layout.fillWidth: true
                                    visible: notificationCard.showPreview && bodyText !== ""
                                    bodyText: root.displayBody(notificationCard.body, notificationCard.notificationType,
                                                               notificationCard.percentage)
                                    collapsedLines: notificationCard.previewLines
                                    compact: notificationCard.compact
                                    critical: notificationCard.critical
                                }

                            }
                        }

                        ColumnLayout {
                            visible: notificationCard.isJob
                            Layout.fillWidth: true
                            spacing: MeoTheme.space4

                            RowLayout {
                                visible: notificationCard.percentage >= 0
                                Layout.fillWidth: true
                                spacing: MeoTheme.space8

                                MeoProgressBar {
                                    Layout.fillWidth: true
                                    value: Math.max(0, Math.min(100, notificationCard.percentage)) / 100
                                    isThick: true
                                    enabled: !notificationCard.jobSuspended
                                }
                                MeoText {
                                    text: MeoI18n.translator.i18n("%1%", Math.max(0, notificationCard.percentage))
                                    typeRole: "label"
                                    typeSize: "small"
                                    color: MeoTheme.contentOnSurfaceVariant
                                }
                            }

                            // Transfer figures: size, speed and remaining time.
                            MeoText {
                                readonly property var details: notificationCard.jobDetails
                                readonly property real total: details ? Number(details.totalBytes) : 0
                                readonly property real done: details ? Number(details.processedBytes) : 0
                                readonly property real speed: details ? Number(details.speed) : 0
                                visible: notificationCard.isJob && !notificationCard.jobFinished && text !== ""
                                Layout.fillWidth: true
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.contentOnSurfaceVariant
                                elide: Text.ElideRight
                                text: {
                                    const parts = []
                                    if (notificationCard.jobSuspended)
                                        parts.push(MeoI18n.translator.i18n("Paused"))
                                    if (total > 0)
                                        parts.push(MeoI18n.translator.i18n("%1 of %2", root.formatBytes(done), root.formatBytes(total)))
                                    else if (done > 0)
                                        parts.push(root.formatBytes(done))
                                    if (speed > 0 && !notificationCard.jobSuspended) {
                                        parts.push(MeoI18n.translator.i18n("%1/s", root.formatBytes(speed)))
                                        if (total > done)
                                            parts.push(root.formatRemaining((total - done) / speed))
                                    }
                                    return parts.join(" · ")
                                }
                            }

                            // Application-provided description lines (for example source and destination).
                            Repeater {
                                model: notificationCard.jobDetails ? [
                                    [notificationCard.jobDetails.descriptionLabel1, notificationCard.jobDetails.descriptionValue1],
                                    [notificationCard.jobDetails.descriptionLabel2, notificationCard.jobDetails.descriptionValue2]
                                ] : []
                                delegate: MeoText {
                                    required property var modelData
                                    visible: String(modelData[1] || "") !== ""
                                    Layout.fillWidth: true
                                    typeRole: "label"
                                    typeSize: "small"
                                    color: MeoTheme.contentOnSurfaceVariant
                                    textFormat: Text.PlainText
                                    elide: Text.ElideMiddle
                                    text: String(modelData[0] || "") !== ""
                                          ? root.plainText(modelData[0]) + ": " + root.plainText(modelData[1])
                                          : root.plainText(modelData[1])
                                }
                            }

                            MeoText {
                                visible: notificationCard.jobErrorCode !== 0
                                Layout.fillWidth: true
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                color: notificationCard.critical ? MeoTheme.contentOnErrorContainer : MeoTheme.error
                                text: notificationCard.jobErrorText !== ""
                                      ? root.plainText(notificationCard.jobErrorText)
                                      : MeoI18n.translator.i18n("The task failed.")
                            }
                        }

                        Flow {
                            visible: !notificationCard.historical
                                     && (notificationCard.hasReplyAction
                                         || (notificationCard.actionNames && notificationCard.actionNames.length > 0)
                                         || (notificationCard.isJob
                                             && (notificationCard.suspendable || notificationCard.killable
                                                 || notificationCard.jobOpenUrl !== ""))
                                         || notificationCard.attachedUrls.length > 0
                                         || (notificationCard.hasDefaultAction
                                             && notificationCard.defaultActionText !== ""))
                            Layout.fillWidth: true
                            spacing: MeoTheme.space4

                            Repeater {
                                model: notificationCard.actionNames || []

                                delegate: MeoButton {
                                    required property int index
                                    required property string modelData
                                    type: index === 0 ? "tonal" : "text"
                                    size: "s"
                                    enabled: !notificationCard.historical
                                    text: root.buttonLabel(notificationCard.actionLabels
                                                           && index < notificationCard.actionLabels.length
                                                          ? notificationCard.actionLabels[index] : modelData)
                                    onClicked: if (root.notifications && root.notifications.invokeAction)
                                                   root.notifications.invokeAction(notificationCard.sourceIndex, modelData)
                                }
                            }

                            MeoButton {
                                visible: notificationCard.hasDefaultAction && notificationCard.defaultActionText !== ""
                                type: "tonal"
                                size: "s"
                                text: root.buttonLabel(notificationCard.defaultActionText)
                                onClicked: notificationCard.activate()
                            }

                            // Files attached to the notification open in their default application.
                            Repeater {
                                model: (notificationCard.attachedUrls || []).slice(0, 4)
                                delegate: MeoButton {
                                    required property var modelData
                                    type: "tonal"
                                    size: "s"
                                    icon.name: "attach_file"
                                    text: root.buttonLabel(root.fileName(modelData))
                                    onClicked: Qt.openUrlExternally(modelData)
                                }
                            }

                            MeoButton {
                                visible: notificationCard.isJob && notificationCard.jobOpenUrl !== ""
                                type: notificationCard.jobFinished ? "tonal" : "text"
                                size: "s"
                                icon.name: "folder_open"
                                text: MeoI18n.translator.i18n("Open")
                                onClicked: Qt.openUrlExternally(notificationCard.jobOpenUrl)
                            }

                            MeoButton {
                                objectName: "notificationReplyButton-" + notificationCard.index
                                visible: !notificationCard.historical && notificationCard.hasReplyAction
                                type: notificationCard.replyExpanded ? "tonal" : "text"
                                size: "s"
                                text: notificationCard.replyActionLabel !== ""
                                      ? root.buttonLabel(notificationCard.replyActionLabel) : MeoI18n.translator.i18n("Reply")
                                onClicked: notificationCard.toggleReply()
                            }

                            MeoButton {
                                visible: !notificationCard.historical && notificationCard.isJob && notificationCard.suspendable
                                type: "text"
                                size: "s"
                                text: notificationCard.jobState === NotificationManager.Notifications.JobStateSuspended
                                      ? MeoI18n.translator.i18n("Resume") : MeoI18n.translator.i18n("Pause")
                                onClicked: {
                                    if (!root.notifications)
                                        return
                                    if (notificationCard.jobState === NotificationManager.Notifications.JobStateSuspended)
                                        root.notifications.resumeJob(notificationCard.sourceIndex)
                                    else
                                        root.notifications.suspendJob(notificationCard.sourceIndex)
                                }
                            }

                            MeoButton {
                                visible: !notificationCard.historical && notificationCard.isJob && notificationCard.killable
                                type: "text"
                                size: "s"
                                text: MeoI18n.translator.i18n("Cancel")
                                onClicked: if (root.notifications && root.notifications.killJob)
                                               root.notifications.killJob(notificationCard.sourceIndex)
                            }
                        }

                        RowLayout {
                            visible: !notificationCard.historical && notificationCard.hasReplyAction && notificationCard.replyExpanded
                            Layout.fillWidth: true
                            spacing: MeoTheme.space8

                            MeoTextField {
                                id: replyField
                                Layout.fillWidth: true
                                size: "s"
                                type: "outlined"
                                placeholder: notificationCard.replyPlaceholderText !== ""
                                             ? root.plainText(notificationCard.replyPlaceholderText)
                                             : MeoI18n.translator.i18n("Write a reply")
                                Accessible.name: placeholder
                                onAccepted: notificationCard.submitReply()
                            }

                            MeoButton {
                                type: "filled"
                                size: "s"
                                enabled: replyField.text.trim() !== ""
                                text: notificationCard.replySubmitButtonText !== ""
                                      ? root.buttonLabel(notificationCard.replySubmitButtonText) : MeoI18n.translator.i18n("Send")
                                onClicked: notificationCard.submitReply()
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: MeoScrollBar {}
            }

            MeoMotionSurface {
                anchors.top: parent.top
                width: parent.width
                height: 184 * MeoTheme.globalScale
                color: MeoTheme.surfaceContainerHigh
                radius: ShellMetrics.radiusLarge
                elevation: 0
                showOutline: false
                visible: opacity > 0
                enabled: root.visibleNotificationCount === 0
                opacity: root.showEmptyState && root.visibleNotificationCount === 0 ? 1 : 0
                PopupEmptyState {
                anchors.fill: parent
                anchors.margins: MeoTheme.space16
                iconName: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications_none"
                title: NotificationManager.Server.inhibited
                       ? MeoI18n.translator.i18n("Do Not Disturb is on")
                       : (root.notificationCount > 0 ? MeoI18n.translator.i18n("No recent notifications")
                                                     : MeoI18n.translator.i18n("You’re all caught up"))
                description: NotificationManager.Server.inhibited
                             ? MeoI18n.translator.i18n("New notifications are collected quietly until you turn it off.")
                             : (root.notificationCount > 0
                                ? MeoI18n.translator.i18n("Older notifications or background jobs are hidden by this view’s preferences.")
                                : MeoI18n.translator.i18n("New notifications and background jobs will appear here."))
                actionText: ""
                onActionRequested: root.settingsRequested()
                }
                Behavior on opacity {
                    NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
                }
            }
        }
    }
}
