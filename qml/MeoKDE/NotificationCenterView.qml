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

    readonly property int notificationCount: notifications && typeof notifications.count === "number"
                                             ? notifications.count : 0
    readonly property int unreadCount: notifications && typeof notifications.unreadNotificationsCount === "number"
                                       ? notifications.unreadNotificationsCount : 0
    readonly property int activeJobsCount: showJobs && notifications && typeof notifications.activeJobsCount === "number"
                                           ? notifications.activeJobsCount : 0
    readonly property int liveNotificationCount: notifications && typeof notifications.activeNotificationsCount === "number"
                                                 ? notifications.activeNotificationsCount : 0
    readonly property int historyNotificationCount: notifications && typeof notifications.expiredNotificationsCount === "number"
                                                    ? notifications.expiredNotificationsCount : 0
    readonly property int visibleNotificationCount: {
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
            return qsTr("Now")
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60)
            return qsTr("%1 min").arg(minutes)
        const hours = Math.floor(minutes / 60)
        if (hours < 24)
            return qsTr("%1 h").arg(hours)
        if (hours < 48)
            return qsTr("Yesterday")
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
            return qsTr("Progress: %1%").arg(percentage)
        return ""
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
                preserveScrollPosition: false
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
                                                            ? qsTr("%1 · %2").arg(root.plainText(applicationName)).arg(root.plainText(originName))
                                                            : root.plainText(applicationName)
                    readonly property int notificationType: Number(model.type)
                    readonly property bool isJob: notificationType === NotificationManager.Notifications.JobType
                    readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
                    readonly property bool historical: expired
                    readonly property bool contentAllowed: (root.showHistory || !historical)
                                                           && (root.showJobs || !isJob)
                    readonly property var effectiveTime: updated || created
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
                    activeFocusOnTab: hasDefaultAction && !historical
                    Accessible.role: Accessible.ListItem
                    Accessible.name: root.plainText(summary !== "" ? summary : applicationName)
                    Accessible.description: root.displayBody(body, notificationType, percentage)
                                            + (historical ? qsTr(" Earlier notification.") : "")
                    Accessible.focusable: hasDefaultAction && !historical
                    Accessible.onPressAction: if (hasDefaultAction && !historical && root.notifications
                                                     && root.notifications.invokeDefaultAction)
                                                  root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onReturnPressed: if (hasDefaultAction && !historical && root.notifications
                                               && root.notifications.invokeDefaultAction)
                                              root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onEnterPressed: if (hasDefaultAction && !historical && root.notifications
                                              && root.notifications.invokeDefaultAction)
                                             root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onSpacePressed: if (hasDefaultAction && !historical && root.notifications
                                              && root.notifications.invokeDefaultAction)
                                             root.notifications.invokeDefaultAction(sourceIndex)

                    MouseArea {
                        id: notificationPointer
                        anchors.fill: parent
                        enabled: notificationCard.hasDefaultAction && !notificationCard.historical
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (root.notifications && root.notifications.invokeDefaultAction)
                                       root.notifications.invokeDefaultAction(notificationCard.sourceIndex)
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
                                    ? MeoTheme.onErrorContainer : MeoTheme.primary
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
                                color: notificationCard.critical ? MeoTheme.onErrorContainer
                                                                 : MeoTheme.onSurfaceVariant
                            }
                            MeoText {
                                Layout.fillWidth: true
                                text: notificationCard.displaySource !== ""
                                      ? notificationCard.displaySource : qsTr("System")
                                textFormat: Text.PlainText
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                elide: Text.ElideRight
                                color: notificationCard.critical ? MeoTheme.onErrorContainer
                                                                 : MeoTheme.onSurfaceVariant
                            }
                            MeoText {
                                visible: notificationCard.critical
                                text: qsTr("Critical")
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.onErrorContainer
                                Accessible.name: qsTr("Critical notification")
                            }
                            MeoText {
                                visible: notificationCard.historical && !notificationCard.critical
                                text: qsTr("Earlier")
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                color: MeoTheme.onSurfaceVariant
                                Accessible.name: qsTr("Notification history")
                            }
                            MeoText {
                                text: root.relativeTime(notificationCard.effectiveTime)
                                typeRole: "label"
                                typeSize: "small"
                                color: notificationCard.critical ? MeoTheme.onErrorContainer
                                                                 : MeoTheme.onSurfaceVariant
                            }
                            MeoIconButton {
                                visible: notificationCard.configurable
                                type: "standard"
                                size: "s"
                                icon.name: "settings"
                                Accessible.name: qsTr("Configure notifications from %1")
                                                 .arg(root.plainText(notificationCard.applicationName))
                                onClicked: if (root.notifications && root.notifications.configure)
                                               root.notifications.configure(notificationCard.sourceIndex)
                            }
                            MeoIconButton {
                                visible: notificationCard.closable
                                type: "standard"
                                size: "s"
                                icon.name: "close"
                                Accessible.name: qsTr("Dismiss notification")
                                onClicked: if (root.notifications && root.notifications.close)
                                               root.notifications.close(notificationCard.sourceIndex)
                            }
                        }

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
                            color: notificationCard.critical ? MeoTheme.onErrorContainer : MeoTheme.onSurface
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

                        RowLayout {
                            visible: notificationCard.isJob && notificationCard.percentage >= 0
                            Layout.fillWidth: true
                            spacing: MeoTheme.space8

                            MeoProgressBar {
                                Layout.fillWidth: true
                                value: Math.max(0, Math.min(100, notificationCard.percentage)) / 100
                                isThick: true
                            }
                            MeoText {
                                text: qsTr("%1%").arg(Math.max(0, notificationCard.percentage))
                                typeRole: "label"
                                typeSize: "small"
                                color: MeoTheme.onSurfaceVariant
                            }
                        }

                        Flow {
                            visible: !notificationCard.historical
                                     && (notificationCard.hasReplyAction
                                         || (notificationCard.actionNames && notificationCard.actionNames.length > 0)
                                         || (notificationCard.isJob
                                             && (notificationCard.suspendable || notificationCard.killable)))
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
                                objectName: "notificationReplyButton-" + notificationCard.index
                                visible: !notificationCard.historical && notificationCard.hasReplyAction
                                type: notificationCard.replyExpanded ? "tonal" : "text"
                                size: "s"
                                text: notificationCard.replyActionLabel !== ""
                                      ? root.buttonLabel(notificationCard.replyActionLabel) : qsTr("Reply")
                                onClicked: notificationCard.toggleReply()
                            }

                            MeoButton {
                                visible: !notificationCard.historical && notificationCard.isJob && notificationCard.suspendable
                                type: "text"
                                size: "s"
                                text: notificationCard.jobState === NotificationManager.Notifications.JobStateSuspended
                                      ? qsTr("Resume") : qsTr("Pause")
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
                                text: qsTr("Cancel")
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
                                             : qsTr("Write a reply")
                                Accessible.name: placeholder
                                onAccepted: notificationCard.submitReply()
                            }

                            MeoButton {
                                type: "filled"
                                size: "s"
                                enabled: replyField.text.trim() !== ""
                                text: notificationCard.replySubmitButtonText !== ""
                                      ? root.buttonLabel(notificationCard.replySubmitButtonText) : qsTr("Send")
                                onClicked: notificationCard.submitReply()
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: MeoScrollBar {}
            }

            PopupEmptyState {
                anchors.fill: parent
                visible: opacity > 0
                enabled: root.visibleNotificationCount === 0
                opacity: root.visibleNotificationCount === 0 ? 1 : 0
                iconName: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications_none"
                title: NotificationManager.Server.inhibited
                       ? qsTr("Do Not Disturb is on")
                       : (root.notificationCount > 0 ? qsTr("No recent notifications")
                                                     : qsTr("You’re all caught up"))
                description: NotificationManager.Server.inhibited
                             ? qsTr("New notifications are collected quietly until you turn it off.")
                             : (root.notificationCount > 0
                                ? qsTr("Older notifications or background jobs are hidden by this view’s preferences.")
                                : qsTr("New notifications and background jobs will appear here."))
                actionText: root.showSettingsAction ? qsTr("Notification settings") : ""
                onActionRequested: root.settingsRequested()
                Behavior on opacity {
                    NumberAnimation { duration: MeoTheme.motionDurationPanelState; easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandard }
                }
            }
        }
    }
}
