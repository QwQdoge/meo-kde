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

    readonly property int notificationCount: notifications && typeof notifications.count === "number"
                                             ? notifications.count : 0
    readonly property int unreadCount: notifications && typeof notifications.unreadNotificationsCount === "number"
                                       ? notifications.unreadNotificationsCount : 0
    readonly property int activeJobsCount: notifications && typeof notifications.activeJobsCount === "number"
                                           ? notifications.activeJobsCount : 0

    signal settingsRequested()

    function modelIndex(row) {
        return root.notifications && root.notifications.index
                ? root.notifications.index(row, 0) : null
    }

    function clearClosableNotifications() {
        if (!root.notifications || !root.notifications.data || !root.notifications.close)
            return
        for (let row = root.notifications.count - 1; row >= 0; --row) {
            const idx = root.notifications.index(row, 0)
            if (root.notifications.data(idx, NotificationManager.Notifications.ClosableRole))
                root.notifications.close(idx)
        }
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
        return Qt.formatDate(timestamp, Qt.DefaultLocaleShortDate)
    }

    function displayBody(body, type, percentage) {
        if (body !== "")
            return body
        if (type === NotificationManager.Notifications.JobType && percentage >= 0)
            return qsTr("Progress: %1%").arg(percentage)
        return ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MeoTheme.space8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * MeoTheme.globalScale
            spacing: MeoTheme.space8

            ColumnLayout {
                visible: root.showTitle
                Layout.fillWidth: true
                spacing: 0

                MeoText {
                    text: root.unreadCount > 0
                          ? qsTr("Notifications · %1 unread").arg(root.unreadCount)
                          : qsTr("Notifications")
                    typeRole: "title"
                    typeSize: "medium"
                    emphasized: true
                    color: MeoTheme.onSurface
                }

                MeoText {
                    visible: root.activeJobsCount > 0
                    text: root.activeJobsCount === 1
                          ? qsTr("1 background task")
                          : qsTr("%1 background tasks").arg(root.activeJobsCount)
                    typeRole: "label"
                    typeSize: "small"
                    color: MeoTheme.onSurfaceVariant
                }
            }

            Item { visible: !root.showTitle; Layout.fillWidth: true }

            MeoIconButton {
                type: NotificationManager.Server.inhibited ? "filled" : "tonal"
                size: "s"
                icon.name: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications"
                enabled: NotificationManager.Server.valid
                Accessible.name: NotificationManager.Server.inhibited
                                 ? qsTr("Turn off Do Not Disturb")
                                 : qsTr("Turn on Do Not Disturb")
                Accessible.checked: NotificationManager.Server.inhibited
                onClicked: NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
            }

            MeoButton {
                visible: root.notificationCount > 0
                type: "text"
                size: "s"
                text: qsTr("Clear all")
                onClicked: root.clearClosableNotifications()
            }

            MeoIconButton {
                visible: root.showSettingsAction
                type: "standard"
                size: "s"
                icon.name: "settings"
                Accessible.name: qsTr("Notification settings")
                onClicked: root.settingsRequested()
            }
        }

        MeoMotionSurface {
            visible: NotificationManager.Server.inhibited
            Layout.fillWidth: true
            Layout.preferredHeight: dndMessage.implicitHeight + 2 * MeoTheme.space8
            color: MeoTheme.secondaryContainer
            radius: MeoTheme.shapeMedium
            elevation: 0

            RowLayout {
                id: dndMessage
                anchors.fill: parent
                anchors.margins: MeoTheme.space8
                spacing: MeoTheme.space8

                MeoIcon {
                    icon: "do_not_disturb_on"
                    size: 18
                    color: MeoTheme.onSecondaryContainer
                }
                MeoText {
                    Layout.fillWidth: true
                    text: qsTr("Do Not Disturb is on. New notifications are collected quietly.")
                    typeRole: "label"
                    typeSize: "small"
                    wrapMode: Text.Wrap
                    color: MeoTheme.onSecondaryContainer
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: notificationList
                anchors.fill: parent
                visible: opacity > 0
                enabled: count > 0
                opacity: count > 0 ? 1 : 0
                clip: true
                spacing: MeoTheme.space8
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: Math.max(height, 320 * MeoTheme.globalScale)
                model: root.notifications
                Behavior on opacity {
                    NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                }
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: MeoMotion.stateChange; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; to: 0.985; duration: MeoMotion.stateChange; easing.type: Easing.InCubic }
                    }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                }

                delegate: MeoMotionSurface {
                    id: notificationCard

                    required property int index
                    required property string summary
                    required property string body
                    required property string applicationName
                    required property string iconName
                    required property string applicationIconName
                    required property bool closable
                    required property bool configurable
                    required property bool hasDefaultAction
                    required property bool hasReplyAction
                    required property string replyActionLabel
                    required property string replyPlaceholderText
                    required property string replySubmitButtonText
                    required property var actionNames
                    required property var actionLabels
                    required property int type
                    required property int urgency
                    required property int percentage
                    required property int jobState
                    required property bool suspendable
                    required property bool killable
                    required property var created
                    required property var updated

                    readonly property var sourceIndex: root.modelIndex(index)
                    readonly property string displayIcon: iconName !== "" ? iconName
                                                          : (applicationIconName !== "" ? applicationIconName
                                                                                       : "notifications")
                    readonly property bool isJob: type === NotificationManager.Notifications.JobType
                    readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
                    readonly property var effectiveTime: updated || created
                    property bool replyExpanded: false

                    ListView.onReused: {
                        replyExpanded = false
                        replyField.clear()
                    }

                    function submitReply() {
                        if (!root.notifications || !root.notifications.reply || replyField.text.trim() === "")
                            return
                        root.notifications.reply(notificationCard.sourceIndex, replyField.text.trim(),
                                                 NotificationManager.Notifications.Close)
                        replyField.clear()
                        notificationCard.replyExpanded = false
                    }

                    width: notificationList.width
                    implicitHeight: cardContent.implicitHeight + 2 * MeoTheme.space12
                    color: critical ? MeoTheme.errorContainer : MeoTheme.surfaceContainerHigh
                    radius: MeoTheme.shapeLarge
                    elevation: 0
                    Behavior on implicitHeight {
                        NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                    }
                    activeFocusOnTab: hasDefaultAction
                    Accessible.role: Accessible.ListItem
                    Accessible.name: summary !== "" ? summary : applicationName
                    Accessible.description: root.displayBody(body, type, percentage)
                    Accessible.focusable: hasDefaultAction
                    Accessible.onPressAction: if (hasDefaultAction && root.notifications
                                                     && root.notifications.invokeDefaultAction)
                                                  root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onReturnPressed: if (hasDefaultAction && root.notifications
                                               && root.notifications.invokeDefaultAction)
                                              root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onEnterPressed: if (hasDefaultAction && root.notifications
                                              && root.notifications.invokeDefaultAction)
                                             root.notifications.invokeDefaultAction(sourceIndex)
                    Keys.onSpacePressed: if (hasDefaultAction && root.notifications
                                              && root.notifications.invokeDefaultAction)
                                             root.notifications.invokeDefaultAction(sourceIndex)

                    MouseArea {
                        anchors.fill: parent
                        enabled: notificationCard.hasDefaultAction
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (root.notifications && root.notifications.invokeDefaultAction)
                                       root.notifications.invokeDefaultAction(notificationCard.sourceIndex)
                    }

                    ColumnLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: MeoTheme.space12
                        spacing: MeoTheme.space8

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
                                text: notificationCard.applicationName !== ""
                                      ? notificationCard.applicationName : qsTr("System")
                                typeRole: "label"
                                typeSize: "small"
                                emphasized: true
                                elide: Text.ElideRight
                                color: notificationCard.critical ? MeoTheme.onErrorContainer
                                                                 : MeoTheme.onSurfaceVariant
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
                                Accessible.name: qsTr("Configure notifications from %1").arg(notificationCard.applicationName)
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
                            text: notificationCard.summary !== "" ? notificationCard.summary
                                                                   : notificationCard.applicationName
                            typeRole: "body"
                            typeSize: "large"
                            emphasized: true
                            wrapMode: Text.Wrap
                            color: notificationCard.critical ? MeoTheme.onErrorContainer : MeoTheme.onSurface
                        }

                        MeoText {
                            visible: text !== ""
                            Layout.fillWidth: true
                            text: root.displayBody(notificationCard.body, notificationCard.type,
                                                   notificationCard.percentage)
                            typeRole: "body"
                            typeSize: "medium"
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: notificationCard.critical ? MeoTheme.onErrorContainer
                                                             : MeoTheme.onSurfaceVariant
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
                            visible: notificationCard.hasReplyAction
                                     || (notificationCard.actionNames && notificationCard.actionNames.length > 0)
                                     || (notificationCard.isJob && (notificationCard.suspendable || notificationCard.killable))
                            Layout.fillWidth: true
                            spacing: MeoTheme.space4

                            Repeater {
                                model: notificationCard.actionNames || []

                                delegate: MeoButton {
                                    required property int index
                                    required property string modelData
                                    type: index === 0 ? "tonal" : "text"
                                    size: "s"
                                    text: notificationCard.actionLabels && index < notificationCard.actionLabels.length
                                          ? notificationCard.actionLabels[index] : modelData
                                    onClicked: if (root.notifications && root.notifications.invokeAction)
                                                   root.notifications.invokeAction(notificationCard.sourceIndex, modelData)
                                }
                            }

                            MeoButton {
                                visible: notificationCard.hasReplyAction
                                type: notificationCard.replyExpanded ? "tonal" : "text"
                                size: "s"
                                text: notificationCard.replyActionLabel !== ""
                                      ? notificationCard.replyActionLabel : qsTr("Reply")
                                onClicked: {
                                    notificationCard.replyExpanded = !notificationCard.replyExpanded
                                    if (notificationCard.replyExpanded)
                                        replyField.forceActiveFocus()
                                }
                            }

                            MeoButton {
                                visible: notificationCard.isJob && notificationCard.suspendable
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
                                visible: notificationCard.isJob && notificationCard.killable
                                type: "text"
                                size: "s"
                                text: qsTr("Cancel")
                                onClicked: if (root.notifications && root.notifications.killJob)
                                               root.notifications.killJob(notificationCard.sourceIndex)
                            }
                        }

                        RowLayout {
                            visible: notificationCard.hasReplyAction && notificationCard.replyExpanded
                            Layout.fillWidth: true
                            spacing: MeoTheme.space8

                            MeoTextField {
                                id: replyField
                                Layout.fillWidth: true
                                size: "s"
                                type: "outlined"
                                placeholder: notificationCard.replyPlaceholderText !== ""
                                             ? notificationCard.replyPlaceholderText : qsTr("Write a reply")
                                Accessible.name: placeholder
                                onAccepted: notificationCard.submitReply()
                            }

                            MeoButton {
                                type: "filled"
                                size: "s"
                                enabled: replyField.text.trim() !== ""
                                text: notificationCard.replySubmitButtonText !== ""
                                      ? notificationCard.replySubmitButtonText : qsTr("Send")
                                onClicked: notificationCard.submitReply()
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            PopupEmptyState {
                anchors.fill: parent
                visible: opacity > 0
                enabled: notificationList.count === 0
                opacity: notificationList.count === 0 ? 1 : 0
                iconName: NotificationManager.Server.inhibited ? "do_not_disturb_on" : "notifications_none"
                title: NotificationManager.Server.inhibited ? qsTr("Do Not Disturb is on") : qsTr("You’re all caught up")
                description: NotificationManager.Server.inhibited
                             ? qsTr("New notifications are collected quietly until you turn it off.")
                             : qsTr("New notifications and background jobs will appear here.")
                actionText: root.showSettingsAction ? qsTr("Notification settings") : ""
                onActionRequested: root.settingsRequested()
                Behavior on opacity {
                    NumberAnimation { duration: MeoMotion.stateChange; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
