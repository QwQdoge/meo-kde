"""The top status bar is clear; the bottom Shelf keeps a tinted surface."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PanelBackgroundContract(unittest.TestCase):
    def test_top_edge_frame_is_clear_and_bottom_is_tinted(self):
        for theme in ("MeoLight", "MeoDark"):
            for rel in ("widgets", "translucent/widgets"):
                svg = (ROOT / "themes/desktoptheme" / theme / rel / "panel-background.svg").read_text()
                groups = re.findall(r'<g class="ColorScheme-ButtonBackground" fill="currentColor" fill-opacity="([0-9.]+)">(.*?)</g>', svg, re.S)
                self.assertEqual(len(groups), 2, (theme, rel))
                tinted = [g for g in groups if 'id="south-center"' in g[1]]
                clear = [g for g in groups if 'id="north-center"' in g[1]]
                self.assertEqual(len(tinted), 1)
                self.assertEqual(len(clear), 1)
                self.assertGreater(float(tinted[0][0]), 0.3)
                self.assertEqual(float(clear[0][0]), 0.0)
                self.assertNotIn('id="north-', tinted[0][1])


if __name__ == "__main__":
    unittest.main()
