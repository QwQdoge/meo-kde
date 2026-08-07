import configparser
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMES = ROOT / "themes" / "color-schemes"
DESKTOP_THEMES = ROOT / "themes" / "desktoptheme"
REQUIRED = {
    "Colors:Button", "Colors:Complementary", "Colors:Header", "Colors:Selection",
    "Colors:Tooltip", "Colors:View", "Colors:Window", "General", "KDE", "WM",
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

    def test_modes_are_visibly_distinct(self):
        values = {}
        for name in ("MeoLight", "MeoDark"):
            parser = configparser.ConfigParser(interpolation=None)
            parser.read(SCHEMES / f"{name}.colors", encoding="utf-8")
            values[name] = parser["Colors:Window"]["BackgroundNormal"]
        self.assertNotEqual(values["MeoLight"], values["MeoDark"])

    def test_matching_plasma_themes_ship_the_matching_scheme(self):
        for name in ("MeoLight", "MeoDark"):
            root = DESKTOP_THEMES / name
            metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
            self.assertEqual(metadata["KPlugin"]["Id"], name)
            self.assertTrue((root / "colors").is_file())
            self.assertTrue((root / "widgets" / "background.svg").is_file())


if __name__ == "__main__":
    unittest.main()
