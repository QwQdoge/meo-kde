import configparser
import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMES = ROOT / "themes" / "color-schemes"
DESKTOP_THEMES = ROOT / "themes" / "desktoptheme"
REQUIRED = {
    "Colors:Button", "Colors:Complementary", "Colors:Header", "Colors:Selection",
    "Colors:Tooltip", "Colors:View", "Colors:Window", "General", "KDE", "MeoMaterial", "WM",
}
MATERIAL_ROLES = {
    "surfaceContainer", "onSurface", "primary", "onPrimary",
    "primaryContainer", "onPrimaryContainer", "secondaryContainer",
    "onSecondaryContainer", "onSurfaceVariant", "outline",
}


class MeoColorSchemeTests(unittest.TestCase):
    def test_light_and_dark_have_complete_kde_roles(self):
        for name in ("MeoLight", "MeoDark"):
            parser = configparser.ConfigParser(interpolation=None)
            parser.read(SCHEMES / f"{name}.colors", encoding="utf-8")
            self.assertTrue(REQUIRED.issubset(parser.sections()), name)
            self.assertEqual(parser["General"]["ColorScheme"], name)
            for role in ("Colors:Button", "Colors:Header", "Colors:Selection", "Colors:View", "Colors:Window"):
                for key in ("BackgroundNormal", "ForegroundNormal", "DecorationFocus"):
                    self.assertRegex(parser[role][key], r"^\d{1,3},\d{1,3},\d{1,3}$")
            self.assertEqual(set(parser["MeoMaterial"]), {key.lower() for key in MATERIAL_ROLES})
            for key in MATERIAL_ROLES:
                self.assertRegex(parser["MeoMaterial"][key], r"^\d{1,3},\d{1,3},\d{1,3}$")

    def test_modes_are_visibly_distinct(self):
        values = {}
        for name in ("MeoLight", "MeoDark"):
            parser = configparser.ConfigParser(interpolation=None)
            parser.read(SCHEMES / f"{name}.colors", encoding="utf-8")
            values[name] = parser["Colors:Window"]["BackgroundNormal"]
        self.assertNotEqual(values["MeoLight"], values["MeoDark"])

    def test_plasma_surfaces_follow_the_active_system_scheme(self):
        for name in ("MeoLight", "MeoDark"):
            root = DESKTOP_THEMES / name
            metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
            self.assertEqual(metadata["KPlugin"]["Id"], name)
            # Plasma uses a style-local color scheme whenever this file is
            # present. Omitting it is intentional: the CSS classes below then
            # resolve against the active static or generated KDE scheme.
            self.assertFalse((root / "colors").exists())
            for relative in (
                "widgets/background.svg",
                "widgets/panel-background.svg",
                "dialogs/background.svg",
                "translucent/widgets/background.svg",
                "translucent/widgets/panel-background.svg",
                "translucent/dialogs/background.svg",
            ):
                svg = (root / relative).read_text(encoding="utf-8")
                self.assertIn('id="current-color-scheme"', svg, relative)
                self.assertIn("ColorScheme-Background", svg, relative)
                self.assertIn('fill="currentColor"', svg, relative)

    def test_generated_task_frames_are_current(self):
        subprocess.run(
            ["python", str(ROOT / "tools/theme/build_task_frames.py"), "--check"],
            check=True,
        )

    def test_generated_floating_dock_assets_are_current(self):
        subprocess.run(
            ["python", str(ROOT / "tools/theme/build_floating_dock_assets.py"), "--check"],
            check=True,
        )

if __name__ == "__main__":
    unittest.main()
