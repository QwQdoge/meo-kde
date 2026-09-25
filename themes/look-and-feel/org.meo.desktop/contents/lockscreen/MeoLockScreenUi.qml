/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Derived from Plasma 6.7.5's lockscreen presentation flow. Keep the
    authenticator, PasswordSync, SessionManagement, virtual-keyboard, and
    keyboard-layout contracts upstream-compatible when synchronizing.
*/

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions
import org.kde.breeze.components

import MeoUI 1.0
import Meo.KScreenLocker 1.0
import Meo.System 1.0

Item {
    id: lockScreenUi

    // KScreenLocker creates one secure QQuickWindow for every physical screen
    // and shares its QML engine between them. The bridge records only which
    // existing window presents the panel; PasswordSync and authenticator keep
    // owning the one credential/authentication state.
    readonly property int screenCoordinatorRevision: ScreenCoordinator.revision
    readonly property bool activeAuthenticationSurface: {
        screenCoordinatorRevision // make the binding react to topology changes
        return ScreenCoordinator.isSurfaceActive(org_kde_plasma_screenlocker_greeter_view)
    }
    readonly property bool authenticationUiVisible: activeAuthenticationSurface
                                                        && ScreenCoordinator.authenticationRequested
    readonly property bool hasMultipleSecuritySurfaces: ScreenCoordinator.registeredSurfaceCount > 1
    readonly property int screenMigrationDuration: MeoTheme.reduceMotion
                                                  ? MeoTheme.motionDurationShort2
                                                  : MeoTheme.motionDurationMedium1
    readonly property bool showMediaControls: configBoolean("showMediaControls", false)
    readonly property bool showAlbumArtwork: configBoolean("showAlbumArtwork", false)
    readonly property bool showAudioControls: configBoolean("showAudioControls", false)
    readonly property bool showWeather: configBoolean("showWeather", false)
    readonly property bool showWeatherLocation: configBoolean("showWeatherLocation", false)
    readonly property bool showPerformance: configBoolean("showPerformance", true)
    readonly property bool showSystemSummary: configBoolean("showSystemSummary", true)
    readonly property string notificationPrivacyLevel: configNotificationPrivacy()
    readonly property real dashboardHeight: Math.min(height - MeoTheme.space32 * 2,
                                                      height * 0.70)
    readonly property real dashboardWidth: Math.min(width - MeoTheme.space32 * 2,
                                                    dashboardHeight * 16 / 9)
    readonly property real dashboardCenterScale: Math.min(1.0,
                                                          Math.max(0.58, height / 1440))
    readonly property real dashboardCenterWidth: Math.max(344 * MeoTheme.globalScale,
                                                          600 * MeoTheme.globalScale
                                                          * dashboardCenterScale)
    readonly property bool wideAmbientDashboard: dashboardWidth >= 900 * MeoTheme.globalScale
                                                 && dashboardHeight >= 500 * MeoTheme.globalScale

    // One animated scalar drives the whole ambient -> authentication
    // transition. This keeps the motion coherent like Caelestia while using
    // MeoUI's M3 Expressive curve rather than introducing a second motion
    // system.
    property real authenticationReveal: authenticationUiVisible ? 1.0 : 0.0

    Behavior on authenticationReveal {
        NumberAnimation {
            duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: authenticationUiVisible
                                ? MeoTheme.motionEasingEmphasizedDecelerate
                                : MeoTheme.motionEasingEmphasizedAccelerate
        }
    }

    Component.onCompleted: ScreenCoordinator.registerSurface(org_kde_plasma_screenlocker_greeter_view)
    Component.onDestruction: ScreenCoordinator.unregisterSurface(org_kde_plasma_screenlocker_greeter_view)

    function requestAuthenticationHere() {
        ScreenCoordinator.requestAuthenticationOn(org_kde_plasma_screenlocker_greeter_view)
    }

    function configValue(name, fallbackValue) {
        if (typeof config === "undefined" || config[name] === undefined)
            return fallbackValue
        return config[name]
    }

    function configBoolean(name, fallbackValue) {
        return Boolean(configValue(name, fallbackValue))
    }

    function configNotificationPrivacy() {
        const value = String(configValue("lockScreenNotificationVisibility", "count"))
        return value === "hidden" || value === "count" || value === "app-name"
                || value === "full-content" ? value : "count"
    }

    function focusActiveAuthentication() {
        if (!authenticationUiVisible || mainStack.depth !== 1)
            return
        mainStack.forceActiveFocus()
        mainBlock.mainPasswordBox.forceActiveFocus()
    }

    onAuthenticationUiVisibleChanged: {
        if (authenticationUiVisible) {
            authenticator.startAuthenticating()
            fadeoutTimer.restart()
            Qt.callLater(focusActiveAuthentication)
        } else {
            fadeoutTimer.stop()
        }
    }

    function handleMessage(message) {
        if (!message)
            return
        if (!root.notification)
            root.notification = message
        else if (root.notification.includes(message))
            root.notificationRepeated()
        else
            root.notification += "\n" + message
    }

    SessionManagement {
        id: sessionManagement
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement

        function onAboutToSuspend() {
            root.clearPassword()
        }
    }

    Connections {
        target: authenticator

        function onFailed(kind) {
            if (kind !== 0 || !lockScreenUi.activeAuthenticationSurface)
                return
            lockScreenUi.handleMessage(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed"))
            mainBlock.authenticationFailed = true
            mainBlock.showAuthenticationFailure()
            graceLockTimer.restart()
            notificationRemoveTimer.restart()
        }

        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit()
            } else {
                mainStack.replace(null, Qt.resolvedUrl("MeoNoPasswordUnlock.qml"),
                                  { userListModel: users }, StackView.Immediate)
                mainStack.forceActiveFocus()
            }
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage)
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage)
        }

        function onPromptChanged(message) {
            lockScreenUi.handleMessage(authenticator.prompt)
        }

        function onPromptForSecretChanged(message) {
            if (!lockScreenUi.activeAuthenticationSurface)
                return
            mainBlock.showPassword = false
            mainBlock.mainPasswordBox.forceActiveFocus()
        }
    }

    Connections {
        target: ScreenCoordinator

        function onFocusRequested(surface) {
            if (surface === org_kde_plasma_screenlocker_greeter_view)
                Qt.callLater(lockScreenUi.focusActiveAuthentication)
        }
    }

    MouseArea {
        id: lockScreenRoot

        readonly property bool uiVisible: lockScreenUi.authenticationUiVisible
        // An ambient lock screen must not begin fingerprint/smartcard (or a
        // future upstream face method) because of an incidental pointer tap.
        // 72dp is the explicit touch-intent threshold from the public
        // session-entry contract. Keyboard input remains its accessible
        // equivalent and continues to use KScreenLocker's authenticator.
        readonly property real upwardSwipeThreshold: 72 * MeoTheme.globalScale
        property real gestureStartY: 0
        property bool authenticationSwipeRecognized: false
        property bool blockUI: lockScreenUi.authenticationUiVisible && containsMouse
                               && (mainStack.depth > 1
                                   || mainBlock.mainPasswordBox.text.length > 0
                                   || inputPanel.keyboardActive)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible || lockScreenUi.hasMultipleSecuritySurfaces ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: mouse => {
            gestureStartY = mouse.y
            authenticationSwipeRecognized = uiVisible
        }
        onPositionChanged: mouse => {
            if (uiVisible || authenticationSwipeRecognized)
                return
            if (gestureStartY - mouse.y < upwardSwipeThreshold)
                return
            authenticationSwipeRecognized = true
            lockScreenUi.requestAuthenticationHere()
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false
                lockScreenUi.requestAuthenticationHere()
            } else {
                fadeoutTimer.restart()
            }
        }
        Keys.onEscapePressed: {
            // Match the upstream escape behavior: hide the password prompt
            // and request that KScreenLocker clears its single password model.
            if (uiVisible) {
                ScreenCoordinator.dismissAuthentication()
                if (inputPanel.keyboardActive)
                    inputPanel.showHide()
                root.clearPassword()
            }
        }
        Keys.onPressed: event => {
            lockScreenUi.requestAuthenticationHere()
            event.accepted = false
        }

        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.showPassword = false
                    ScreenCoordinator.dismissAuthentication()
                }
            }
        }

        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        Timer {
            id: graceLockTimer
            interval: 3000
            onTriggered: {
                root.clearPassword()
                mainBlock.authenticationFailed = false
                mainBlock.nonInteractiveError = ""
                authenticator.startAuthenticating()
            }
        }

        // WallpaperFader is still the proven KDE wallpaper blur/contrast
        // implementation, but its upstream state machine also writes directly
        // to clock/mainStack opacity with InOutQuad. Feed those writes into
        // inert proxies so the visible Meo surfaces can use one coherent M3
        // Expressive progress value instead of two competing animations.
        Item {
            id: wallpaperMainStackProxy
            visible: false
        }
        Item {
            id: wallpaperClockProxy
            visible: false
            property Item shadow: wallpaperClockProxyShadow
        }
        Item {
            id: wallpaperClockProxyShadow
            visible: false
        }
        Item {
            id: wallpaperFooterProxy
            visible: false
        }

        WallpaperFader {
            anchors.fill: parent
            // Caelestia keeps the wallpaper softly blurred behind its large
            // lock surface. Keep KDE's proven blur implementation, but proxy
            // every opacity target so it cannot override Meo's motion.
            state: lockScreenUi.activeAuthenticationSurface ? "on" : "off"
            source: wallpaper
            mainStack: wallpaperMainStackProxy
            footer: wallpaperFooterProxy
            clock: wallpaperClockProxy
            alwaysShowClock: true
        }

        // DMS-style layered scrim: nearly invisible in the ambient state, then
        // a lower-screen surface/primary gradient grows with authentication.
        // It is deliberately just a visual layer inside KScreenLocker's secure
        // window; it never captures credentials or session actions.
        Rectangle {
            id: expressiveScrim
            anchors.fill: parent
            opacity: 0.18 + lockScreenUi.authenticationReveal * 0.82

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    position: 0.0
                    color: Qt.rgba(MeoTheme.surface.r, MeoTheme.surface.g,
                                   MeoTheme.surface.b,
                                   0.02 + lockScreenUi.authenticationReveal * 0.08)
                }
                GradientStop {
                    position: 0.48
                    color: Qt.rgba(MeoTheme.surface.r, MeoTheme.surface.g,
                                   MeoTheme.surface.b,
                                   0.08 + lockScreenUi.authenticationReveal * 0.20)
                }
                GradientStop {
                    position: 0.78
                    color: Qt.rgba(MeoTheme.primaryContainer.r,
                                   MeoTheme.primaryContainer.g,
                                   MeoTheme.primaryContainer.b,
                                   0.08 + lockScreenUi.authenticationReveal * 0.26)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(MeoTheme.surface.r, MeoTheme.surface.g,
                                   MeoTheme.surface.b,
                                   0.26 + lockScreenUi.authenticationReveal * 0.52)
                }
            }
        }

        // Caelestia's defining lock-screen silhouette is one large 16:9,
        // 70%-screen-height surface over the blurred wallpaper. Meo keeps that
        // composition but uses its own HCT palette, spacing and motion tokens.
        Rectangle {
            id: wideDashboardSurface
            anchors.centerIn: parent
            width: lockScreenUi.dashboardWidth
            height: lockScreenUi.dashboardHeight
            visible: lockScreenUi.activeAuthenticationSurface
                     && lockScreenUi.wideAmbientDashboard
            radius: MeoTheme.shapeExtraLarge * 1.5
            color: Qt.rgba(MeoTheme.surface.r, MeoTheme.surface.g,
                           MeoTheme.surface.b, 0.94)
            border.width: Math.max(1, MeoTheme.globalScale)
            border.color: Qt.rgba(MeoTheme.outlineVariant.r,
                                  MeoTheme.outlineVariant.g,
                                  MeoTheme.outlineVariant.b, 0.34)
            scale: MeoTheme.reduceMotion
                   ? 1.0
                   : 0.985 + lockScreenUi.authenticationReveal * 0.015

            layer.enabled: visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.78
                shadowOpacity: 0.34
                shadowVerticalOffset: 10 * MeoTheme.globalScale
                shadowColor: MeoTheme.shadow
            }

            Behavior on scale {
                enabled: !MeoTheme.reduceMotion
                NumberAnimation {
                    duration: MeoTheme.motionDurationMedium1
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                }
            }
        }

        // WallpaperFader owns the upstream `clock.shadow` visual contract.
        // Keep that adapter local to the KScreenLocker theme so MeoUI's clock
        // stays backend-agnostic for other session-entry consumers.
        Item {
            id: ambientClockFrame
            property Item shadow: ambientClockShadow
            visible: opacity > 0.001
            opacity: 1.0 - lockScreenUi.authenticationReveal
            scale: MeoTheme.reduceMotion ? 1.0 : 1.0 - lockScreenUi.authenticationReveal * 0.055
            anchors.horizontalCenter: parent.horizontalCenter
            width: ambientClock.implicitWidth
            height: ambientClock.implicitHeight
            y: lockScreenUi.wideAmbientDashboard
               ? wideDashboardSurface.y + MeoTheme.space32
                 - lockScreenUi.authenticationReveal * 20 * MeoTheme.globalScale
               : Math.max(MeoTheme.space32,
                          parent.height * 0.22 - height / 2
                          - lockScreenUi.authenticationReveal * 28 * MeoTheme.globalScale)

            Item {
                id: ambientClockShadow
                visible: false
            }

            // Direct visual port of the standalone lock clock: split dynamic
            // primary/secondary time glyphs, while KScreenLocker continues to
            // own the secure window and ambient-state lifecycle.
            MeoLockScreenClock {
                id: ambientClock
                anchors.centerIn: parent
            }
        }

        // Ambient information follows Caelestia's spatial hierarchy on wide
        // screens: weather/system/media on the left, identity in the centre,
        // aggregate resources/notifications on the right. On compact screens
        // it collapses to the lighter DMS-style vertical status stack.
        Loader {
            id: wideAmbientDashboard
            anchors.fill: wideDashboardSurface
            anchors.margins: MeoTheme.space24
            active: lockScreenUi.activeAuthenticationSurface
                    && lockScreenUi.wideAmbientDashboard
            visible: active && status === Loader.Ready
            opacity: 1.0 - lockScreenUi.authenticationReveal * 0.08
            enabled: active
            transform: Translate {
                y: -lockScreenUi.authenticationReveal * 6 * MeoTheme.globalScale
            }

            sourceComponent: RowLayout {
                anchors.fill: parent
                spacing: MeoTheme.space32

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 238 * MeoTheme.globalScale
                    Layout.fillHeight: true
                    spacing: MeoTheme.space12

                    MeoLockScreenWeatherCard {
                        Layout.fillWidth: true
                        visible: lockScreenUi.showWeather && Weather.available
                        showLocation: lockScreenUi.showWeatherLocation
                    }

                    MeoLockScreenSystemSummary {
                        Layout.fillWidth: true
                        visible: lockScreenUi.showSystemSummary
                    }

                    // Caelestia places media at the bottom of the left rail.
                    Item { Layout.fillHeight: true }

                    MediaControls {
                        Layout.fillWidth: true
                        visible: lockScreenUi.showMediaControls || lockScreenUi.showAudioControls
                        showMedia: lockScreenUi.showMediaControls
                        showArtwork: lockScreenUi.showAlbumArtwork
                        showVolume: lockScreenUi.showAudioControls
                    }
                }

                // Keep the same 600dp-at-1440p centre scale Caelestia uses.
                Item {
                    Layout.preferredWidth: lockScreenUi.dashboardCenterWidth
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 238 * MeoTheme.globalScale
                    Layout.fillHeight: true
                    spacing: MeoTheme.space12

                    MeoLockScreenPerformanceSummary {
                        Layout.fillWidth: true
                        visible: lockScreenUi.showPerformance
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: lockScreenUi.notificationPrivacyLevel !== "hidden"
                        visible: status === Loader.Ready
                        source: "MeoLockScreenNotificationSummary.qml"
                        onLoaded: {
                            item.privacyLevel = lockScreenUi.notificationPrivacyLevel
                            item.width = width
                        }
                        onWidthChanged: if (item) item.width = width
                    }
                }
            }
        }

        Loader {
            id: compactAmbientDashboard
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: ambientClockFrame.bottom
                topMargin: MeoTheme.space16
            }
            width: Math.min(parent.width - 2 * MeoTheme.space24,
                            400 * MeoTheme.globalScale)
            active: lockScreenUi.activeAuthenticationSurface
                    && !lockScreenRoot.uiVisible
                    && !lockScreenUi.wideAmbientDashboard
            visible: active && status === Loader.Ready
            opacity: 1.0 - lockScreenUi.authenticationReveal
            enabled: active
            transform: Translate {
                y: -lockScreenUi.authenticationReveal * 18 * MeoTheme.globalScale
            }

            sourceComponent: ColumnLayout {
                width: compactAmbientDashboard.width
                spacing: MeoTheme.space12

                MeoWeatherStatus {
                    Layout.alignment: Qt.AlignHCenter
                    available: lockScreenUi.showWeather && Weather.available
                    stale: Weather.stale
                    showLocation: lockScreenUi.showWeatherLocation
                    location: Weather.location
                    temperatureText: Weather.temperatureText
                    condition: Weather.condition
                    iconName: Weather.iconName
                }

                MediaControls {
                    Layout.fillWidth: true
                    visible: lockScreenUi.showMediaControls || lockScreenUi.showAudioControls
                    showMedia: lockScreenUi.showMediaControls
                    showArtwork: lockScreenUi.showAlbumArtwork
                    showVolume: lockScreenUi.showAudioControls
                }

                Loader {
                    Layout.fillWidth: true
                    active: lockScreenUi.notificationPrivacyLevel !== "hidden"
                    visible: status === Loader.Ready
                    source: "MeoLockScreenNotificationSummary.qml"
                    onLoaded: {
                        item.privacyLevel = lockScreenUi.notificationPrivacyLevel
                        item.width = width
                    }
                    onWidthChanged: if (item) item.width = width
                }
            }
        }

        // Non-active screens still remain full KScreenLocker surfaces. This
        // text deliberately exposes no account, media, notification, or
        // credential state. An intentional upward swipe requests that existing
        // surface as the authentication host.
        MeoText {
            id: inactiveAuthenticationHint
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: ambientClockFrame.bottom
                topMargin: MeoTheme.space16
            }
            visible: root.viewVisible && lockScreenUi.hasMultipleSecuritySurfaces
                     && !lockScreenUi.activeAuthenticationSurface
            opacity: visible ? 1 : 0
            text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip",
                         "Swipe up to unlock on this display")
            typeRole: "body"
            typeSize: "medium"
            color: MeoTheme.contentOnSurfaceVariant
            Accessible.role: Accessible.StaticText
            Accessible.name: text

            Behavior on opacity {
                NumberAnimation {
                    duration: lockScreenUi.screenMigrationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
                }
            }
        }

        ListModel {
            id: users

            Component.onCompleted: {
                users.append({
                    name: kscreenlocker_userName,
                    realName: kscreenlocker_userName,
                    icon: kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                          : ""
                })
            }
        }

        StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
            }
            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3
            focus: lockScreenUi.authenticationUiVisible
            enabled: lockScreenUi.authenticationUiVisible
            opacity: lockScreenUi.authenticationReveal
            visible: opacity > 0.001
            y: (1.0 - lockScreenUi.authenticationReveal) * 44 * MeoTheme.globalScale
            scale: MeoTheme.reduceMotion
                   ? 1.0
                   : 0.94 + lockScreenUi.authenticationReveal * 0.06
            transformOrigin: Item.Center

            // The secure surface stays owned by KScreenLocker. Only its
            // presentation follows a Caelestia-style scale/translate reveal,
            // synchronized by the single M3 Expressive progress value above.
            initialItem: MeoLockScreenMainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenUi.authenticationUiVisible
                centerWidthScale: lockScreenUi.wideAmbientDashboard
                                  ? lockScreenUi.dashboardCenterScale : 1.0
                embeddedDashboard: lockScreenUi.wideAmbientDashboard
                showMediaControls: lockScreenUi.showMediaControls
                showAlbumArtwork: lockScreenUi.showAlbumArtwork
                avatarSource: kscreenlocker_userImage !== ""
                              ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                              : ""
                showUserList: lockScreenUi.authenticationUiVisible && userList.y + mainStack.y > 0
                enabled: !graceLockTimer.running
                userListModel: users

                StackView.onStatusChanged: {
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear()
                        mainPasswordBox.focus = true
                        root.notification = ""
                        authenticationFailed = false
                        nonInteractiveError = ""
                    }
                }

                notificationMessage: {
                    if (!lockScreenRoot.uiVisible)
                        return ""
                    const messages = []
                    if (capsLockState.locked)
                        messages.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"))
                    if (root.notification)
                        messages.push(root.notification)
                    return messages.join(" • ")
                }

                onPasswordResult: password => {
                    authenticationFailed = false
                    nonInteractiveError = ""
                    authenticator.respond(password)
                }

                // Presentation is MeoUI; every capability and action still
                // comes directly from Plasma's SessionManagement.
                actionItems: [
                    MeoButton {
                        type: "text"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Sleep")
                        icon.name: "system-suspend"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.suspend()
                        }
                        visible: sessionManagement.canSuspend
                    },
                    MeoButton {
                        type: "text"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Hibernate")
                        icon.name: "system-suspend-hibernate"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.hibernate()
                        }
                        visible: sessionManagement.canHibernate
                    },
                    MeoButton {
                        type: "text"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Switch User")
                        icon.name: "system-switch-user"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.switchUser()
                        }
                        visible: sessionManagement.canSwitchUser
                    },
                    MeoButton {
                        type: "text"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Restart")
                        icon.name: "system-reboot"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.requestReboot()
                        }
                        visible: sessionManagement.canReboot
                    },
                    MeoButton {
                        type: "text"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Shut Down")
                        icon.name: "system-shutdown"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.requestShutdown()
                        }
                        visible: sessionManagement.canShutdown
                    }
                ]
            }
        }

        VirtualKeyboardLoader {
            id: inputPanel
            z: 1
            screenRoot: lockScreenRoot
            mainStack: mainStack
            mainBlock: mainBlock
            passwordField: mainBlock.mainPasswordBox
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }

        RowLayout {
            id: footer
            opacity: lockScreenRoot.uiVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationShort4
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingStandard
                }
            }

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Kirigami.Units.smallSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            // This keeps the upstream virtual-keyboard controller while using
            // the shared MeoUI control, including its 48dp target and state
            // feedback. It owns no authentication state.
            MeoButton {
                id: virtualKeyboardButton
                type: "text"
                size: "s"
                focusPolicy: Qt.TabFocus
                text: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to show/hide virtual keyboard", "Virtual Keyboard")
                icon.name: inputPanel.keyboardActive ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                onClicked: {
                    mainBlock.mainPasswordBox.forceActiveFocus()
                    inputPanel.showHide()
                }
                visible: inputPanel.status === Loader.Ready
                Layout.fillHeight: true
            }

            // KeyboardLayoutSwitcher is still KDE's controller; this button
            // only presents that existing state through MeoUI.
            MeoButton {
                id: keyboardButton
                type: "text"
                size: "s"
                focusPolicy: Qt.TabFocus
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to change keyboard layout", "Switch layout")
                icon.name: "input-keyboard"

                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }

                text: keyboardLayoutSwitcher.layoutNames.longName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
                Layout.fillHeight: true
            }

            Item { Layout.fillWidth: true }
            Battery { }
        }
    }
}
