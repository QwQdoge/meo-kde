"""Current first-party Plasma shell composition contracts.

The broad regression suite lives in desktop_layout_contracts.py so intentional
UI contract changes can be overridden here without weakening unrelated tests.
"""

import importlib.util
from pathlib import Path


BASE = Path(__file__).with_name("desktop_layout_contracts.py")
SPEC = importlib.util.spec_from_file_location("meo_desktop_layout_contracts", BASE)
legacy = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(legacy)


class DesktopLayoutTests(legacy.DesktopLayoutTests):
    def test_shelf_pairs_launcher_and_search_without_a_second_task_model(self):
        shelf = (
            legacy.REPO_ROOT / "plasmoids/org.meo.shelf/contents/ui/main.qml"
        ).read_text(encoding="utf-8")
        launcher = (
            legacy.REPO_ROOT / "plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("MeoIconButton", shelf)
        self.assertIn('source: "meoarch-logo"', shelf)
        self.assertIn('i18n("All apps")', shelf)
        self.assertIn("launcherPopup.toggleFullLauncher()", shelf)
        self.assertNotIn("MeoButtonGroup", shelf)
        self.assertNotIn("TaskManager.TasksModel", shelf)
        for key in (
            "launcherDefaultPage", "launcherWidth", "launcherPlacement",
            "launcherShowFavorites", "launcherShowRecents",
        ):
            self.assertIn(f"Plasmoid.configuration.{key}", shelf)

        # Search remains part of the same launcher backend for Alt+Space and
        # in-launcher queries; it is simply no longer a second shelf button.
        self.assertIn("function openQuickSearch()", launcher)
        self.assertIn("Kicker.RunnerModel", launcher)
        self.assertIn("popupType: QQC2.Popup.Window", launcher)

    def test_default_profile_selects_native_taskbar(self):
        profile = (
            legacy.REPO_ROOT / "defaults/plasma/meo-shellrc"
        ).read_text(encoding="utf-8")
        helper = (
            legacy.REPO_ROOT / "tools/shell/apply-meo-panel-layout.sh"
        ).read_text(encoding="utf-8")
        metrics = (
            legacy.REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("DockHeight=48", profile)
        self.assertIn("DockImplementation=native", profile)
        self.assertIn("shelfPanelHeight: 48 * MeoTheme.globalScale", metrics)
        self.assertIn("shelfSurfaceHeight: 48 * MeoTheme.globalScale", metrics)
        self.assertIn("shelfBottomMargin: 0 * MeoTheme.globalScale", metrics)
        self.assertIn('if ("${panel_mode}" === "dual" && "${dock_implementation}" === "native")', helper)
        self.assertNotIn('writeConfig("maxStripes"', helper)

        expected_fallbacks = {
            "MeoLight": ("#1c1b1f", "#6750a4", "#b3261e"),
            "MeoDark": ("#e6e0e9", "#d0bcff", "#ffb4ab"),
        }
        required_frames = (
            "normal", "normal-hover", "focus", "focus-hover",
            "minimized", "minimized-hover", "attention", "attention-hover",
            "progress", "launcher-hover",
        )
        required_parts = (
            "center", "top", "left", "right", "topleft", "topright",
            "bottomleft", "bottomright", "bottom",
        )
        for mode, fallbacks in expected_fallbacks.items():
            task_frame = (
                legacy.REPO_ROOT
                / f"themes/desktoptheme/{mode}/widgets/tasks.svg"
            ).read_text(encoding="utf-8")
            for fallback in fallbacks:
                self.assertIn(fallback, task_frame)
            for frame in required_frames:
                for part in required_parts:
                    self.assertIn(f'id="{frame}-{part}"', task_frame)
            self.assertIn("ColorScheme-ButtonFocus", task_frame)
            self.assertIn("ColorScheme-Background", task_frame)
            self.assertIn("A20.5 20.5", task_frame)
            self.assertIn('id="normal-indicator"', task_frame)
            self.assertIn('id="focus-indicator"', task_frame)
            self.assertIn('id="minimized-indicator"', task_frame)
            self.assertIn('width="12" height="2" rx="1" opacity="0.72"', task_frame)
            self.assertIn('width="18" height="4" rx="2" opacity="1"', task_frame)
            self.assertIn('id="group-expander-bottom"', task_frame)
            self.assertIn('id="normal-center"', task_frame)
            self.assertIn(
                'id="normal-center" x="23.5" y="23.5" width="1" height="1" opacity="0"',
                task_frame,
            )
            self.assertIn('id="normal-hover-center"', task_frame)
            self.assertIn('opacity="0.10"', task_frame)
            self.assertNotIn('opacity="0.94"', task_frame)

    def test_status_and_quick_settings_have_compact_width_contracts(self):
        super().test_status_and_quick_settings_have_compact_width_contracts()
        metrics = (
            legacy.REPO_ROOT / "qml/MeoKDE/ShellMetrics.qml"
        ).read_text(encoding="utf-8")
        quick_center = (
            legacy.TOPBAR / "QuickSettingsCenter.qml"
        ).read_text(encoding="utf-8")
        self.assertIn("quickSettingsWidth: 440 * MeoTheme.globalScale", metrics)
        self.assertIn("implicitWidth: ShellMetrics.quickSettingsWidth", quick_center)


if __name__ == "__main__":
    legacy.unittest.main()
