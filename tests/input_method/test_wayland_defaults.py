import configparser
import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
KWIN_DEFAULTS = ROOT / "defaults" / "kwin" / "kwinrc"
ENVIRONMENT_DEFAULTS = ROOT / "defaults" / "environment" / "90-meo-applications.conf"
APPLY_DESKTOP = ROOT / "tools" / "theme" / "apply-meo-desktop.sh"


def read_config(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    return parser


class FcitxWaylandDefaultTests(unittest.TestCase):
    def test_kwin_owns_default_fcitx_wayland_launch(self):
        parser = read_config(KWIN_DEFAULTS)
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

    def _run_kwin_only_apply(self, initial_kwinrc: str) -> configparser.ConfigParser:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_root = root / "config"
            fake_bin = root / "bin"
            config_root.mkdir()
            fake_bin.mkdir()
            kwinrc = config_root / "kwinrc"
            kwinrc.write_text(initial_kwinrc, encoding="utf-8")

            helper = fake_bin / "kwriteconfig6"
            helper.write_text(
                textwrap.dedent(
                    """\
                    #!/usr/bin/env python3
                    import configparser
                    import sys
                    from pathlib import Path

                    args = sys.argv[1:]
                    path = Path(args[args.index("--file") + 1])
                    group = args[args.index("--group") + 1]
                    key = args[args.index("--key") + 1]
                    delete = "--delete" in args
                    value = "" if delete else args[args.index("--key") + 2]

                    parser = configparser.ConfigParser(interpolation=None)
                    parser.optionxform = str
                    if path.exists():
                        parser.read(path, encoding="utf-8")
                    if not parser.has_section(group):
                        parser.add_section(group)
                    if delete:
                        parser.remove_option(group, key)
                    else:
                        parser.set(group, key, value)
                    with path.open("w", encoding="utf-8") as handle:
                        parser.write(handle, space_around_delimiters=False)
                    """
                ),
                encoding="utf-8",
            )
            helper.chmod(helper.stat().st_mode | stat.S_IXUSR)

            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(root),
                    "XDG_CONFIG_HOME": str(config_root),
                    "PATH": f"{fake_bin}:{env['PATH']}",
                    "MEO_KWIN_DEFAULTS": str(KWIN_DEFAULTS),
                }
            )
            completed = subprocess.run(
                ["bash", str(APPLY_DESKTOP), "--kwin-only", "--no-backup", "--quiet"],
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            parser = read_config(kwinrc)
            # Copy the parsed state before TemporaryDirectory removes the file.
            snapshot = configparser.ConfigParser(interpolation=None)
            snapshot.optionxform = str
            for section in parser.sections():
                snapshot.add_section(section)
                for key, value in parser[section].items():
                    snapshot.set(section, key, value)
            return snapshot

    def test_appearance_apply_preserves_explicit_user_virtual_keyboard(self):
        parser = self._run_kwin_only_apply(
            "[Wayland]\nInputMethod=/custom/input-method.desktop\n"
        )
        self.assertEqual(
            parser["Wayland"]["InputMethod"],
            "/custom/input-method.desktop",
        )
        self.assertEqual(parser["Windows"]["FocusPolicy"], "ClickToFocus")

    def test_appearance_apply_does_not_pin_system_default_into_user_config(self):
        parser = self._run_kwin_only_apply("")
        self.assertTrue(parser.has_section("Wayland"))
        self.assertNotIn("InputMethod", parser["Wayland"])
        self.assertEqual(parser["Windows"]["FocusPolicy"], "ClickToFocus")


if __name__ == "__main__":
    unittest.main()
