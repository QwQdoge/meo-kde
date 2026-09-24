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
        self.no_password = (LOCKSCREEN / "MeoNoPasswordUnlock.qml").read_text(encoding="utf-8")
        self.media = (LOCKSCREEN / "MediaControls.qml").read_text(encoding="utf-8")
        self.notifications = (LOCKSCREEN / "MeoLockScreenNotificationSummary.qml").read_text(encoding="utf-8")
        self.config = (LOCKSCREEN / "config.xml").read_text(encoding="utf-8")
        self.media_source = (REPO_ROOT / "native/system/mediacontroller.cpp").read_text(encoding="utf-8")
        self.weather_source = (REPO_ROOT / "native/system/weathercache.cpp").read_text(encoding="utf-8")
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
        self.assertIn("MeoAmbientClock", self.ui)
        self.assertIn("MeoAuthenticationSurface", self.main)
        self.assertIn("clock: ambientClockFrame", self.ui)
        self.assertIn("property Item shadow: ambientClockShadow", self.ui)
        for forbidden in ("tryUnlock(", "property string password", "PamAuthenticator", "QDBus"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.ui + self.main)

    def test_p3_data_adapters_are_explicitly_bounded_and_optional(self):
        for required in (
            "import Meo.System 1.0",
            "MediaControls",
            "MeoWeatherStatus",
            "MeoLockScreenNotificationSummary.qml",
            "activeAuthenticationSurface && !lockScreenRoot.uiVisible",
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

    def test_rich_defaults_enable_explicit_current_session_modules(self):
        self.assertIn('<entry name="showMediaControls" type="Bool">', self.config)
        self.assertIn('<entry name="showAlbumArtwork" type="Bool">', self.config)
        self.assertIn('<entry name="showWeather" type="Bool">', self.config)
        self.assertIn('<entry name="showWeatherLocation" type="Bool">', self.config)
        self.assertIn('<entry name="lockScreenNotificationVisibility" type="String">', self.config)
        self.assertIn('<entry name="showAudioControls" type="Bool">', self.config)
        for entry in ("showMediaControls", "showAlbumArtwork", "showAudioControls", "showWeather", "showWeatherLocation"):
            with self.subTest(entry=entry):
                section = self.config.split(f'<entry name="{entry}"', 1)[1].split("</entry>", 1)[0]
                self.assertIn("<default>true</default>", section)
        self.assertIn('<default>full-content</default>', self.config)
        self.assertIn("groupMode: NotificationManager.Notifications.GroupDisabled", self.notifications)
        for forbidden in ("invokeDefaultAction", "reply(", "urls", "showJobs: true", "showExpired: true"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.notifications)

    def test_no_password_path_uses_same_meoui_surface(self):
        self.assertIn("SessionManagementScreen", self.no_password)
        self.assertIn("MeoAuthenticationSurface", self.no_password)
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
