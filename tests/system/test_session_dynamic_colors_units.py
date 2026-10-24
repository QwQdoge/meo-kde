import configparser
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / "defaults/systemd"


def unit(name):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read_string((UNITS / name).read_text(encoding="utf-8"))
    return parser


class SessionDynamicColorsUnitTests(unittest.TestCase):
    def test_units_only_run_in_the_isolated_meo_session(self):
        for name in ("meo-session-dynamic-colors.service", "meo-session-dynamic-colors.path"):
            with self.subTest(name=name):
                self.assertEqual(unit(name)["Unit"]["ConditionEnvironment"], "MEO_DESKTOP_SESSION=1")

    def test_path_watches_the_session_config_home_not_the_ordinary_one(self):
        text = (UNITS / "meo-session-dynamic-colors.path").read_text(encoding="utf-8")
        for key in ("plasma-org.meo.shell-appletsrc", "kdeglobals", "meo-dynamic-colorsrc"):
            self.assertIn(f"PathChanged=%h/.config/meo-desktop/{key}", text)
        self.assertNotIn("PathChanged=%h/.config/kdeglobals", text)
        self.assertEqual(unit("meo-session-dynamic-colors.path")["Path"]["Unit"],
                         "meo-session-dynamic-colors.service")

    def test_service_uses_packaged_binaries_and_is_started_with_the_session(self):
        service = unit("meo-session-dynamic-colors.service")
        self.assertEqual(service["Service"]["ExecStart"], "/usr/bin/meo-dynamic-colors --follow-meo --apply")
        self.assertNotIn(".local/bin", (UNITS / "meo-session-dynamic-colors.service").read_text())
        self.assertEqual(service["Install"]["WantedBy"], "graphical-session.target")

    def test_ordinary_plasma_units_are_unchanged(self):
        # The pre-existing units stay for manual/source installs; the packaged
        # session uses the session-specific ones.
        self.assertIn("PathChanged=%h/.config/kdeglobals", (UNITS / "meo-dynamic-colors.path").read_text())


if __name__ == "__main__":
    unittest.main()
