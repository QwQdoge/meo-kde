/* SPDX-FileCopyrightText: 2026 MeoArch contributors
   SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import QtQuick.Layouts

import org.kde.breeze.components

import MeoUI 1.0

SessionManagementScreen {
    id: unlockScreen

    focus: true

    MeoAuthenticationSurface {
        Layout.fillWidth: true
        active: true
        title: i18ndc("plasma_shell_org.kde.plasma.desktop", "@title", "Unlock")
        supportingText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info", "Your session is ready")

        MeoButton {
            id: unlockButton
            Layout.fillWidth: true
            text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button no-password unlock", "Unlock")
            icon.name: "lock_open"
            size: "m"
            focus: true
            onClicked: Qt.quit()
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()
        }
    }

    Component.onCompleted: forceActiveFocus()
}
