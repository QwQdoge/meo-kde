from pathlib import Path
import configparser
import unittest


ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "data/wayland-sessions/meo.desktop"
LAUNCHER = ROOT / "tools/session/startmeo-wayland"
LEGACY_SESSION = ROOT / "defaults/sessions/meoarch-wayland.desktop"
PKGBUILD = ROOT / "packaging/arch/PKGBUILD"


class MeoArchWaylandSessionTests(unittest.TestCase):
    def test_single_isolated_session_entry(self):
        entry = configparser.ConfigParser(interpolation=None)
        entry.optionxform = str
        entry.read_string(SESSION.read_text(encoding="utf-8"))
        desktop = entry["Desktop Entry"]
        self.assertEqual(desktop["Name"], "Meo Desktop")
        self.assertEqual(desktop["Exec"], "/usr/bin/startmeo-wayland")
        self.assertEqual(desktop["TryExec"], "/usr/bin/startmeo-wayland")
        self.assertIn("Meo", desktop["DesktopNames"].split(";"))

    def test_launcher_isolates_configuration_from_plain_plasma(self):
        content = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn('XDG_CONFIG_HOME="${meo_config_home}"', content)
        self.assertIn("PLASMA_DEFAULT_SHELL=org.meo.shell", content)
        self.assertIn("startplasma-wayland", content)

    def test_no_second_session_entry_named_meo_desktop(self):
        # A plain `startplasma-wayland` entry under the same display name would
        # show two "Meo Desktop" choices in the login screen and one of them
        # would share the ordinary Plasma configuration.
        self.assertFalse(LEGACY_SESSION.exists())
        recipe = PKGBUILD.read_text(encoding="utf-8")
        self.assertNotIn("meoarch-wayland.desktop", recipe)
        self.assertNotIn("usr/share/wayland-sessions/", recipe.replace("# ", ""))


if __name__ == "__main__":
    unittest.main()
