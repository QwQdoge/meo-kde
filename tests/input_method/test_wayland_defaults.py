import configparser
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
KWIN_DEFAULTS = ROOT / "defaults" / "kwin" / "kwinrc"
ENVIRONMENT_DEFAULTS = ROOT / "defaults" / "environment" / "90-meo-applications.conf"


class FcitxWaylandDefaultTests(unittest.TestCase):
    def test_kwin_owns_default_fcitx_wayland_launch(self):
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser.read(KWIN_DEFAULTS, encoding="utf-8")
        self.assertEqual(
            parser["Wayland"]["InputMethod"],
            "/usr/share/applications/org.fcitx.Fcitx5.desktop",
        )

    def test_native_wayland_does_not_force_toolkit_im_modules(self):
        source = ENVIRONMENT_DEFAULTS.read_text(encoding="utf-8")
        active = [
            line.strip()
            for line in source.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertIn("XMODIFIERS=@im=fcitx", active)
        self.assertFalse(any(line.startswith("QT_IM_MODULE=") for line in active))
        self.assertFalse(any(line.startswith("GTK_IM_MODULE=") for line in active))

    def test_default_is_user_overridable_not_an_autostart_duplicate(self):
        kwin = KWIN_DEFAULTS.read_text(encoding="utf-8")
        environment = ENVIRONMENT_DEFAULTS.read_text(encoding="utf-8")
        combined = kwin + "\n" + environment
        self.assertNotIn("autostart/org.fcitx", combined)
        self.assertNotIn("systemctl --user", combined)
        self.assertNotIn("Exec=/usr/bin/fcitx5", combined)


if __name__ == "__main__":
    unittest.main()
