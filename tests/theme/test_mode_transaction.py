import configparser
import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "theme" / "apply-meo-mode.sh"


def read_value(path: Path, group: str, key: str) -> str:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    return parser[group][key]


class MeoModeTransactionTests(unittest.TestCase):
    def _fixture(self, root: Path, fail_target_theme: bool):
        config = root / "config"
        data = root / "data"
        fake_bin = root / "bin"
        config.mkdir()
        fake_bin.mkdir()
        (data / "plasma/desktoptheme/MeoDark").mkdir(parents=True)
        (data / "color-schemes").mkdir(parents=True)
        (data / "icons/MeoSymbolsDark").mkdir(parents=True)
        (data / "color-schemes/MeoDark.colors").write_text("[General]\nColorScheme=MeoDark\n", encoding="utf-8")
        (data / "icons/MeoSymbolsDark/index.theme").write_text("[Icon Theme]\nName=MeoSymbolsDark\n", encoding="utf-8")
        (config / "kdeglobals").write_text(
            "[General]\nColorScheme=BreezeLight\n\n[Icons]\nTheme=Breeze\n",
            encoding="utf-8",
        )
        (config / "plasmarc").write_text("[Theme]\nname=breeze\n", encoding="utf-8")

        helper = fake_bin / "meo-fake-theme-command"
        helper.write_text(
            textwrap.dedent(
                f"""\
                #!/usr/bin/env python3
                import configparser
                import os
                import sys
                from pathlib import Path

                name = Path(sys.argv[0]).name
                config_root = Path(os.environ["XDG_CONFIG_HOME"])

                def set_value(path, group, key, value=None, delete=False):
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

                if name == "plasma-apply-colorscheme":
                    set_value(config_root / "kdeglobals", "General", "ColorScheme", sys.argv[1])
                elif name == "plasma-apply-desktoptheme":
                    theme = sys.argv[1]
                    if {str(fail_target_theme)} and theme == "MeoDark":
                        sys.exit(42)
                    set_value(config_root / "plasmarc", "Theme", "name", theme)
                elif name == "kwriteconfig6":
                    args = sys.argv[1:]
                    file = Path(args[args.index("--file") + 1])
                    group = args[args.index("--group") + 1]
                    key = args[args.index("--key") + 1]
                    delete = "--delete" in args
                    value = None if delete else args[args.index("--key") + 2]
                    set_value(file, group, key, value, delete)
                elif name == "meo-dynamic-colors":
                    pass
                """
            ),
            encoding="utf-8",
        )
        helper.chmod(helper.stat().st_mode | stat.S_IXUSR)
        for name in (
            "plasma-apply-colorscheme",
            "plasma-apply-desktoptheme",
            "kwriteconfig6",
            "meo-dynamic-colors",
        ):
            (fake_bin / name).symlink_to(helper.name)

        env = os.environ.copy()
        env.update(
            {
                "HOME": str(root),
                "XDG_CONFIG_HOME": str(config),
                "XDG_DATA_HOME": str(data),
                "PATH": f"{fake_bin}:{env['PATH']}",
                "MEO_DYNAMIC_COLORS_HELPER": str(fake_bin / "meo-dynamic-colors"),
            }
        )
        return config, env

    def test_failure_rolls_back_all_owned_mode_state(self):
        with tempfile.TemporaryDirectory() as directory:
            config, env = self._fixture(Path(directory), fail_target_theme=True)
            completed = subprocess.run(
                ["bash", str(SCRIPT), "dark"],
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("restoring the previous presentation state", completed.stderr)
            self.assertEqual(read_value(config / "kdeglobals", "General", "ColorScheme"), "BreezeLight")
            self.assertEqual(read_value(config / "plasmarc", "Theme", "name"), "breeze")
            self.assertEqual(read_value(config / "kdeglobals", "Icons", "Theme"), "Breeze")

    def test_success_commits_target_plasma_and_icon_state(self):
        with tempfile.TemporaryDirectory() as directory:
            config, env = self._fixture(Path(directory), fail_target_theme=False)
            completed = subprocess.run(
                ["bash", str(SCRIPT), "dark"],
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(read_value(config / "plasmarc", "Theme", "name"), "MeoDark")
            self.assertEqual(read_value(config / "kdeglobals", "Icons", "Theme"), "MeoSymbolsDark")

    def test_script_has_signal_and_error_rollback_boundary(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("trap on_error ERR", source)
        self.assertIn("trap on_signal INT TERM HUP", source)
        self.assertIn("rollback_mode_transaction", source)
        self.assertIn("applied_desktop_theme", source)
        self.assertIn("applied_icon_theme", source)


if __name__ == "__main__":
    unittest.main()
