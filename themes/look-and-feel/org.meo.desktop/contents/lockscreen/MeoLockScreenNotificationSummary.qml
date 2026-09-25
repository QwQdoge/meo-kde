/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only lock-screen projection of Plasma NotificationManager. It never
    exposes actions, reply fields, URLs, images, job controls, or history.
*/

import QtQuick
import QtQuick.Layouts

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
    readonly property var latestIndex: notificationModel.count > 0
                                      ? notificationModel.index(0, 0) : null
    readonly property string applicationName: effectivePrivacyLevel === "count"
                                              ? "" : plainText(roleValue(NotificationManager.Notifications.ApplicationNameRole))
    readonly property string summary: effectivePrivacyLevel === "full-content"
                                     ? plainText(roleValue(NotificationManager.Notifications.SummaryRole)) : ""
    readonly property string body: effectivePrivacyLevel === "full-content"
                                  ? plainText(roleValue(NotificationManager.Notifications.BodyRole)) : ""

    implicitWidth: 360 * MeoTheme.globalScale
    implicitHeight: notificationSurface.implicitHeight
    visible: effectivePrivacyLevel !== "hidden"

    function roleValue(role) {
        if (!latestIndex || !notificationModel.data)
            return ""
        const value = notificationModel.data(latestIndex, role)
        return value === undefined || value === null ? "" : value
    }

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
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        // KScreenLocker owns this QQuickWindow and its secure surface.
        window: org_kde_plasma_screenlocker_greeter_view
    }

    Rectangle {
        id: notificationSurface
        width: root.width
        implicitHeight: notificationLayout.implicitHeight + MeoTheme.space16 * 2
        radius: MeoTheme.shapeExtraLarge
        color: Qt.rgba(MeoTheme.surfaceContainer.r, MeoTheme.surfaceContainer.g,
                       MeoTheme.surfaceContainer.b, 0.92)

        ColumnLayout {
            id: notificationLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
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
                visible: root.notificationCount > 0
                privacyLevel: root.effectivePrivacyLevel
                notificationCount: root.notificationCount
                applicationName: root.applicationName
                summary: root.summary
                body: root.body
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 86 * MeoTheme.globalScale
                visible: root.notificationCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: MeoTheme.space6

                    MeoIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "notifications_none"
                        size: 32 * MeoTheme.globalScale
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
