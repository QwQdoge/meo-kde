/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only lock-screen projection of Plasma NotificationManager. It reuses
    KDE's own application grouping model and deliberately exposes no actions,
    replies, URLs, job controls, or notification mutation.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

import MeoUI 1.0

Item {
    id: root

    // hidden | count | app-name | full-content. The enclosing Loader never
    // instantiates this item for hidden, so no notification model is created.
    property string privacyLevel: "count"
    readonly property string effectivePrivacyLevel: privacyLevel === "count"
                                                  || privacyLevel === "app-name"
                                                  || privacyLevel === "full-content"
                                                ? privacyLevel : "count"
    readonly property int notificationCount: Math.max(0, notificationModel.activeNotificationsCount)

    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: 320 * MeoTheme.globalScale
    visible: effectivePrivacyLevel !== "hidden"
    clip: true

    function plainText(value) {
        return String(value || "").slice(0, 4096)
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
                .slice(0, 512)
                .trim()
    }

    NotificationManager.Notifications {
        id: notificationModel
        limit: 50
        showNotifications: true
        showJobs: false
        showExpired: false
        showDismissed: false
        sortMode: NotificationManager.Notifications.SortByDate

        // Do not reimplement Caelestia's grouping in QML. Plasma already owns
        // a tested application-grouping proxy with writable expansion state.
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        expandUnread: false

        // KScreenLocker owns this QQuickWindow and its secure surface.
        window: org_kde_plasma_screenlocker_greeter_view
    }

    Rectangle {
        anchors.fill: parent
        radius: MeoTheme.shapeMedium
        color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                       MeoTheme.surfaceContainer.b, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MeoTheme.space16
            spacing: MeoTheme.space10

            MeoText {
                Layout.fillWidth: true
                text: root.notificationCount > 0
                      ? (root.notificationCount === 1
                         ? qsTr("1 notification")
                         : qsTr("%1 notifications").arg(root.notificationCount))
                      : qsTr("Notifications")
                font.family: MeoTheme.fontFamilyMonospace
                typeRole: "label"
                typeSize: "small"
                emphasized: true
                color: MeoTheme.outline
                elide: Text.ElideRight
            }

            MeoPrivacyNotificationSummary {
                Layout.fillWidth: true
                visible: root.effectivePrivacyLevel === "count" && root.notificationCount > 0
                privacyLevel: "count"
                notificationCount: root.notificationCount
            }

            ListView {
                id: notificationList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.effectivePrivacyLevel !== "count" && root.notificationCount > 0
                clip: true
                spacing: MeoTheme.space8
                model: notificationModel

                delegate: Item {
                    id: delegateRoot

                    required property int index
                    required property var model
                    required property bool isGroup
                    required property bool isInGroup
                    required property bool isGroupExpanded
                    required property int groupChildrenCount
                    required property string applicationName
                    required property string applicationIconName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property date created
                    required property date updated

                    readonly property bool contentAllowed: root.effectivePrivacyLevel === "full-content"
                    readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
                    readonly property date effectiveTime: isNaN(updated.getTime()) ? created : updated
                    readonly property bool showRow: !isInGroup || contentAllowed
                    width: ListView.view.width
                    height: showRow ? rowSurface.implicitHeight : 0
                    visible: showRow
                    opacity: showRow ? 1 : 0

                    Rectangle {
                        id: rowSurface
                        width: parent.width
                        implicitHeight: rowContent.implicitHeight + MeoTheme.space12 * 2
                        radius: delegateRoot.isGroup ? MeoTheme.shapeLarge : MeoTheme.shapeMedium
                        color: delegateRoot.critical && delegateRoot.isGroup
                               ? MeoTheme.secondaryContainer
                               : MeoTheme.surfaceContainerHigh

                        RowLayout {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: MeoTheme.space12
                            spacing: MeoTheme.space10

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 42 * MeoTheme.globalScale
                                implicitHeight: implicitWidth
                                radius: implicitWidth / 2
                                color: delegateRoot.critical
                                       ? MeoTheme.error
                                       : delegateRoot.urgency === NotificationManager.Notifications.LowUrgency
                                         ? MeoTheme.surfaceContainerHighest
                                         : MeoTheme.secondaryContainer

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 25 * MeoTheme.globalScale
                                    height: width
                                    source: delegateRoot.applicationIconName
                                    visible: delegateRoot.applicationIconName !== ""
                                }

                                MeoIcon {
                                    anchors.centerIn: parent
                                    visible: delegateRoot.applicationIconName === ""
                                    icon: delegateRoot.critical ? "priority_high" : "notifications"
                                    size: 24 * MeoTheme.globalScale
                                    color: delegateRoot.critical
                                           ? MeoTheme.contentOnError
                                           : MeoTheme.contentOnSecondaryContainer
                                    fill: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: MeoTheme.space4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: MeoTheme.space8

                                    MeoText {
                                        Layout.fillWidth: true
                                        text: root.plainText(delegateRoot.applicationName)
                                        typeRole: "body"
                                        typeSize: "small"
                                        color: MeoTheme.contentOnSurfaceVariant
                                        elide: Text.ElideRight
                                    }

                                    MeoText {
                                        visible: !isNaN(delegateRoot.effectiveTime.getTime())
                                        text: Qt.formatTime(delegateRoot.effectiveTime, "HH:mm")
                                        typeRole: "body"
                                        typeSize: "small"
                                        color: MeoTheme.outline
                                    }

                                    Rectangle {
                                        visible: delegateRoot.isGroup
                                                 && delegateRoot.groupChildrenCount > 0
                                        implicitHeight: 28 * MeoTheme.globalScale
                                        implicitWidth: groupBadgeRow.implicitWidth + MeoTheme.space12
                                        radius: implicitHeight / 2
                                        color: delegateRoot.critical
                                               ? MeoTheme.error
                                               : MeoTheme.surfaceContainerHighest

                                        RowLayout {
                                            id: groupBadgeRow
                                            anchors.centerIn: parent
                                            spacing: MeoTheme.space2

                                            MeoText {
                                                text: String(delegateRoot.groupChildrenCount)
                                                typeRole: "label"
                                                typeSize: "small"
                                                emphasized: true
                                                color: delegateRoot.critical
                                                       ? MeoTheme.contentOnError
                                                       : MeoTheme.contentOnSurface
                                            }

                                            MeoIcon {
                                                visible: delegateRoot.contentAllowed
                                                icon: delegateRoot.isGroupExpanded
                                                      ? "expand_less" : "expand_more"
                                                size: 18 * MeoTheme.globalScale
                                                color: delegateRoot.critical
                                                       ? MeoTheme.contentOnError
                                                       : MeoTheme.contentOnSurface
                                            }
                                        }
                                    }
                                }

                                MeoText {
                                    Layout.fillWidth: true
                                    visible: delegateRoot.contentAllowed
                                             && !delegateRoot.isGroup
                                             && text !== ""
                                    text: root.plainText(delegateRoot.summary)
                                    typeRole: "body"
                                    typeSize: "small"
                                    emphasized: true
                                    color: MeoTheme.contentOnSurface
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }

                                MeoText {
                                    Layout.fillWidth: true
                                    visible: delegateRoot.contentAllowed
                                             && !delegateRoot.isGroup
                                             && text !== ""
                                    text: root.plainText(delegateRoot.body)
                                    typeRole: "body"
                                    typeSize: "small"
                                    color: MeoTheme.contentOnSurfaceVariant
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        TapHandler {
                            enabled: delegateRoot.isGroup
                                     && delegateRoot.contentAllowed
                                     && delegateRoot.groupChildrenCount > 0
                            onTapped: delegateRoot.model.isGroupExpanded = !delegateRoot.isGroupExpanded
                        }
                    }

                    Behavior on height {
                        enabled: !MeoTheme.reduceMotion
                        NumberAnimation {
                            duration: MeoTheme.motionDurationShort4
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: MeoTheme.motionDurationShort4
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.7
                            to: 1
                            duration: MeoTheme.motionDurationShort4
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: MeoTheme.motionDurationShort4
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.notificationCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: MeoTheme.space8

                    MeoIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "notifications_none"
                        size: 38 * MeoTheme.globalScale
                        color: MeoTheme.outlineVariant
                    }
                    MeoText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No notifications")
                        font.family: MeoTheme.fontFamilyMonospace
                        typeRole: "label"
                        typeSize: "medium"
                        color: MeoTheme.outlineVariant
                    }
                }
            }
        }
    }
}
