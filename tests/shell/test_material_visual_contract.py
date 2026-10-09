"""Material/Meo visual regression contracts for first-party shell surfaces."""

from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


class MaterialVisualContractTests(unittest.TestCase):
    def test_shell_theme_uses_dynamic_material_and_expressive_motion(self):
        source = read("qml/MeoKDE/MeoShellTheme.qml")

        self.assertIn("MeoTheme.isExpressive = true", source)
        self.assertIn("MeoTheme.applyDynamicColorScheme", source)
        self.assertIn("MeoTheme.reduceMotion = platformShortDuration <= 0", source)
        self.assertIn("MeoTheme.isBouncy = !MeoTheme.reduceMotion", source)
        self.assertIn("SchemeTonalSpot", source)
        self.assertNotRegex(source, r'#[0-9A-Fa-f]{3,8}')

    def test_shared_shell_surfaces_keep_one_material_primitive_stack(self):
        frosted = read("qml/MeoKDE/FrostedSurface.qml")
        trigger = read("qml/MeoKDE/ShellTriggerSurface.qml")
        quick_center = read("plasmoids/org.meo.topbar/contents/ui/QuickSettingsCenter.qml")
        quick_home = read("plasmoids/org.meo.topbar/contents/ui/QuickSettingsHome.qml")
        status = read("qml/MeoKDE/StatusCenterView.qml")
        notifications = read("qml/MeoKDE/NotificationCenterView.qml")
        launcher = read("plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml")

        for token in (
            "MeoMotionSurface", "MeoTheme.surfaceContainer",
            "MeoTheme.transparencyEnabled", "elevation: 3", "showOutline: false",
        ):
            self.assertIn(token, frosted)

        for token in (
            "MeoShape", "MeoStateLayer", "MeoTheme.primaryContainer",
            "MeoTheme.onPrimaryContainer",
        ):
            self.assertIn(token, trigger)

        for token in (
            "MeoRevealMotion", "FrostedSurface",
            'MeoMotion.pageOffset("pixel")', "MeoTheme.motionDurationPage",
        ):
            self.assertIn(token, quick_center)

        for token in (
            "MeoQuickSettingsTile", 'visualStyle: "pixel"',
            "MeoQuickControlSlider",
        ):
            self.assertIn(token, quick_home)

        for token in (
            "MeoStatusCenter", "MeoRevealMotion", "MeoTheme.surfaceContainerLow",
        ):
            self.assertIn(token, status)

        for token in (
            "MeoMotionSurface", "MeoStateLayer", "MeoTheme.surfaceContainerHigh",
        ):
            self.assertIn(token, notifications)

        for token in (
            "MeoMotionPopup", "MeoSearchBar", "MeoAppGridItem",
            "MeoContextMenu", "MeoLoadingFeedback",
        ):
            self.assertIn(token, launcher)

    def test_primary_product_qml_has_no_literal_hex_palette(self):
        surfaces = (
            "qml/MeoKDE/FrostedSurface.qml",
            "qml/MeoKDE/ShellTriggerSurface.qml",
            "qml/MeoKDE/StatusCenterView.qml",
            "qml/MeoKDE/NotificationCenterView.qml",
            "plasmoids/org.meo.topbar/contents/ui/QuickSettingsCenter.qml",
            "plasmoids/org.meo.topbar/contents/ui/QuickSettingsHome.qml",
            "plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml",
        )
        literal = re.compile(r'#[0-9A-Fa-f]{3,8}')
        for path in surfaces:
            self.assertIsNone(literal.search(read(path)), path)

    def test_native_and_plasma_renderers_share_semantic_material_roles(self):
        style = read("native/application-style/src/meostyle.cpp")
        viewitems = read("tools/theme/build_viewitem_assets.py")
        menubar = read("tools/theme/build_menubar_assets.py")

        self.assertIn("Meo::DesignTokens::", style)
        self.assertIn("QPalette::", style)
        self.assertIn("PE_PanelMenu", style)
        self.assertNotRegex(style, r'#[0-9A-Fa-f]{3,8}')

        for token in (
            "ColorScheme-ButtonBackground",
            "ColorScheme-ButtonHover",
            "ColorScheme-Highlight",
        ):
            self.assertIn(token, viewitems)
        self.assertIn("ColorScheme-Highlight", menubar)

    def test_kde_behaviour_stays_native_while_meo_owns_presentation(self):
        layout = read(
            "themes/look-and-feel/org.meo.desktop/contents/layouts/"
            "org.kde.plasma.desktop-layout.js"
        )
        for plugin in (
            "org.meo.systemmenu",
            "org.kde.plasma.appmenu",
            "org.kde.plasma.systemtray",
        ):
            self.assertIn(plugin, layout)

        # KDE owns tasks; the Meo pair only supplies launcher/search actions.
        self.assertIn('org.kde.plasma.icontasks', layout)
        self.assertIn('tasks.writeConfig("fill", false)', layout)

        launcher = read("plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml")
        self.assertIn("Kicker.RootModel", launcher)
        self.assertIn("Kicker.RunnerModel", launcher)
        self.assertIn("MeoContextMenu", launcher)

    def test_lock_screen_keeps_caelestia_lineage_but_meo_visual_identity(self):
        documentation = read("docs/LOCKSCREEN.md")

        self.assertIn("caelestia-dots/shell", documentation)
        self.assertIn("Material 3 roles as MeoUI", documentation)
        self.assertIn("Comfortaa", documentation)
        self.assertIn("Roboto", documentation)
        self.assertIn("Material Symbols Rounded", documentation)

    def test_material_shell_contract_documents_reference_boundaries(self):
        documentation = read("docs/design/MATERIAL_SHELL_CONTRACT.md")

        self.assertIn("Caelestia", documentation)
        self.assertIn("end-4", documentation)
        self.assertIn("MeoUI + Material 3", documentation)
        self.assertIn("Reference shells are inspiration, not a second design system", documentation)
        self.assertIn("Native behavior stays native", documentation)


if __name__ == "__main__":
    unittest.main()
