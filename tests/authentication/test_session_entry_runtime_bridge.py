from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCK_ROOT = REPO_ROOT / "lockscreen"
OVERRIDES = LOCK_ROOT / "overrides/modules/lock"
PKGBUILD = REPO_ROOT / "packaging/arch/meo-lockscreen/PKGBUILD"
LAUNCHER = LOCK_ROOT / "meo-lockscreen-launch"


class SessionEntryRuntimeBridgeTests(unittest.TestCase):
    def read(self, path: Path) -> str:
        return path.read_text(encoding="utf-8")

    def test_launcher_exports_real_user_paths_before_xdg_isolation(self):
        launcher = self.read(LAUNCHER)
        session_export = 'export MEO_SESSION_ENTRY_CONFIG="${user_config_home}/meo/session-entry/lockscreen-v1.json"'
        weather_export = 'export MEO_LOCKSCREEN_WEATHER_CACHE="${state_home}/meo/weather/lockscreen.json"'
        xdg_override = 'export XDG_CONFIG_HOME="${config_home}"'

        self.assertIn(session_export, launcher)
        self.assertIn(weather_export, launcher)
        self.assertIn(xdg_override, launcher)
        self.assertLess(launcher.index(session_export), launcher.index(xdg_override))
        self.assertLess(launcher.index(weather_export), launcher.index(xdg_override))

    def test_package_replaces_only_presentation_modules(self):
        pkgbuild = self.read(PKGBUILD)
        expected = {
            "MeoSessionEntry.qml",
            "MeoWeatherCache.qml",
            "MeoNotificationPane.qml",
            "Content.qml",
            "Media.qml",
            "WeatherInfo.qml",
        }
        for name in expected:
            with self.subTest(name=name):
                self.assertIn(f'lockscreen/overrides/modules/lock/{name}', pkgbuild)

        # Authentication/session-lock primitives remain the pinned upstream
        # implementation; this bridge must not replace them.
        for forbidden in ("Pam.qml", "Lock.qml", "LockSurface.qml"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(f'lockscreen/overrides/modules/lock/{forbidden}', pkgbuild)

    def test_session_entry_reader_is_fail_closed_and_bounded(self):
        source = self.read(OVERRIDES / "MeoSessionEntry.qml")
        for required in (
            'document.schemaVersion !== 1',
            'document.scope !== "lockscreen"',
            'text.length > 64 * 1024',
            'notificationVisibility = "hidden"',
            'showAlbumArtwork = false',
            'weatherLocation = "hidden"',
            'reduceMotion = "always"',
            'source = "safe-fallback"',
            'watchChanges: true',
        ):
            with self.subTest(required=required):
                self.assertIn(required, source)

        self.assertNotIn("execDetached", source)
        self.assertNotIn("Process {", source)
        self.assertNotIn("Requests.", source)

    def test_weather_surface_is_cache_only(self):
        cache = self.read(OVERRIDES / "MeoWeatherCache.qml")
        weather = self.read(OVERRIDES / "WeatherInfo.qml")

        self.assertIn('Quickshell.env("MEO_LOCKSCREEN_WEATHER_CACHE")', cache)
        self.assertIn("maximumAgeMs: 6 * 60 * 60 * 1000", cache)
        self.assertIn("cacheFile.reload()", cache)
        self.assertNotIn("Requests.", cache)
        self.assertNotIn("http://", cache)
        self.assertNotIn("https://", cache)
        self.assertNotIn("Weather.reload", weather)
        self.assertNotIn("qs.services", weather)
        self.assertIn("MeoWeatherCache", weather)

    def test_content_does_not_instantiate_optional_private_cards_when_disabled(self):
        content = self.read(OVERRIDES / "Content.qml")
        self.assertIn("MeoSessionEntry.weatherEnabled && MeoWeatherCache.available", content)
        self.assertIn("MeoSessionEntry.mediaEnabled", content)
        self.assertIn("MeoNotificationPane", content)

    def test_notification_summary_respects_all_privacy_modes(self):
        source = self.read(OVERRIDES / "MeoNotificationPane.qml")
        for mode in ("hidden", "count", "app-name", "full-content"):
            with self.subTest(mode=mode):
                self.assertIn(f'"{mode}"', source)

        # Restricted modes use only count/appName. Summary/body rendering is
        # delegated solely to the explicit full-content branch.
        self.assertIn("notification.appName", source)
        self.assertNotIn("notification.summary", source)
        self.assertNotIn("notification.body", source)
        self.assertIn('active: root.mode === "full-content"', source)

    def test_album_art_is_opt_in_and_local_only(self):
        media = self.read(OVERRIDES / "Media.qml")
        self.assertIn("MeoSessionEntry.showAlbumArtwork", media)
        self.assertIn('candidate.startsWith("file://")', media)
        self.assertNotIn("https://img.youtube.com", media)


if __name__ == "__main__":
    unittest.main()
