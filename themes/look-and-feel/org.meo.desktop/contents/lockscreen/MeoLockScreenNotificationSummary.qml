/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Read-only lock-screen projection of Plasma NotificationManager. It never
    exposes actions, reply fields, URLs, images, job controls, or history.
*/

import QtQuick

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

    implicitWidth: notificationSummary.implicitWidth
    implicitHeight: notificationSummary.implicitHeight
    visible: notificationSummary.visible

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

    MeoPrivacyNotificationSummary {
        id: notificationSummary
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(360 * MeoTheme.globalScale, root.width)
        privacyLevel: root.effectivePrivacyLevel
        notificationCount: root.notificationCount
        applicationName: root.applicationName
        summary: root.summary
        body: root.body
    }
}
