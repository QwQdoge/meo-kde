/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    This root preserves the magic KScreenLocker contract from Plasma 6.7.
    Authentication, input routing, and fallback ownership remain upstream.
*/

import QtQuick

Item {
    id: root

    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // KScreenLocker reads this property to show lock OSD content.
    property bool viewVisible: false

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    MeoLockScreenUi {
        anchors.fill: parent
    }
}
