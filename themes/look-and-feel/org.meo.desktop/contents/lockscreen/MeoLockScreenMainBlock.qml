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

import MeoUI 1.0

MeoLockScreenSessionManagement {
    id: sessionManager

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    // The outer KScreenLocker adapter toggles this only for the coordinator's
    // active secure surface. It changes presentation, never credential state.
    property bool activeAuthenticationSurface: lockScreenUiVisible
    property bool embeddedDashboard: false
    property bool authenticationFailed: false
    property string nonInteractiveError: ""
    property bool showMediaControls: false
    property bool showAlbumArtwork: false
    // Supplied by the KScreenLocker theme root from its existing, local user
    // image property. This is presentation-only and never participates in
    // authentication or account selection.
    property url avatarSource: ""
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
    property int visibleBoundary: mapFromItem(passwordBox.unlockButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(passwordBox.unlockButton, 0, 0).y
                    + passwordBox.unlockButton.height + Kirigami.Units.smallSpacing

    signal passwordResult(string password)

    function startLogin() {
        // Deliberately pass the string straight to the owning LockScreen UI;
        // this QML item never stores a second credential copy.
        // Match the upstream TextField-focus workaround (QTBUG-55460): move
        // focus to the real submit button before the authenticator can close
        // the locker window.
        passwordBox.unlockButton.forceActiveFocus()
        passwordResult(passwordBox.text)
    }

    function showAuthenticationFailure() {
        authenticationSurface.triggerFailure()
    }

    onUserSelected: {
        passwordBox.forceActiveFocus(Qt.TabFocusReason)
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
        Layout.preferredWidth: sessionManager.standaloneCenterWidth
        Layout.maximumWidth: sessionManager.standaloneCenterWidth
        active: sessionManager.activeAuthenticationSurface
        embedded: sessionManager.embeddedDashboard
        centerScale: sessionManager.centerWidthScale
        failed: sessionManager.authenticationFailed || sessionManager.nonInteractiveError !== ""
        avatarSource: sessionManager.avatarSource
        title: i18ndc("plasma_shell_org.kde.plasma.desktop", "@title", "Welcome back")
        supportingText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info", "Unlock your Meo session")
        statusText: sessionManager.authenticationFailed || sessionManager.nonInteractiveError !== ""
                    ? "" : sessionManager.secondaryAuthenticatorText
        errorText: sessionManager.authenticationFailed
                   ? sessionManager.notificationMessage
                   : sessionManager.nonInteractiveError

        MeoLockScreenPasswordField {
            id: passwordBox
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: false
            Layout.preferredWidth: implicitWidth
            Layout.maximumWidth: authenticationSurface.width * 0.8
            placeholderText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
            accessibleLabel: placeholderText
            fingerprintAvailable: sessionManager.fingerprintAvailable
            smartcardAvailable: sessionManager.smartcardAvailable
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
                              | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            text: PasswordSync.password
            focus: true
            enabled: !authenticator.graceLocked
            onUnlockRequested: {
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

    }

}
