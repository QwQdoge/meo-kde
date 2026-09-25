"""P1 lockscreen theme contract: visual ownership only, KDE owns authentication."""

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCKSCREEN = REPO_ROOT / "themes/look-and-feel/org.meo.desktop/contents/lockscreen"
NATIVE_LOCKSCREEN = REPO_ROOT / "native/lockscreen"


class LockScreenThemeTests(unittest.TestCase):
    def setUp(self):
        self.root = (LOCKSCREEN / "LockScreen.qml").read_text(encoding="utf-8")
        self.ui = (LOCKSCREEN / "MeoLockScreenUi.qml").read_text(encoding="utf-8")
        self.main = (LOCKSCREEN / "MeoLockScreenMainBlock.qml").read_text(encoding="utf-8")
        self.auth_card = (LOCKSCREEN / "MeoLockScreenAuthCard.qml").read_text(encoding="utf-8")
        self.clock = (LOCKSCREEN / "MeoLockScreenClock.qml").read_text(encoding="utf-8")
        self.password_field = (LOCKSCREEN / "MeoLockScreenPasswordField.qml").read_text(encoding="utf-8")
        self.session_geometry = (LOCKSCREEN / "MeoLockScreenSessionManagement.qml").read_text(encoding="utf-8")
        self.no_password = (LOCKSCREEN / "MeoNoPasswordUnlock.qml").read_text(encoding="utf-8")
        self.media = (LOCKSCREEN / "MediaControls.qml").read_text(encoding="utf-8")
        self.notifications = (LOCKSCREEN / "MeoLockScreenNotificationSummary.qml").read_text(encoding="utf-8")
        self.weather_card = (LOCKSCREEN / "MeoLockScreenWeatherCard.qml").read_text(encoding="utf-8")
        self.performance_card = (LOCKSCREEN / "MeoLockScreenPerformanceSummary.qml").read_text(encoding="utf-8")
        self.wavy_fill = (LOCKSCREEN / "MeoLockScreenWavyFill.qml").read_text(encoding="utf-8")
        self.system_summary = (LOCKSCREEN / "MeoLockScreenSystemSummary.qml").read_text(encoding="utf-8")
        self.config = (LOCKSCREEN / "config.xml").read_text(encoding="utf-8")
        self.media_source = (REPO_ROOT / "native/system/mediacontroller.cpp").read_text(encoding="utf-8")
        self.weather_source = (REPO_ROOT / "native/system/weathercache.cpp").read_text(encoding="utf-8")
        self.weather_refresh_source = (REPO_ROOT / "native/system/weatherrefresh.cpp").read_text(encoding="utf-8")
        self.coordinator_header = (NATIVE_LOCKSCREEN / "screencoordinator.h").read_text(encoding="utf-8")
        self.coordinator_source = (NATIVE_LOCKSCREEN / "screencoordinator.cpp").read_text(encoding="utf-8")
        self.coordinator_cmake = (NATIVE_LOCKSCREEN / "CMakeLists.txt").read_text(encoding="utf-8")

    def test_root_preserves_kscreenlocker_magic_contract(self):
        for required in (
            "property bool debug",
            "property string notification",
            "signal clearPassword()",
            "signal notificationRepeated()",
            "property bool viewVisible",
            "MeoLockScreenUi",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.root)

    def test_uses_upstream_authenticator_and_single_password_sync_owner(self):
        self.assertIn("text: PasswordSync.password", self.main)
        self.assertIn('target: PasswordSync', self.main)
        self.assertIn('property: "password"', self.main)
        self.assertIn("authenticator.respond(password)", self.ui)
        self.assertIn("authenticator.startAuthenticating()", self.ui)
        self.assertNotIn("tryUnlock(", self.ui)
        self.assertNotIn("property string password", self.main)
        self.assertNotIn("property string credential", self.main)

    def test_preserves_real_system_affordances(self):
        for required in (
            "ScreenLocker.Authenticator.Fingerprint",
            "ScreenLocker.Authenticator.Smartcard",
            "VirtualKeyboardLoader",
            "KeyboardLayoutSwitcher",
            "KeyboardIndicator.KeyState",
            "sessionManagement.suspend()",
            "sessionManagement.hibernate()",
            "sessionManagement.switchUser()",
            "root.clearPassword()",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.main + self.ui)

    def test_meoui_session_entry_primitives_remain_presentation_only(self):
        self.assertIn("import MeoUI 1.0", self.ui)
        self.assertIn("MeoLockScreenClock", self.ui)
        self.assertIn("MeoLockScreenAuthCard", self.main)
        self.assertIn("MeoSpringValue", self.auth_card)
        self.assertIn("clock: wallpaperClockProxy", self.ui)
        self.assertIn("property Item shadow: wallpaperClockProxyShadow", self.ui)
        self.assertIn("id: ambientClockFrame", self.ui)
        for forbidden in ("tryUnlock(", "property string password", "PamAuthenticator", "QDBus"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.ui + self.main + self.auth_card)

        for forbidden in ("PasswordSync", "authenticator", "respond(", "PamAuthenticator", "QDBus"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.password_field)

    def test_standalone_visual_port_keeps_dynamic_roles_and_safe_motion(self):
        for required in (
            "MeoTheme.surfaceContainer",
            "MeoTheme.surfaceContainerHighest",
            "MeoTheme.motionEasingEmphasizedDecelerate",
            "MeoSpringValue",
            "MeoTheme.reduceMotion",
            "Accessible.role: Accessible.Pane",
            "MeoLockScreenClock",
            "avatarSource",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.auth_card)
        for forbidden in ("PasswordSync", "authenticator", "respond(", "QDBus", "PamAuthenticator"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.auth_card)
        self.assertIn("avatarSource: kscreenlocker_userImage", self.ui)

    def test_expressive_motion_and_gradient_remain_presentation_only(self):
        for required in (
            "property real authenticationReveal",
            "Gradient {",
            "expressiveScrim",
            "motionEasingEmphasizedDecelerate",
            "motionEasingEmphasizedAccelerate",
            "0.94 + lockScreenUi.authenticationReveal * 0.06",
            "primaryContainer",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui + self.auth_card)

        self.assertIn("implicitHeight: content.implicitHeight + contentInset * 2", self.auth_card)
        self.assertIn("Math.min(600 * MeoTheme.globalScale", self.auth_card)
        self.assertIn("failed: sessionManager.authenticationFailed", self.main)

        for forbidden in ("PamAuthenticator", "tryUnlock(", "QDBus"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.auth_card)

    def test_standalone_visual_geometry_keeps_breeze_models_but_expands_the_center(self):
        self.assertIn("MeoLockScreenSessionManagement", self.main)
        self.assertIn("Breeze.UserList", self.session_geometry)
        self.assertIn("property alias actionItems", self.session_geometry)
        self.assertIn("standaloneCenterWidth", self.session_geometry)
        self.assertIn("600 * MeoTheme.globalScale", self.session_geometry)
        self.assertIn("Layout.preferredWidth: root.standaloneCenterWidth", self.session_geometry)
        self.assertIn("Layout.fillWidth: true", self.session_geometry)
        self.assertIn("Layout.preferredWidth: sessionManager.standaloneCenterWidth", self.main)

    def test_password_pill_ports_standalone_visual_without_owning_credentials(self):
        for required in (
            "radius: height / 2",
            "MeoTheme.surfaceContainer",
            "MeoIconButton",
            "arrow_forward",
            "signal unlockRequested()",
            "property alias unlockButton: submitButton",
            "cursorVisible: visible",
            "Accessible.name",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.password_field)
        for forbidden in ("PasswordSync", "authenticator", "PamAuthenticator", "QDBus"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.password_field)

    def test_password_pill_keeps_kscreenlocker_focus_and_keyboard_contract(self):
        self.assertIn("passwordBox.unlockButton.forceActiveFocus()", self.main)
        self.assertIn("mapFromItem(passwordBox.unlockButton", self.main)
        self.assertIn("TextField {", self.password_field)
        self.assertIn("passwordField: mainBlock.mainPasswordBox", self.ui)

    def test_p3_data_adapters_are_explicitly_bounded_and_optional(self):
        for required in (
            "import Meo.System 1.0",
            "MediaControls",
            "MeoWeatherStatus",
            "MeoLockScreenNotificationSummary.qml",
            "active: lockScreenUi.activeAuthenticationSurface",
            "showAlbumArtwork",
            "showWeatherLocation",
            "lockScreenNotificationVisibility",
                "showAudioControls",
                "SystemState.audioAvailable",
                "showMedia: lockScreenUi.showMediaControls",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui + self.main + self.media)

        for required in (
            "asyncCall",
            "kDbusTimeoutMs",
            "safeLocalArtworkUrl",
            "safeSessionArtworkUrl",
            "kMaximumArtworkBytes",
            "isLocalFile",
            "QNetwork",
        ):
            with self.subTest(required=required):
                if required == "QNetwork":
                    self.assertNotIn(required, self.media_source)
                else:
                    self.assertIn(required, self.media_source)

        # Lock-screen QML consumes only the local-file projection. The
        # session-only HTTPS projection never crosses the lock-screen boundary.
        self.assertIn("coverSource: root.showArtwork ? Media.artUrl : \"\"", self.media)
        self.assertNotIn("remoteArtUrl", self.media)

        for required in (
            "kMaximumCacheBytes",
            "kMaximumCacheAgeSeconds",
            "QFileSystemWatcher",
            "QJsonDocument",
            "QNetwork",
        ):
            with self.subTest(required=required):
                if required == "QNetwork":
                    self.assertNotIn(required, self.weather_source)
                else:
                    self.assertIn(required, self.weather_source)

    def test_weather_forecast_is_real_cache_data_and_never_locker_network(self):
        for required in (
            'QStringLiteral("hourly")',
            'QStringLiteral("temperature_2m,weather_code")',
            'QStringLiteral("forecast_hours")',
            'QStringLiteral("6")',
            'QStringLiteral("forecast")',
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.weather_refresh_source)

        for required in (
            "Q_PROPERTY(QVariantList forecast",
            'object.value(QStringLiteral("forecast")).toArray()',
            "Weather.forecast.slice(0, 4)",
            "showForecast",
            "dashboardHeight >= 700 * MeoTheme.globalScale",
            "iconMapper.materialSymbolFor",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.weather_source + self.weather_card + self.ui
                              + (REPO_ROOT / "native/system/weathercache.h").read_text(encoding="utf-8"))

        self.assertNotIn("QNetwork", self.weather_source)
        self.assertNotIn("http://", self.weather_card)
        self.assertNotIn("https://", self.weather_card)

    def test_wide_ambient_dashboard_matches_reference_spatial_hierarchy(self):
        for required in (
            "wideAmbientDashboard",
            "MeoLockScreenWeatherCard",
            "MeoLockScreenSystemSummary",
            "MediaControls",
            "MeoLockScreenPerformanceSummary",
            "MeoLockScreenNotificationSummary.qml",
            "dashboardHeight",
            "height * 0.70",
            "dashboardWidth",
            "dashboardHeight * 16 / 9",
            "anchors.fill: wideDashboardSurface",
            "Layout.preferredWidth: lockScreenUi.dashboardCenterWidth",
            "compactAmbientDashboard",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui)

    def test_reference_visual_language_uses_real_meoui_shapes_and_surfaces(self):
        for required in (
            'shapeName: "Pentagon"',
            'shapeName: "Slanted"',
            'shapeName: "Gem"',
            'Performance.cpuTemperature >= 90 ? "SoftBurst" : "Circle"',
            'text: "meofetch"',
            "font.family: MeoTheme.fontFamilyMonospace",
            "radius: MeoTheme.shapeExtraLarge * 1.35",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.performance_card + self.system_summary + self.weather_card)

        for required in (
            "id: wideDashboardSurface",
            "height * 0.70",
            "dashboardHeight * 16 / 9",
            "shadowEnabled: true",
            "embeddedDashboard: lockScreenUi.wideAmbientDashboard",
            "footer: wallpaperFooterProxy",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui)

        self.assertIn("property bool embedded: false", self.auth_card)
        self.assertIn("opacity: card.embedded ? 0 : 1", self.auth_card)

    def test_caelestia_center_style_reuses_meoui_primitives(self):
        for required in (
            'variant: "ClamShell"',
            "centerScale: card.centerScale",
            "visible: !card.embedded && text !== \"\"",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.auth_card)

        for required in (
            "property real centerScale: 1.0",
            'Qt.formatDate(dateTime, "dddd • d MMM").toUpperCase()',
            "224 * clock.centerScale * MeoTheme.globalScale",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.clock)

        for required in (
            "emptyFieldWidth",
            "filledFieldWidth",
            "MeoShapeMorph",
            'fromShape: "Circle"',
            'toShape: "Arrow"',
            "fingerprintAvailable",
            "smartcardAvailable",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.password_field)

    def test_resource_hover_reuses_kde_session_management(self):
        for required in (
            "HoverHandler",
            "sessionControlsShown",
            "signal suspendRequested()",
            "signal hibernateRequested()",
            "signal rebootRequested()",
            "signal shutdownRequested()",
            "property bool sessionControlsEnabled: true",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.performance_card)

        for required in (
            "sessionControlsEnabled: lockScreenUi.showSessionControls",
            "canSuspend: sessionManagement.canSuspend",
            "canHibernate: sessionManagement.canHibernate",
            "canReboot: sessionManagement.canReboot",
            "canShutdown: sessionManagement.canShutdown",
            "sessionManagement.suspend()",
            "sessionManagement.hibernate()",
            "sessionManagement.requestReboot()",
            "sessionManagement.requestShutdown()",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui)

    def test_caelestia_entrance_uses_transform_motion_not_layout_animation(self):
        for required in (
            "property real dashboardEntrance",
            "dashboardSpinProgress",
            "dashboardExpandProgress",
            "dashboardContentEntrance",
            "NumberAnimation on dashboardEntrance",
            "id: dashboardEntranceGlyph",
            "-180 * (1.0 - lockScreenUi.dashboardSpinProgress)",
            "0.12 + lockScreenUi.dashboardExpandProgress * 0.88",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui)

        for forbidden in (
            "NumberAnimation on dashboardWidth",
            "NumberAnimation on dashboardHeight",
            'property: "width"',
            'property: "height"',
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.ui)

    def test_resource_liquid_fill_is_shape_masked_and_idle_safe(self):
        self.assertIn("MeoLockScreenWavyFill", self.performance_card)
        for required in (
            "maskEnabled: true",
            "MeoShape",
            "type: root.shapeName",
            "property bool animate: true",
            "NumberAnimation on waveOffset",
            "loops: Animation.Infinite",
            "easing.type: Easing.Linear",
            "import QtQuick.Shapes",
            "Shape {",
            "PathSvg",
            "Behavior on animatedValue",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.wavy_fill)

        # The wave strip is scene-graph geometry and is translated as one
        # cached item. No Canvas/QQuickPaintedItem upload path is allowed.
        self.assertNotIn("Canvas {", self.wavy_fill)
        self.assertNotIn("requestPaint", self.wavy_fill)
        self.assertNotIn("onWaveOffsetChanged", self.wavy_fill)
        self.assertIn("animate: root.visible && !root.sessionControlsShown", self.performance_card)

    def test_fetch_matches_caelestia_structure_without_identity_disclosure(self):
        for required in (
            'text: "meofetch"',
            'label: "OS"',
            "Performance.operatingSystemName",
            "Performance.kernelVersion",
            "Performance.desktopEnvironment",
            'label: "WM"',
            "Performance.desktopEnvironment",
            '"KDE Plasma"',
            'label: "UP"',
            'label: "BATT"',
            "paletteSwatches",
            "MeoTheme.primaryContainer",
            "MeoTheme.secondaryContainer",
            "MeoTheme.tertiaryContainer",
            "StatusChip",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.system_summary)

        for forbidden in (
            "USER",
            "SystemState.networkName",
            "SystemState.wifiNetworks",
            "SystemState.bluetoothDevices",
            "qEnvironmentVariable",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.system_summary)

    def test_lock_performance_projection_is_aggregate_and_privacy_bounded(self):
        for required in (
            'Performance.subscribe(clientId, ["cpu", "memory", "disk", "system"])',
            "Performance.cpuUsage",
            "Performance.memoryUsage",
            "Performance.storageUsage",
            "Performance.cpuTemperature",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.performance_card)

        for forbidden in (
            "topCpuProcesses",
            "topMemoryProcesses",
            "processes",
            "networkInterfaces",
            "networkName",
            "terminateProcess",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.performance_card)

    def test_lock_system_summary_does_not_disclose_identity_or_network_name(self):
        for required in (
            "Performance.uptimeSeconds",
            "SystemState.networkConnected",
            "SystemState.batteryPercent",
            "SystemState.volumePercent",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.system_summary)
        for forbidden in (
            "SystemState.networkName",
            "Performance.processes",
            "Performance.topCpuProcesses",
            "Performance.topMemoryProcesses",
            "SystemState.wifiNetworks",
            "SystemState.bluetoothDevices",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.system_summary)

    def test_rich_defaults_enable_explicit_current_session_modules(self):
        self.assertIn('<entry name="showMediaControls" type="Bool">', self.config)
        self.assertIn('<entry name="showAlbumArtwork" type="Bool">', self.config)
        self.assertIn('<entry name="showWeather" type="Bool">', self.config)
        self.assertIn('<entry name="showWeatherLocation" type="Bool">', self.config)
        self.assertIn('<entry name="lockScreenNotificationVisibility" type="String">', self.config)
        self.assertIn('<entry name="showAudioControls" type="Bool">', self.config)
        self.assertIn('<entry name="showPerformance" type="Bool">', self.config)
        self.assertIn('<entry name="showSystemSummary" type="Bool">', self.config)
        self.assertIn('<entry name="showSessionControls" type="Bool">', self.config)
        for entry in ("showMediaControls", "showAlbumArtwork", "showAudioControls", "showWeather", "showPerformance", "showSystemSummary", "showSessionControls"):
            with self.subTest(entry=entry):
                section = self.config.split(f'<entry name="{entry}"', 1)[1].split("</entry>", 1)[0]
                self.assertIn("<default>true</default>", section)

        weather_location = self.config.split('<entry name="showWeatherLocation"', 1)[1].split("</entry>", 1)[0]
        self.assertIn("<default>false</default>", weather_location)
        notification_privacy = self.config.split('<entry name="lockScreenNotificationVisibility"', 1)[1].split("</entry>", 1)[0]
        self.assertIn("<default>count</default>", notification_privacy)

        self.assertIn("groupMode: NotificationManager.Notifications.GroupApplicationsFlat", self.notifications)
        self.assertIn("groupLimit: 2", self.notifications)
        self.assertIn("required property bool isGroup", self.notifications)
        self.assertIn("required property bool isInGroup", self.notifications)
        self.assertIn("required property bool isGroupExpanded", self.notifications)
        self.assertIn("delegateRoot.model.isGroupExpanded = !delegateRoot.isGroupExpanded", self.notifications)
        for forbidden in ("invokeDefaultAction", "reply(", "urls", "showJobs: true", "showExpired: true"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.notifications)

    def test_media_uses_the_dynamic_lockscreen_presentation(self):
        for required in (
            'presentation: "lockScreen"',
            "coverSource: root.showArtwork ? Media.artUrl : \"\"",
            "showArtwork: root.showArtwork",
            "MeoMediaController",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.media)
        for forbidden in ("asyncCall", "QProcess", "http://", "https://"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.media)

    def test_no_password_path_uses_same_meoui_surface(self):
        self.assertIn("SessionManagementScreen", self.no_password)
        self.assertIn("MeoLockScreenAuthCard", self.no_password)
        self.assertIn("Qt.quit()", self.no_password)

    def test_multiscreen_coordinator_selects_only_existing_secure_windows(self):
        for required in (
            "import Meo.KScreenLocker 1.0",
            "ScreenCoordinator.registerSurface(org_kde_plasma_screenlocker_greeter_view)",
            "ScreenCoordinator.unregisterSurface(org_kde_plasma_screenlocker_greeter_view)",
            "ScreenCoordinator.requestAuthenticationOn(org_kde_plasma_screenlocker_greeter_view)",
            "ScreenCoordinator.dismissAuthentication()",
            "activeAuthenticationSurface",
            "screenMigrationDuration",
            "upwardSwipeThreshold",
            "authenticationSwipeRecognized",
            "gestureStartY - mouse.y",
            "Swipe up to unlock on this display",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.ui)

        for required in (
            "QGuiApplication::screenAdded",
            "QGuiApplication::screenRemoved",
            "QWindow::screenChanged",
            "requestActivate()",
            "FixedPrimary",
            "FollowInteraction",
            "registeredSurfaceCount",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.coordinator_source + self.coordinator_header)

    def test_multiscreen_coordinator_never_becomes_a_credential_owner(self):
        coordinator = self.coordinator_header + self.coordinator_source
        for forbidden in (
            "authenticator.respond",
            "PamAuthenticator",
            "PasswordSync",
            "QDBus",
            "property string password",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, coordinator)
        self.assertIn("meo-lockscreen-screen-coordinator", self.coordinator_cmake)
        self.assertIn("add_test(", self.coordinator_cmake)


if __name__ == "__main__":
    unittest.main()
