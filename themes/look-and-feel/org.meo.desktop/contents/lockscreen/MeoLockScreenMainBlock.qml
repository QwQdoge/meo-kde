/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Presentation adapter over Plasma's SessionManagementScreen. This file does
    not retain credentials: PasswordSync remains KScreenLocker's only model.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.breeze.components

import MeoUI 1.0

SessionManagementScreen {
    id: sessionManager

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    // The outer KScreenLocker adapter toggles this only for the coordinator's
    // active secure surface. It changes presentation, never credential state.
    property bool activeAuthenticationSurface: lockScreenUiVisible
    property bool authenticationFailed: false
    property string nonInteractiveError: ""
    property bool showMediaControls: false
    property bool showAlbumArtwork: false
    property alias showPassword: passwordBox.passwordVisible

    readonly property bool fingerprintAvailable: authenticator.authenticatorTypes
                                               & ScreenLocker.Authenticator.Fingerprint
    readonly property bool smartcardAvailable: authenticator.authenticatorTypes
                                             & ScreenLocker.Authenticator.Smartcard
    readonly property string secondaryAuthenticatorText: fingerprintAvailable
                                                       ? i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "Or scan your fingerprint on the reader")
                                                       : smartcardAvailable
                                                         ? i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "Or scan your smartcard")
                                                         : ""

    // The y position that must stay visible while the upstream virtual
    // keyboard is active.
    property int visibleBoundary: mapFromItem(unlockButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(unlockButton, 0, 0).y
                    + unlockButton.height + Kirigami.Units.smallSpacing

    signal passwordResult(string password)

    function startLogin() {
        // Deliberately pass the string straight to the owning LockScreen UI;
        // this QML item never stores a second credential copy.
        unlockButton.forceActiveFocus()
        passwordResult(passwordBox.text)
    }

    function showAuthenticationFailure() {
        authenticationSurface.triggerFailure()
    }

    onUserSelected: {
        const nextControl = passwordBox.visible ? passwordBox : unlockButton
        nextControl.forceActiveFocus(Qt.TabFocusReason)
    }

    property QtObject nonInteractiveAuthenticatorConnection: Connections {
        target: authenticator

        function onNoninteractiveError(kind, authenticator) {
            if (kind & (ScreenLocker.Authenticator.Fingerprint
                        | ScreenLocker.Authenticator.Smartcard)) {
                sessionManager.nonInteractiveError = authenticator.errorMessage
                authenticationSurface.triggerFailure()
            }
        }
    }

    MeoLockScreenAuthCard {
        id: authenticationSurface
        Layout.fillWidth: true
        Layout.minimumWidth: 344 * MeoTheme.globalScale
        Layout.maximumWidth: 480 * MeoTheme.globalScale
        active: sessionManager.activeAuthenticationSurface
        title: i18ndc("plasma_shell_org.kde.plasma.desktop", "@title", "Welcome back")
        supportingText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info", "Unlock your Meo session")
        statusText: sessionManager.authenticationFailed || sessionManager.nonInteractiveError !== ""
                    ? "" : sessionManager.secondaryAuthenticatorText
        errorText: sessionManager.authenticationFailed
                   ? sessionManager.notificationMessage
                   : sessionManager.nonInteractiveError

        MeoTextField {
            id: passwordBox
            Layout.fillWidth: true
            label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
            placeholder: label
            isPassword: true
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
                              | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            text: PasswordSync.password
            focus: true
            enabled: !authenticator.graceLocked
            Accessible.name: label

            onAccepted: {
                if (sessionManager.lockScreenUiVisible)
                    sessionManager.startLogin()
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left && !text) {
                    sessionManager.userList.decrementCurrentIndex()
                    event.accepted = true
                }
                if (event.key === Qt.Key_Right && !text) {
                    sessionManager.userList.incrementCurrentIndex()
                    event.accepted = true
                }
            }

            Connections {
                target: root

                function onClearPassword() {
                    passwordBox.forceActiveFocus()
                    passwordBox.text = ""
                    passwordBox.text = Qt.binding(() => PasswordSync.password)
                }

                function onNotificationRepeated() {
                    sessionManager.playHighlightAnimation()
                }
            }
        }

        Binding {
            target: PasswordSync
            property: "password"
            value: passwordBox.text
        }

        MeoButton {
            id: unlockButton
            Layout.fillWidth: true
            text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button accessible only", "Unlock")
            icon.name: "lock_open"
            size: "m"
            Accessible.name: text
            onClicked: sessionManager.startLogin()
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()
        }
    }

}
