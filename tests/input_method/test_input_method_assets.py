from __future__ import annotations

import configparser
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]


class InputMethodAssetsTests(unittest.TestCase):
    def test_fcitx_defaults_only_select_capsule_themes(self) -> None:
        config = configparser.ConfigParser(interpolation=None)
        defaults = (ROOT / "defaults/input-method/fcitx5/conf/classicui.conf").read_text(
            encoding="utf-8"
        )
        config.read_string("[root]\n" + defaults)
        classic = config["root"]
        self.assertEqual(classic["Theme"], "MeoInputMethod-Light")
        self.assertEqual(classic["DarkTheme"], "MeoInputMethod-Dark")
        self.assertEqual(classic["UseDarkTheme"], "True")
        for untouched in (
            "Vertical Candidate List",
            "WheelForPaging",
            "Font",
            "MenuFont",
            "EnableFractionalScale",
            "UseAccentColor",
        ):
            self.assertNotIn(untouched, classic)

    def test_fcitx_capsule_assets_are_complete(self) -> None:
        sources = {
            "MeoInputMethod-Light": "MeoLight",
            "MeoInputMethod-Dark": "MeoDark",
        }
        for theme_name, scheme_name in sources.items():
            with self.subTest(theme=theme_name):
                scheme = configparser.ConfigParser(interpolation=None)
                scheme.read(
                    ROOT / "themes/color-schemes" / f"{scheme_name}.colors",
                    encoding="utf-8",
                )

                def role(group: str, key: str) -> str:
                    red, green, blue = map(int, scheme[group][key].split(","))
                    return f"#{red:02x}{green:02x}{blue:02x}"

                colors = {
                    "normal": role("Colors:Window", "ForegroundNormal"),
                    "selected": role("Colors:Selection", "BackgroundAlternate"),
                    "selected_text": role("Colors:Window", "ForegroundNormal"),
                    "panel": role("Colors:Window", "BackgroundAlternate"),
                }
                theme_root = ROOT / "themes/input-method/fcitx5" / theme_name
                config = configparser.ConfigParser(interpolation=None)
                config.read(theme_root / "theme.conf", encoding="utf-8")
                panel = config["InputPanel"]
                self.assertEqual(panel["NormalColor"], colors["normal"])
                self.assertEqual(panel["HighlightCandidateColor"], colors["selected_text"])
                self.assertEqual(config["InputPanel/Background"]["Image"], "panel.png")
                self.assertEqual(config["InputPanel/Highlight"]["Image"], "highlight.png")
                self.assertNotIn("AccentColorField", config)

                panel_svg = ET.parse(theme_root / "panel.svg").getroot()
                highlight_svg = ET.parse(theme_root / "highlight.svg").getroot()
                panel_rect = next(iter(panel_svg))
                highlight_rect = next(iter(highlight_svg))
                self.assertEqual(panel_rect.attrib["fill"], colors["panel"])
                self.assertNotIn("stroke", panel_rect.attrib)
                self.assertEqual(highlight_rect.attrib["fill"], colors["selected"])
                outer_radius = float(panel_rect.attrib["rx"])
                inner_radius = float(highlight_rect.attrib["rx"])
                self.assertEqual(outer_radius, 24)
                self.assertEqual(inner_radius, 17)
                self.assertEqual(outer_radius - inner_radius, 7)
                self.assertEqual(config["InputPanel/ContentMargin"]["Top"], "7")
                self.assertEqual(config["InputPanel/TextMargin"]["Top"], "8")
                self.assertEqual(config["InputPanel/TextMargin"]["Left"], "8")
                self.assertEqual(config["InputPanel/Background/Margin"]["Top"], "24")
                # Fcitx paints the highlight around the candidate's text
                # bounds. This value is padding, not a corner-radius token.
                self.assertEqual(config["InputPanel/Highlight/Margin"]["Top"], "8")
                font_height = 19
                popup_height = font_height + 2 * 8 + 2 * 7
                selected_height = font_height + 2 * 8
                self.assertEqual(popup_height, 49)
                self.assertEqual(selected_height, 35)

                for image, dimensions in (("panel.png", (50, 50)), ("highlight.png", (36, 36))):
                    with (theme_root / image).open("rb") as stream:
                        self.assertEqual(stream.read(8), b"\x89PNG\r\n\x1a\n")
                        stream.read(8)
                        self.assertEqual(struct.unpack(">II", stream.read(8)), dimensions)

    def test_ibus_template_uses_semantic_roles(self) -> None:
        template = (ROOT / "themes/input-method/ibus/gtk.css.in").read_text(encoding="utf-8")
        for role in (
            "@MEO_SURFACE@",
            "@MEO_SURFACE_CONTAINER@",
            "@MEO_ON_SURFACE@",
            "@MEO_PRIMARY@",
            "@MEO_SECONDARY_CONTAINER@",
            "@MEO_ON_SECONDARY_CONTAINER@",
            "@MEO_OUTLINE@",
            "@MEO_ON_SURFACE_VARIANT@",
        ):
            self.assertIn(role, template)
        self.assertIn("@define-color theme_selected_bg_color @MEO_SECONDARY_CONTAINER@;", template)
        self.assertIn("@define-color theme_selected_fg_color @MEO_ON_SECONDARY_CONTAINER@;", template)
        self.assertIn("#IBusCandidate", template)
        self.assertIn("border-radius: 24px;", template)
        self.assertIn("border-radius: 17px;", template)
        self.assertIn("padding: 7px;", template)
        self.assertNotIn("transition:", template)
        self.assertNotIn("animation:", template)
        self.assertNotRegex(template, r"#[0-9a-fA-F]{6}")

    def test_rendered_ibus_css_parses_when_gtk_is_available(self) -> None:
        try:
            import gi

            gi.require_version("Gtk", "3.0")
            from gi.repository import Gtk
        except (ImportError, ValueError):
            self.skipTest("GTK 3 GObject introspection is not installed")

        colors = configparser.ConfigParser(interpolation=None)
        colors.read(ROOT / "themes/color-schemes/MeoLight.colors", encoding="utf-8")

        def hex_role(group: str, key: str) -> str:
            red, green, blue = map(int, colors[group][key].split(","))
            return f"#{red:02x}{green:02x}{blue:02x}"

        values = {
            "@MEO_SURFACE@": hex_role("Colors:Window", "BackgroundNormal"),
            "@MEO_SURFACE_CONTAINER@": hex_role("Colors:Window", "BackgroundAlternate"),
            "@MEO_ON_SURFACE@": hex_role("Colors:Window", "ForegroundNormal"),
            "@MEO_PRIMARY@": hex_role("Colors:Selection", "BackgroundNormal"),
            "@MEO_SECONDARY_CONTAINER@": hex_role("Colors:Selection", "BackgroundAlternate"),
            "@MEO_ON_SECONDARY_CONTAINER@": hex_role("Colors:Window", "ForegroundNormal"),
            "@MEO_OUTLINE@": hex_role("Colors:Window", "ForegroundInactive"),
            "@MEO_ON_SURFACE_VARIANT@": hex_role("Colors:Window", "ForegroundInactive"),
        }
        rendered = (ROOT / "themes/input-method/ibus/gtk.css.in").read_text(encoding="utf-8")
        for token, value in values.items():
            rendered = rendered.replace(token, value)
        provider = Gtk.CssProvider()
        provider.load_from_data(rendered.encode("utf-8"))

    def test_helper_is_syntax_valid_and_dry_run_is_side_effect_free(self) -> None:
        helper = ROOT / "tools/input-method/meo-input-method.sh"
        subprocess.run(["bash", "-n", str(helper)], check=True)
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            environment = os.environ | {
                "XDG_CONFIG_HOME": str(temporary / "config"),
                "XDG_DATA_HOME": str(temporary / "data"),
                "XDG_CONFIG_DIRS": str(temporary / "empty-config"),
                "MEO_INPUT_METHOD_RESOURCE_ROOT": str(ROOT / "themes/input-method"),
                "MEO_INPUT_METHOD_COLOR_SCHEME_ROOT": str(ROOT / "themes/color-schemes"),
                "MEO_INPUT_METHOD_COLOR_SCHEME": "MeoDark",
            }
            result = subprocess.run(
                ["bash", str(helper), "--enable", "ibus", "--dry-run"],
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )
            self.assertIn("Would render IBus MD3 theme from MeoDark", result.stdout)
            self.assertIn("gsettings set org.freedesktop.ibus.panel custom-theme MeoInputMethod", result.stdout)
            self.assertNotIn("custom-font", result.stdout)
            self.assertNotIn("lookup-table-orientation", result.stdout)
            self.assertFalse((temporary / "data/themes/MeoInputMethod").exists())

    def test_fcitx_enable_preserves_native_options(self) -> None:
        helper = ROOT / "tools/input-method/meo-input-method.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            temporary = Path(temp_dir)
            config = temporary / "config/fcitx5/conf/classicui.conf"
            config.parent.mkdir(parents=True)
            config.write_text(
                "Vertical Candidate List=True\nFont=User Font 13\n"
                "WheelForPaging=False\nUseAccentColor=True\n",
                encoding="utf-8",
            )
            fake_bin = temporary / "bin"
            fake_bin.mkdir()
            fcitx = fake_bin / "fcitx5"
            fcitx.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            fcitx.chmod(0o755)
            remote = fake_bin / "fcitx5-remote"
            remote.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            remote.chmod(0o755)
            environment = os.environ | {
                "XDG_CONFIG_HOME": str(temporary / "config"),
                "XDG_DATA_HOME": str(temporary / "data"),
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
            }
            subprocess.run(
                ["bash", str(helper), "--enable", "fcitx5", "--quiet"],
                check=True,
                env=environment,
            )
            rendered = config.read_text(encoding="utf-8")
            self.assertIn("Vertical Candidate List=True", rendered)
            self.assertIn("Font=User Font 13", rendered)
            self.assertIn("WheelForPaging=False", rendered)
            self.assertIn("UseAccentColor=True", rendered)
            self.assertIn("Theme=MeoInputMethod-Light", rendered)
            self.assertIn("DarkTheme=MeoInputMethod-Dark", rendered)
            self.assertNotIn("[ClassicUI]", rendered)

    def test_package_and_mode_switch_expose_the_integration(self) -> None:
        package = (ROOT / "packaging/arch/PKGBUILD").read_text(encoding="utf-8")
        self.assertIn("defaults/input-method/fcitx5/conf/classicui.conf", package)
        self.assertIn("themes/input-method/fcitx5/MeoInputMethod-Light", package)
        self.assertIn("themes/input-method/fcitx5/MeoInputMethod-Dark", package)
        self.assertIn("meo-input-method", package)
        self.assertIn("meo-desktop-apply", package)
        self.assertIn("fcitx5-configtool", package)
        mode_switch = (ROOT / "tools/theme/apply-meo-mode.sh").read_text(encoding="utf-8")
        self.assertIn("meo-input-method --sync --quiet", mode_switch)
        apply_helper = (ROOT / "tools/theme/apply-meo-desktop.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("fcitx5-remote --check", apply_helper)
        self.assertIn("--enable fcitx5 --quiet", apply_helper)
        self.assertIn("pgrep -x ibus-daemon", apply_helper)
        self.assertIn("--enable ibus --quiet", apply_helper)
        self.assertGreater(
            apply_helper.index("--enable fcitx5 --quiet"),
            apply_helper.index("plasma-apply-lookandfeel -a org.meo.desktop"),
        )
        setup = (ROOT / "setup/apply-meo-desktop.sh").read_text(encoding="utf-8")
        self.assertIn("tools/theme/apply-meo-desktop.sh", setup)
        self.assertIn("MEO_INPUT_METHOD_HELPER", setup)


if __name__ == "__main__":
    unittest.main()
