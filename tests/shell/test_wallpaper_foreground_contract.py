"""Source contract for wallpaper-region-aware top-bar foreground."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class WallpaperForegroundContract(unittest.TestCase):
    def test_native_sampler_is_cached_and_local_image_only(self):
        source = read("native/system/wallpapercontrast.cpp")
        self.assertIn("DynamicColorSource::configuredWallpaperPath", source)
        self.assertIn("m_regionCache", source)
        self.assertIn("m_cachedStamp", source)
        # No screen capture or continuous polling.
        for forbidden in ("grabWindow", "QScreen", "QTimer", "startTimer"):
            self.assertNotIn(forbidden, source)
        self.assertIn('"WallpaperContrast"', read("native/system/meosystemplugin.cpp"))
        self.assertIn("meo-wallpaper-contrast", read("native/system/CMakeLists.txt"))

    def test_unknown_wallpaper_never_guesses(self):
        header = read("native/system/wallpapercontrast.h")
        self.assertIn("-1", header)
        panel = read("qml/MeoKDE/PanelForeground.qml")
        self.assertIn("fallbackDark", panel)
        self.assertIn("MeoShellTheme.panelForeground", panel)

    def test_panel_foreground_is_throttled_and_event_driven(self):
        panel = read("qml/MeoKDE/PanelForeground.qml")
        self.assertIn("Timer", panel)
        self.assertIn("onChanged", panel)
        self.assertIn("prefersDarkForeground", panel)
        self.assertNotIn("grabToImage", panel)
        self.assertNotIn("onFrameSwapped", panel)
        self.assertIn("PanelForeground 1.0 PanelForeground.qml", read("qml/MeoKDE/qmldir"))

    def test_top_bar_surfaces_use_region_foreground_not_a_fixed_color(self):
        for path in (
            "qml/MeoKDE/ShellTriggerSurface.qml",
            "qml/MeoKDE/TimeNotificationButton.qml",
            "qml/MeoKDE/NotificationCompactButton.qml",
            "plasmoids/org.meo.topbar/contents/ui/components/SystemStatusCluster.qml",
        ):
            with self.subTest(path=path):
                text = read(path)
                self.assertIn("PanelForeground", text)
                self.assertNotIn("MeoShellTheme.panelForeground", text)


if __name__ == "__main__":
    unittest.main()
