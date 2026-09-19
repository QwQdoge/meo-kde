import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/theme/apply-meo-mode.sh"


class ApplyMeoModeTest(unittest.TestCase):
    def test_mode_switch_preserves_active_application_overlay(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            config.mkdir()
            (config / "kdeglobals").write_text(
                "[Icons]\nTheme=MeoUserDark\n", encoding="utf-8")
            for name in ("MeoUser", "MeoUserDark"):
                index = data / "icons" / name / "index.theme"
                index.parent.mkdir(parents=True, exist_ok=True)
                index.write_text("[Icon Theme]\n", encoding="utf-8")
            environment = dict(os.environ, XDG_CONFIG_HOME=str(config),
                               XDG_DATA_HOME=str(data))
            result = subprocess.run([str(SCRIPT), "light", "--dry-run"],
                                    text=True, capture_output=True, check=True,
                                    env=environment)
            self.assertIn("Theme MeoUser", result.stdout)
            self.assertNotIn("Theme MeoSymbols\n", result.stdout)

    def test_mode_switch_does_not_claim_missing_overlay_is_active(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            config.mkdir()
            (config / "kdeglobals").write_text(
                "[Icons]\nTheme=MeoUser\n", encoding="utf-8")
            environment = dict(os.environ, XDG_CONFIG_HOME=str(config),
                               XDG_DATA_HOME=str(root / "data"))
            result = subprocess.run([str(SCRIPT), "dark", "--dry-run"],
                                    text=True, capture_output=True, check=True,
                                    env=environment)
            self.assertIn("Theme MeoSymbolsDark", result.stdout)
            self.assertIn("overlay is active", result.stderr)


if __name__ == "__main__":
    unittest.main()
