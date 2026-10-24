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
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.battery as BatteryApi
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
    // Plasma 6.8 no longer injects the greeter view as a context property;
    // the item's own Window is the per-screen KScreenLocker window.
    readonly property var greeterWindow: Window.window
    readonly property int screenCoordinatorRevision: ScreenCoordinator.revision
    readonly property bool activeAuthenticationSurface: {
        screenCoordinatorRevision // make the binding react to topology changes
        return ScreenCoordinator.isSurfaceActive(greeterWindow)
    }
    readonly property bool authenticationUiVisible: activeAuthenticationSurface
                                                        && ScreenCoordinator.authenticationRequested
    readonly property bool hasMultipleSecuritySurfaces: ScreenCoordinator.registeredSurfaceCount > 1
    readonly property int screenMigrationDuration: MeoTheme.reduceMotion
                                                  ? MeoTheme.motionDurationShort2
                                                  : MeoTheme.motionDurationMedium1
    readonly property bool showAmbientDashboard: configBoolean("showAmbientDashboard", false)
    readonly property bool showMediaControls: configBoolean("showMediaControls", false)
    readonly property bool showAlbumArtwork: configBoolean("showAlbumArtwork", false)
    readonly property bool showAudioControls: configBoolean("showAudioControls", false)
    readonly property bool showWeather: configBoolean("showWeather", false)
    readonly property bool showWeatherLocation: configBoolean("showWeatherLocation", false)
    readonly property bool showPerformance: configBoolean("showPerformance", true)
    readonly property bool showSystemSummary: configBoolean("showSystemSummary", true)
    readonly property bool showSessionControls: configBoolean("showSessionControls", true)
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
    readonly property bool wideAmbientDashboard: showAmbientDashboard && dashboardWidth >= 900 * MeoTheme.globalScale
                                                 && dashboardHeight >= 500 * MeoTheme.globalScale
    property string pendingPowerAction: ""

    // Black or white content color from the wallpaper pixels behind the clock
    // and unlock hint. The native sampler reads the lock-screen wallpaper
    // (falling back to the desktop one) once, caches it, and answers again
    // only when the wallpaper or the screen size changes. Unknown wallpaper
    // keeps the theme-derived color.
    property int wallpaperContrastRevision: 0
    readonly property var wallpaperContrast: typeof WallpaperContrast === "undefined"
                                             ? null : WallpaperContrast
    function foregroundFor(rx, ry, rw, rh) {
        wallpaperContrastRevision
        // Unknown wallpaper: white, as on the reference lock screen.
        if (!wallpaperContrast || width <= 0 || height <= 0)
            return "white"
        const dark = wallpaperContrast.prefersDarkForeground(
                    width * rx, height * ry, width * rw, height * rh,
                    width, height, false,
                    wallpaperContrast.lockScreenWallpaperPath())
        return dark ? Qt.alpha("black", 0.88) : "white"
    }
    // Clock block, date line, bottom hint and top status row are sampled
    // separately so a mixed wallpaper cannot pick one unreadable color.
    readonly property color clockForeground: foregroundFor(0.36, 0.20, 0.28, 0.48)
    readonly property color hintForeground: foregroundFor(0.36, 0.84, 0.28, 0.12)
    readonly property color topForeground: foregroundFor(0.00, 0.00, 1.00, 0.07)
    readonly property color ambientForeground: clockForeground
    Connections {
        target: lockScreenUi.wallpaperContrast
        ignoreUnknownSignals: true
        function onChanged() { lockScreenUi.wallpaperContrastRevision++ }
    }

    function confirmPower(action) {
        pendingPowerAction = action
        powerConfirmation.open()
    }

    MeoDialog {
        id: powerConfirmation
        title: lockScreenUi.pendingPowerAction === "sleep" ? qsTr("Sleep")
             : lockScreenUi.pendingPowerAction === "hibernate" ? qsTr("Hibernate")
             : lockScreenUi.pendingPowerAction === "reboot" ? qsTr("Restart")
             : qsTr("Shut down")
        message: qsTr("Confirm this power action?")
        confirmText: qsTr("Continue")
        cancelText: qsTr("Cancel")
        onConfirmed: {
            const action = lockScreenUi.pendingPowerAction
            lockScreenUi.pendingPowerAction = ""
            root.clearPassword()
            if (action === "sleep") sessionManagement.suspend()
            else if (action === "hibernate") sessionManagement.hibernate()
            else if (action === "reboot") sessionManagement.requestReboot(SessionManagement.Skip)
            else if (action === "shutdown") sessionManagement.requestShutdown(SessionManagement.Skip)
        }
        onCancelled: lockScreenUi.pendingPowerAction = ""
        onDismissed: lockScreenUi.pendingPowerAction = ""
    }

    // One animated scalar drives the whole ambient -> authentication
    // transition. This keeps the motion coherent like Caelestia while using
    // MeoUI's M3 Expressive curve rather than introducing a second motion
    // system.
    property real authenticationReveal: authenticationUiVisible ? 1.0 : 0.0
    property real dashboardEntrance: MeoTheme.reduceMotion ? 1.0 : 0.0
    readonly property real dashboardSpinProgress: Math.min(1.0, dashboardEntrance / 0.34)
    readonly property real dashboardExpandProgress: Math.max(0.0,
                                                             Math.min(1.0,
                                                                      (dashboardEntrance - 0.18) / 0.82))
    readonly property real dashboardContentEntrance: Math.max(0.0,
                                                              Math.min(1.0,
                                                                       (dashboardEntrance - 0.34) / 0.66))

    NumberAnimation on dashboardEntrance {
        running: !MeoTheme.reduceMotion
        from: 0.0
        to: 1.0
        duration: MeoTheme.motionDurationExtraLong1
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
    }

    Behavior on authenticationReveal {
        NumberAnimation {
            duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
                    easing.bezierCurve: authenticationUiVisible ? MeoTheme.motionEasingEmphasizedDecelerate : MeoTheme.motionEasingEmphasizedAccelerate
        }
    }

    // The Window attached property is null until the item is inside its
    // KScreenLocker window, so (re)register whenever it changes.
    property var registeredWindow: null
    function syncSurface() {
        if (registeredWindow === greeterWindow)
            return
        if (registeredWindow)
            ScreenCoordinator.unregisterSurface(registeredWindow)
        registeredWindow = greeterWindow
        if (registeredWindow)
            ScreenCoordinator.registerSurface(registeredWindow)
    }
    onGreeterWindowChanged: syncSurface()
    Component.onCompleted: {
        syncSurface()
        Qt.callLater(lockScreenRoot.forceActiveFocus)
    }
    Component.onDestruction: {
        if (registeredWindow)
            ScreenCoordinator.unregisterSurface(registeredWindow)
    }

    function requestAuthenticationHere() {
        ScreenCoordinator.requestAuthenticationOn(lockScreenUi.greeterWindow)
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
            Qt.callLater(lockScreenRoot.forceActiveFocus)
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
            // The backend (PAM) reported success: stop every pending
            // authenticator (password, fingerprint, smartcard) so none of them
            // times out or retries, then release the lock. An account without a
            // password succeeds without any prompt; that unlocks directly on the
            // deliberate click/key that revealed authentication, with no second
            // confirmation screen.
            authenticator.stopAuthenticating()
            Qt.quit()
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage)
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage)
        }

        function onPromptChanged() {
            lockScreenUi.handleMessage(authenticator.prompt)
        }

        function onPromptForSecretChanged() {
            if (!lockScreenUi.activeAuthenticationSurface)
                return
            mainBlock.showPassword = false
            mainBlock.mainPasswordBox.forceActiveFocus()
        }
    }

    Connections {
        target: ScreenCoordinator

        function onFocusRequested(surface) {
            if (surface === lockScreenUi.greeterWindow)
                Qt.callLater(lockScreenUi.focusActiveAuthentication)
        }
    }

    MouseArea {
        id: lockScreenRoot
        focus: !lockScreenUi.authenticationUiVisible

        readonly property bool uiVisible: lockScreenUi.authenticationUiVisible
        // The ambient lock screen starts authentication only on a deliberate
        // action: any key press, a click/tap, or an upward swipe of at least
        // 72dp (the touch-intent threshold from the public session-entry
        // contract). Pointer motion alone never starts fingerprint/smartcard
        // (or a future upstream face method).
        readonly property real upwardSwipeThreshold: 72 * MeoTheme.globalScale
        property real gestureStartY: 0
        property bool authenticationSwipeRecognized: false
        property bool blockUI: lockScreenUi.authenticationUiVisible && containsMouse
                               && (mainStack.depth > 1
                                   || mainBlock.mainPasswordBox.text.length > 0
                                   || Keyboards.KWinVirtualKeyboard.visible)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible || lockScreenUi.hasMultipleSecuritySurfaces ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: mouse => {
            gestureStartY = mouse.y
            authenticationSwipeRecognized = uiVisible
        }
        onClicked: mouse => {
            if (!uiVisible)
                lockScreenUi.requestAuthenticationHere()
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
                if (Keyboards.KWinVirtualKeyboard.visible)
                    Keyboards.KWinVirtualKeyboard.active = false
                root.clearPassword()
            }
        }
        Keys.onPressed: event => {
            if (!uiVisible) {
                // A wake-up Enter must not become an empty PAM submission.
                // Consume the ambient gesture; credentials start in the revealed field.
                lockScreenUi.requestAuthenticationHere()
                event.accepted = true
            } else {
                event.accepted = false
            }
        }

        // KScreenLocker's authenticators only start a PAM conversation when
        // startAuthenticating() finds the worker ready and not busy, and it
        // must be called again after a failure or a worker restart. Without this
        // heartbeat the first call can land before the worker is ready, no
        // prompt is ever issued and typed passwords or fingerprint touches have
        // nothing to answer. Same contract as the stock Plasma 6.8 lock screen.
        Timer {
            id: authenticationHeartbeat
            interval: 1000
            running: !authenticator.unlocked && lockScreenUi.authenticationUiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
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
            state: ""
            factor: lockScreenUi.showAmbientDashboard ? 1.0 : lockScreenUi.authenticationReveal * 0.6
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
            opacity: lockScreenUi.authenticationReveal

            // Neutral dim, not a surface-colored wash: the wallpaper keeps its
            // colors and the white foreground stays legible.
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha("black", 0.10) }
                GradientStop { position: 0.55; color: Qt.alpha("black", 0.22) }
                GradientStop { position: 1.0; color: Qt.alpha("black", 0.42) }
            }
        }

        // Optional information dashboard. The default ambient view keeps the
        // wallpaper clear, with only the stacked clock and unlock hint.
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
            opacity: lockScreenUi.dashboardEntrance
            rotation: MeoTheme.reduceMotion
                      ? 0
                      : -180 * (1.0 - lockScreenUi.dashboardSpinProgress)
            scale: {
                const authenticationScale = MeoTheme.reduceMotion
                                            ? 1.0
                                            : 0.985 + lockScreenUi.authenticationReveal * 0.015
                const entranceScale = MeoTheme.reduceMotion
                                      ? 1.0
                                      : 0.12 + lockScreenUi.dashboardExpandProgress * 0.88
                return authenticationScale * entranceScale
            }

            layer.enabled: visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.78
                shadowOpacity: 0.34
                shadowVerticalOffset: 10 * MeoTheme.globalScale
                shadowColor: MeoTheme.shadow
            }

        }

        Item {
            id: dashboardEntranceGlyph
            anchors.centerIn: parent
            width: 104 * MeoTheme.globalScale
            height: width
            visible: lockScreenUi.wideAmbientDashboard
                     && lockScreenUi.activeAuthenticationSurface
                     && opacity > 0.001
            opacity: MeoTheme.reduceMotion
                     ? 0
                     : 1.0 - lockScreenUi.dashboardContentEntrance
            scale: 0.92 + lockScreenUi.dashboardSpinProgress * 0.08
            rotation: -180 * (1.0 - lockScreenUi.dashboardSpinProgress)

            MeoShape {
                anchors.fill: parent
                type: "squircle"
                radius: MeoTheme.shapeLarge
                color: MeoTheme.surface
                strokeWidth: MeoTheme.strokeWidthThin
                strokeColor: MeoTheme.outlineVariant
            }

            MeoIcon {
                anchors.centerIn: parent
                icon: "lock"
                size: 48 * MeoTheme.globalScale
                weight: 700
                fill: true
                color: MeoTheme.contentOnSurface
            }
        }

        // WallpaperFader owns the upstream `clock.shadow` visual contract.
        // Keep that adapter local to the KScreenLocker theme so MeoUI's clock
        // stays backend-agnostic for other session-entry consumers.
        Item {
            id: ambientClockFrame
            property Item shadow: ambientClockShadow
            visible: opacity > 0.001
            opacity: lockScreenUi.dashboardContentEntrance
                     * (1.0 - lockScreenUi.authenticationReveal)
            scale: MeoTheme.reduceMotion ? 1.0 : 1.0 - lockScreenUi.authenticationReveal * 0.055
            anchors.horizontalCenter: parent.horizontalCenter
            width: ambientClock.implicitWidth
            height: ambientClock.implicitHeight
            y: lockScreenUi.wideAmbientDashboard
               ? wideDashboardSurface.y + MeoTheme.space32
                 - lockScreenUi.authenticationReveal * 20 * MeoTheme.globalScale
               : Math.max(MeoTheme.space32,
                          (parent.height - height) * 0.42
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
                centerScale: lockScreenUi.dashboardCenterScale
                // Stacked hours/minutes sized from the screen like the
                // Googlebook lock screen; foreground follows the wallpaper.
                pixelSize: lockScreenUi.height * 0.205
                foregroundColor: lockScreenUi.clockForeground
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
            opacity: lockScreenUi.dashboardContentEntrance
                     * (1.0 - lockScreenUi.authenticationReveal * 0.08)
            scale: MeoTheme.reduceMotion
                   ? 1.0
                   : 0.92 + lockScreenUi.dashboardContentEntrance * 0.08
            transformOrigin: Item.Center
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
                        rootHeight: lockScreenUi.dashboardHeight
                        showForecast: lockScreenUi.dashboardHeight >= 975 * MeoTheme.globalScale
                                      && Weather.forecast.length > 0
                    }

                    MeoLockScreenSystemSummary {
                        Layout.fillWidth: true
                        visible: lockScreenUi.showSystemSummary
                        rootHeight: lockScreenUi.dashboardHeight
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
                        sessionControlsEnabled: lockScreenUi.showSessionControls
                        canSuspend: sessionManagement.canSuspend
                        canHibernate: sessionManagement.canHibernate
                        canReboot: sessionManagement.canReboot
                        canShutdown: sessionManagement.canShutdown
                        onSuspendRequested: lockScreenUi.confirmPower("sleep")
                        onHibernateRequested: lockScreenUi.confirmPower("hibernate")
                        onRebootRequested: lockScreenUi.confirmPower("reboot")
                        onShutdownRequested: lockScreenUi.confirmPower("shutdown")
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
            active: lockScreenUi.showAmbientDashboard
                    && lockScreenUi.activeAuthenticationSurface
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

        Column {
            id: ambientUnlockHint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(MeoTheme.space32, parent.height * 0.045)
            spacing: MeoTheme.space12
            visible: lockScreenUi.activeAuthenticationSurface && opacity > 0.001
            opacity: 1.0 - lockScreenUi.authenticationReveal
            MeoIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "lock"
                size: 28 * MeoTheme.globalScale
                color: lockScreenUi.hintForeground
            }
            MeoText {
                text: qsTr("Press any key to unlock")
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                color: lockScreenUi.hintForeground
            }
        }

        // Small status line in the top-left corner, as on the reference
        // lock screen. It exposes only the time and date.
        MeoText {
            id: ambientTopLeft
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: MeoTheme.space24
                topMargin: MeoTheme.space16
            }
            visible: lockScreenUi.activeAuthenticationSurface && opacity > 0.001
            opacity: 1.0 - lockScreenUi.authenticationReveal
            text: Qt.formatTime(ambientClock.dateTime, "h:mm") + "  " + ambientClock.dateLabel
            typeRole: "label"
            typeSize: "medium"
            emphasized: true
            color: lockScreenUi.topForeground
        }

        // Top-right status, as on the reference: real battery state only; it
        // is hidden on machines without an internal battery.
        Row {
            id: ambientTopRight
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: MeoTheme.space24
                topMargin: MeoTheme.space16
            }
            spacing: MeoTheme.space8
            visible: batteryControl.hasInternalBatteries
                     && lockScreenUi.activeAuthenticationSurface && opacity > 0.001
            opacity: 1.0 - lockScreenUi.authenticationReveal

            BatteryApi.BatteryControlModel { id: batteryControl }

            PW.BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 20 * MeoTheme.globalScale
                height: width
                pluggedIn: batteryControl.pluggedIn
                hasBattery: batteryControl.hasCumulative
                percent: batteryControl.percent
            }
            MeoText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("%1%").arg(batteryControl.percent)
                typeRole: "label"
                typeSize: "medium"
                emphasized: true
                color: lockScreenUi.topForeground
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
            Kirigami.Theme.inherit: false
            Kirigami.Theme.textColor: "white"
            Kirigami.Theme.disabledTextColor: Qt.alpha("white", 0.6)
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
                centerWidthScale: lockScreenUi.dashboardCenterScale
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
                        type: "tonal"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Sleep")
                        icon.name: "bedtime"
                        onClicked: {
                            lockScreenUi.confirmPower("sleep")
                        }
                        visible: sessionManagement.canSuspend
                    },
                    MeoButton {
                        type: "tonal"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Hibernate")
                        icon.name: "mode_standby"
                        onClicked: {
                            lockScreenUi.confirmPower("hibernate")
                        }
                        visible: sessionManagement.canHibernate
                    },
                    MeoButton {
                        type: "tonal"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Switch User")
                        icon.name: "switch_account"
                        onClicked: {
                            root.clearPassword()
                            sessionManagement.switchUser()
                        }
                        visible: sessionManagement.canSwitchUser
                    },
                    MeoButton {
                        type: "tonal"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Restart")
                        icon.name: "restart_alt"
                        onClicked: {
                            lockScreenUi.confirmPower("reboot")
                        }
                        visible: sessionManagement.canReboot
                    },
                    MeoButton {
                        type: "tonal"
                        size: "s"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Shut Down")
                        icon.name: "power_settings_new"
                        onClicked: {
                            lockScreenUi.confirmPower("shutdown")
                        }
                        visible: sessionManagement.canShutdown
                    }
                ]
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "file:/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockOsd.qml"
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
                type: "tonal"
                size: "s"
                focusPolicy: Qt.TabFocus
                text: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to show/hide virtual keyboard", "Virtual Keyboard")
                icon.name: Keyboards.KWinVirtualKeyboard.visible ? "keyboard_hide" : "keyboard"
                onClicked: {
                    if (Keyboards.KWinVirtualKeyboard.visible) {
                        Keyboards.KWinVirtualKeyboard.active = false
                    } else {
                        // Keep focus on the password field so on-screen
                        // keystrokes are not swallowed.
                        mainBlock.mainPasswordBox.forceActiveFocus()
                        Keyboards.KWinVirtualKeyboard.forceActivate()
                    }
                }
                Layout.fillHeight: true
            }

            // KeyboardLayoutSwitcher is still KDE's controller; this button
            // only presents that existing state through MeoUI.
            MeoButton {
                id: keyboardButton
                type: "tonal"
                size: "s"
                focusPolicy: Qt.TabFocus
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to change keyboard layout", "Switch layout")
                icon.name: "keyboard"

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
