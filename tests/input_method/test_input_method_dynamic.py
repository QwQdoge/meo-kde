from __future__ import annotations

import configparser
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tools/input-method/meo-input-method.sh"
ROLE_RGB = {
    "surfaceContainer": "1,2,3",
    "onSurface": "17,18,19",
    "primary": "33,34,35",
    "onPrimary": "49,50,51",
    "primaryContainer": "65,66,67",
    "onPrimaryContainer": "81,82,83",
    "secondaryContainer": "97,98,99",
    "onSecondaryContainer": "113,114,115",
    "onSurfaceVariant": "129,130,131",
    "outline": "145,146,147",
}


def rgb_to_hex(value: str) -> str:
    red, green, blue = map(int, value.split(","))
    return f"#{red:02x}{green:02x}{blue:02x}"


class InputMethodDynamicTests(unittest.TestCase):
    def make_fake_tools(self, root: Path) -> None:
        root.mkdir(parents=True)
        scripts = {
            "fcitx5": "#!/bin/sh\nexit 0\n",
            "fcitx5-remote": """#!/bin/sh
printf 'fcitx5-remote %s\\n' "$*" >> "${MEO_TEST_LOG:-/dev/null}"
[ "${1:-}" = "--check" ] && [ "${MEO_TEST_FCITX_RUNNING:-0}" = "1" ]
""",
            "ibus-daemon": "#!/bin/sh\nexit 0\n",
            "pgrep": """#!/bin/sh
[ "${MEO_TEST_IBUS_RUNNING:-0}" = "1" ] && [ "${1:-}" = "-x" ] && [ "${2:-}" = "ibus-daemon" ]
""",
            "gsettings": """#!/bin/sh
if [ "${1:-}" = "get" ]; then
  case "${3:-}" in
    custom-theme) printf '%s\\n' "${MEO_TEST_IBUS_THEME:-'OtherTheme'}" ;;
    use-custom-theme) printf '%s\\n' "${MEO_TEST_IBUS_ENABLED:-false}" ;;
  esac
  exit 0
fi
if [ "${1:-}" = "set" ]; then
  printf 'gsettings %s\\n' "$*" >> "${MEO_TEST_LOG:-/dev/null}"
  [ "${MEO_TEST_GSETTINGS_FAIL:-0}" != "1" ]
  exit
fi
exit 1
""",
            "busctl": """#!/bin/sh
printf 'busctl %s\\n' "$*" >> "${MEO_TEST_LOG:-/dev/null}"
case "$*" in
  *ReloadAddonConfig*) [ "${MEO_TEST_BUSCTL_RELOAD_FAIL:-0}" != "1" ]; exit ;;
  *GetConfig*)
    [ "${MEO_TEST_BUSCTL_GET_FAIL:-0}" = "1" ] && exit 1
    printf '%s\\n' "${MEO_TEST_BUSCTL_CONFIG}"
    exit 0
    ;;
esac
exit 1
""",
        }
        for name, content in scripts.items():
            target = root / name
            target.write_text(content, encoding="utf-8")
            target.chmod(0o755)

    def environment(
        self, temporary: Path, roles: dict[str, str] | None = None
    ) -> tuple[dict[str, str], Path]:
        fake_bin = temporary / "bin"
        self.make_fake_tools(fake_bin)
        colors = temporary / "colors"
        colors.mkdir()
        role_values = ROLE_RGB if roles is None else roles
        scheme = colors / "UnitScheme.colors"
        scheme.write_text(
            "[General]\nColorScheme=UnitScheme\n\n[MeoMaterial]\n"
            + "".join(f"{key}={value}\n" for key, value in role_values.items()),
            encoding="utf-8",
        )
        log = temporary / "commands.log"
        env = os.environ | {
            "HOME": str(temporary / "home"),
            "XDG_CONFIG_HOME": str(temporary / "config"),
            "XDG_DATA_HOME": str(temporary / "data"),
            "XDG_CONFIG_DIRS": str(temporary / "system-config"),
            "XDG_DATA_DIRS": str(temporary / "system-data"),
            "MEO_INPUT_METHOD_RESOURCE_ROOT": str(ROOT / "themes/input-method"),
            "MEO_INPUT_METHOD_COLOR_SCHEME_ROOT": str(colors),
            "MEO_INPUT_METHOD_COLOR_SCHEME": "UnitScheme",
            "MEO_TEST_LOG": str(log),
            "MEO_TEST_FCITX_RUNNING": "0",
            "MEO_TEST_IBUS_RUNNING": "0",
            "MEO_TEST_IBUS_THEME": "'OtherTheme'",
            "MEO_TEST_IBUS_ENABLED": "false",
            "MEO_TEST_BUSCTL_CONFIG": (
                'a{sv} 3 "Theme" s "MeoInputMethod-Dynamic" '
                '"DarkTheme" s "MeoInputMethod-Dynamic" "UseDarkTheme" s "True"'
            ),
            "PATH": f"{fake_bin}:/usr/bin:/bin",
        }
        return env, log

    def assert_dynamic_theme(self, root: Path) -> None:
        roles = {key: rgb_to_hex(value) for key, value in ROLE_RGB.items()}
        theme = configparser.ConfigParser(interpolation=None)
        theme.read(root / "theme.conf", encoding="utf-8")
        panel = theme["InputPanel"]
        self.assertEqual(panel["NormalColor"], roles["onSurface"])
        self.assertEqual(panel["HighlightColor"], roles["onSecondaryContainer"])
        self.assertEqual(panel["HighlightBackgroundColor"], roles["secondaryContainer"])
        self.assertEqual(panel["HighlightCandidateColor"], roles["onSecondaryContainer"])
        self.assertEqual(panel["CandidateLabelColor"], roles["onSurfaceVariant"])
        self.assertEqual(theme["InputPanel/PrevPage"]["Image"], "prev.svg")
        self.assertEqual(theme["InputPanel/NextPage"]["Image"], "next.svg")
        self.assertEqual(theme["Menu"]["NormalColor"], roles["onSurface"])
        self.assertEqual(
            theme["Menu"]["HighlightCandidateColor"], roles["onPrimaryContainer"]
        )
        self.assertEqual(theme["Menu/Separator"]["Color"], roles["outline"])
        self.assertNotIn("AccentColorField", theme)
        namespace = {"svg": "http://www.w3.org/2000/svg"}
        expected = {
            "panel.svg": ("rect", "fill", roles["surfaceContainer"]),
            "highlight.svg": ("rect", "fill", roles["secondaryContainer"]),
            "menu-highlight.svg": ("rect", "fill", roles["primaryContainer"]),
            "prev.svg": ("path", "stroke", roles["onSurfaceVariant"]),
            "next.svg": ("path", "stroke", roles["onSurfaceVariant"]),
            "check.svg": ("path", "stroke", roles["onSurfaceVariant"]),
            "submenu.svg": ("path", "stroke", roles["onSurfaceVariant"]),
        }
        for filename, (tag, attribute, value) in expected.items():
            node = ET.parse(root / filename).getroot().find(f"svg:{tag}", namespace)
            self.assertIsNotNone(node, filename)
            assert node is not None
            self.assertEqual(node.attrib[attribute], value, filename)
        panel_rect = ET.parse(root / "panel.svg").getroot().find("svg:rect", namespace)
        assert panel_rect is not None
        self.assertEqual(panel_rect.attrib["stroke"], roles["outline"])

    def test_enable_fcitx_preserves_native_options_and_selects_dynamic(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, _ = self.environment(temporary)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text(
                "Vertical Candidate List=True\nFont=User Font 13\n"
                "WheelForPaging=False\nUseAccentColor=True\n",
                encoding="utf-8",
            )
            subprocess.run(
                ["bash", str(HELPER), "--enable", "fcitx5", "--quiet"],
                check=True,
                env=env,
            )
            output = config.read_text(encoding="utf-8")
            for preserved in (
                "Vertical Candidate List=True",
                "Font=User Font 13",
                "WheelForPaging=False",
                "UseAccentColor=True",
            ):
                self.assertIn(preserved, output)
            self.assertIn("Theme=MeoInputMethod-Dynamic", output)
            self.assertIn("DarkTheme=MeoInputMethod-Dynamic", output)
            self.assertIn("UseDarkTheme=True", output)
            self.assert_dynamic_theme(
                temporary / "data/fcitx5/themes/MeoInputMethod-Dynamic"
            )

    def test_sync_rewrites_only_slots_already_selecting_meo(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text(
                "Theme=MeoInputMethod-Light\nDarkTheme=ThirdPartyDark\n"
                "Vertical Candidate List=True\n",
                encoding="utf-8",
            )
            subprocess.run(["bash", str(HELPER), "--sync"], check=True, env=env)
            output = config.read_text(encoding="utf-8")
            self.assertIn("Theme=MeoInputMethod-Dynamic", output)
            self.assertIn("DarkTheme=ThirdPartyDark", output)
            self.assertIn("Vertical Candidate List=True", output)
            self.assertNotIn("UseDarkTheme=", output)
            self.assert_dynamic_theme(
                temporary / "data/fcitx5/themes/MeoInputMethod-Dynamic"
            )
            commands = log.read_text(encoding="utf-8") if log.exists() else ""
            self.assertNotIn("gsettings set", commands)
            self.assertNotIn("ReloadAddonConfig", commands)

    def test_sync_promotes_system_meo_fallbacks_without_copying_other_options(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, _ = self.environment(temporary)
            system_config = temporary / "system-config/fcitx5/conf/classicui.conf"
            system_config.parent.mkdir(parents=True)
            system_config.write_text(
                "Theme=MeoInputMethod-Light\nDarkTheme=MeoInputMethod-Dark\n"
                "UseDarkTheme=True\nFont=System Default 10\n",
                encoding="utf-8",
            )
            subprocess.run(
                ["bash", str(HELPER), "--sync", "--quiet"], check=True, env=env
            )
            user_config = temporary / "config/fcitx5/conf/classicui.conf"
            output = user_config.read_text(encoding="utf-8")
            self.assertIn("Theme=MeoInputMethod-Dynamic", output)
            self.assertIn("DarkTheme=MeoInputMethod-Dynamic", output)
            self.assertNotIn("Font=", output)
            self.assertNotIn("UseDarkTheme=", output)

    def test_sync_leaves_non_meo_framework_selections_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            original = "Theme=ThirdParty\nDarkTheme=ThirdPartyDark\nUseDarkTheme=False\n"
            config.write_text(original, encoding="utf-8")
            subprocess.run(["bash", str(HELPER), "--sync"], check=True, env=env)
            self.assertEqual(config.read_text(encoding="utf-8"), original)
            self.assertFalse((temporary / "data/fcitx5/themes").exists())
            self.assertFalse((temporary / "data/themes").exists())
            commands = log.read_text(encoding="utf-8") if log.exists() else ""
            self.assertNotIn("gsettings set", commands)

    def test_missing_material_role_fails_before_theme_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            incomplete = dict(ROLE_RGB)
            incomplete.pop("onSecondaryContainer")
            env, _ = self.environment(temporary, incomplete)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text("Theme=MeoInputMethod-Light\n", encoding="utf-8")
            result = subprocess.run(
                ["bash", str(HELPER), "--sync"], capture_output=True, text=True, env=env
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing MeoMaterial/onSecondaryContainer", result.stderr)
            self.assertFalse(
                (temporary / "data/fcitx5/themes/MeoInputMethod-Dynamic/theme.conf").exists()
            )

    def test_ibus_render_uses_exact_material_roles(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            subprocess.run(
                ["bash", str(HELPER), "--enable", "ibus", "--quiet"],
                check=True,
                env=env,
            )
            css = (temporary / "data/themes/MeoInputMethod/gtk-3.0/gtk.css").read_text(
                encoding="utf-8"
            )
            roles = {key: rgb_to_hex(value) for key, value in ROLE_RGB.items()}
            self.assertNotIn("@MEO_", css)
            self.assertIn(f"theme_bg_color {roles['surfaceContainer']};", css)
            self.assertIn(f"theme_selected_bg_color {roles['secondaryContainer']};", css)
            self.assertIn(
                f"theme_selected_fg_color {roles['onSecondaryContainer']};", css
            )
            self.assertIn(f"meo_on_primary {roles['onPrimary']};", css)
            self.assertIn(
                f"meo_on_primary_container {roles['onPrimaryContainer']};", css
            )
            commands = log.read_text(encoding="utf-8")
            self.assertIn("use-custom-theme true", commands)
            self.assertIn("custom-theme MeoInputMethod", commands)

    def test_sync_reloads_only_an_already_selected_live_ibus_theme(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            env["MEO_TEST_IBUS_THEME"] = "'MeoInputMethod'"
            env["MEO_TEST_IBUS_RUNNING"] = "1"
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text("Theme=ThirdParty\n", encoding="utf-8")
            subprocess.run(
                ["bash", str(HELPER), "--sync", "--quiet"], check=True, env=env
            )
            commands = log.read_text(encoding="utf-8")
            self.assertIn("custom-theme Adwaita", commands)
            self.assertIn("custom-theme MeoInputMethod", commands)
            self.assertNotIn("use-custom-theme", commands)
            self.assertFalse((temporary / "data/fcitx5/themes").exists())

    def test_sync_refreshes_both_selected_meo_framework_themes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            env["MEO_TEST_IBUS_THEME"] = "'MeoInputMethod'"
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text(
                "Theme=MeoInputMethod-Light\nDarkTheme=MeoInputMethod-Dark\n",
                encoding="utf-8",
            )
            subprocess.run(
                ["bash", str(HELPER), "--sync", "--quiet"], check=True, env=env
            )
            self.assert_dynamic_theme(
                temporary / "data/fcitx5/themes/MeoInputMethod-Dynamic"
            )
            self.assertTrue(
                (temporary / "data/themes/MeoInputMethod/gtk-3.0/gtk.css").is_file()
            )
            output = config.read_text(encoding="utf-8")
            self.assertIn("Theme=MeoInputMethod-Dynamic", output)
            self.assertIn("DarkTheme=MeoInputMethod-Dynamic", output)
            commands = log.read_text(encoding="utf-8") if log.exists() else ""
            self.assertNotIn("gsettings set", commands)

    def test_fcitx_reload_and_get_config_are_both_verified(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            env["MEO_TEST_FCITX_RUNNING"] = "1"
            result = subprocess.run(
                ["bash", str(HELPER), "--enable", "fcitx5"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn("runtime theme selection verified", result.stdout)
            commands = log.read_text(encoding="utf-8")
            self.assertIn("ReloadAddonConfig s classicui", commands)
            self.assertIn("GetConfig s fcitx://config/addon/classicui", commands)
            self.assertLess(commands.index("ReloadAddonConfig"), commands.index("GetConfig"))

    def test_fcitx_runtime_mismatch_is_a_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, _ = self.environment(temporary)
            env["MEO_TEST_FCITX_RUNNING"] = "1"
            env["MEO_TEST_BUSCTL_CONFIG"] = (
                'a{sv} 3 "Theme" s "default" '
                '"DarkTheme" s "MeoInputMethod-Dynamic" "UseDarkTheme" s "True"'
            )
            result = subprocess.run(
                ["bash", str(HELPER), "--enable", "fcitx5"],
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("runtime verification failed: Theme", result.stderr)

    def test_unavailable_dbus_is_reported_without_remote_reload_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            env["MEO_TEST_FCITX_RUNNING"] = "1"
            env["MEO_TEST_BUSCTL_RELOAD_FAIL"] = "1"
            result = subprocess.run(
                ["bash", str(HELPER), "--enable", "fcitx5"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn("runtime was not verified", result.stderr)
            commands = log.read_text(encoding="utf-8")
            self.assertIn("fcitx5-remote --check", commands)
            self.assertNotIn("fcitx5-remote -r", commands)
            self.assertNotIn("GetConfig", commands)

    def test_get_config_failure_is_reported_after_successful_reload(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            env["MEO_TEST_FCITX_RUNNING"] = "1"
            env["MEO_TEST_BUSCTL_GET_FAIL"] = "1"
            result = subprocess.run(
                ["bash", str(HELPER), "--enable", "fcitx5"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn("GetConfig failed", result.stderr)
            self.assertIn("runtime selection was not verified", result.stderr)
            commands = log.read_text(encoding="utf-8")
            self.assertIn("ReloadAddonConfig", commands)
            self.assertIn("GetConfig", commands)
            self.assertNotIn("fcitx5-remote -r", commands)

    def test_status_reports_file_selection_without_reloading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            env, log = self.environment(temporary)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text(
                "Theme=MeoInputMethod-Dynamic\nDarkTheme=ThirdPartyDark\n"
                "UseDarkTheme=False\n",
                encoding="utf-8",
            )
            dynamic = temporary / "data/fcitx5/themes/MeoInputMethod-Dynamic"
            dynamic.mkdir(parents=True)
            (dynamic / "theme.conf").write_text("[Metadata]\nName=Unit\n", encoding="utf-8")
            result = subprocess.run(
                ["bash", str(HELPER), "--status"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn(f"Fcitx config source: {config}", result.stdout)
            self.assertIn("Fcitx Theme (file): MeoInputMethod-Dynamic", result.stdout)
            self.assertIn("Fcitx DarkTheme (file): ThirdPartyDark", result.stdout)
            self.assertIn("Fcitx UseDarkTheme (file): False", result.stdout)
            self.assertIn("Fcitx dynamic theme files: generated", result.stdout)
            commands = log.read_text(encoding="utf-8")
            self.assertNotIn("ReloadAddonConfig", commands)
            self.assertNotIn("gsettings set", commands)


if __name__ == "__main__":
    unittest.main()
