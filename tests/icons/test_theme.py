import os
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
THEMES = {
    "MeoSymbols": "#232629",
    "MeoSymbolsDark": "#fcfcfc",
}


class MeoSymbolsThemeTests(unittest.TestCase):
    def test_index_and_declared_directories_exist(self):
        for theme_name in THEMES:
            theme = ROOT / "themes" / "icons" / theme_name
            index = theme / "index.theme"
            self.assertTrue(index.is_file())
            text = index.read_text(encoding="utf-8")
            for directory in text.split("Directories=", 1)[1].splitlines()[0].split(","):
                self.assertTrue((theme / directory).is_dir(), f"{theme_name}/{directory}")

    def test_core_icons_resolve(self):
        expected = [
            "places/folder.svg", "actions/document-open.svg", "actions/document-save.svg",
            "status/network-wireless.svg", "status/bluetooth-active.svg",
            "status/audio-volume-high.svg", "status/audio-volume-muted.svg",
            "status/battery-100.svg", "actions/system-shutdown.svg",
            "actions/system-reboot.svg", "categories/preferences-system.svg",
            "actions/edit-copy.svg", "actions/edit-paste.svg", "actions/edit-delete.svg",
        ]
        for theme_name in THEMES:
            theme = ROOT / "themes" / "icons" / theme_name
            for relative in expected:
                self.assertTrue((theme / "scalable" / relative).is_file(), f"{theme_name}/{relative}")

    def test_svg_assets_are_safe_and_theme_colored(self):
        for theme_name, fallback_color in THEMES.items():
            theme = ROOT / "themes" / "icons" / theme_name
            for svg in theme.rglob("*.svg"):
                if svg.is_symlink():
                    self.assertTrue(svg.resolve().exists(), svg)
                    continue
                root = ET.parse(svg).getroot()
                self.assertTrue(root.get("viewBox"), svg)
                payload = svg.read_text(encoding="utf-8").lower()
                self.assertIn('id="current-color-scheme"', payload, svg)
                self.assertIn('class="colorscheme-text"', payload, svg)
                self.assertIn('fill="currentcolor"', payload, svg)
                self.assertIn(fallback_color, payload, svg)
                self.assertNotIn("<script", payload)
                self.assertNotIn("data:image", payload)
                payload_without_namespace = payload.replace("http://www.w3.org/2000/svg", "")
                self.assertNotIn("http://", payload_without_namespace)
                self.assertNotIn("https://", payload_without_namespace)


if __name__ == "__main__":
    unittest.main()
