import importlib.util
import configparser
import os
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("app_icon_studio", ROOT / "tools/icons/app_icon_studio.py")
studio = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = studio
SPEC.loader.exec_module(studio)


class AppIconStudioTest(unittest.TestCase):
    def test_generated_names_are_unique_and_namespaced(self):
        one = studio.DesktopApplication("org.example.One.desktop", Path("a"), Path("b"), "One", "one", "hash")
        two = studio.DesktopApplication("org.example.Two.desktop", Path("a"), Path("b"), "Two", "two", "hash")
        self.assertTrue(one.generated_icon_name.startswith("org.meo.iconstudio.app."))
        self.assertNotEqual(one.generated_icon_name, two.generated_icon_name)

    def test_unity_hub_editor_uses_installed_editor_artwork_alias(self):
        candidates = studio.icon_name_candidates("unityhub-unity-editor")
        self.assertIn("unity-editor-icon", candidates)
        self.assertIn("unityhub", candidates)

    def test_vendor_hicolor_artwork_beats_a_tiny_theme_fallback(self):
        themed = Path("/home/user/.local/share/icons/Theme/16x16/apps/app.svg")
        vendor = Path("/usr/share/icons/hicolor/256x256/apps/app.png")
        self.assertGreater(studio.icon_source_score(vendor), studio.icon_source_score(themed))

    def test_patch_only_changes_meo_managed_desktop_keys(self):
        source = "# user comment\n[Desktop Entry]\nName=Example\nIcon=example\nExec=example\n\n[Other]\nValue=one\n"
        patched = studio.patch_desktop_icon(source, "org.meo.iconstudio.app.abc", "source-hash", "example")
        self.assertIn("# user comment", patched)
        self.assertIn("Exec=example", patched)
        self.assertIn("[Other]\nValue=one", patched)
        self.assertIn("Icon=org.meo.iconstudio.app.abc", patched)
        self.assertIn("X-Meo-IconStudio-Managed=true", patched)
        self.assertIn("X-Meo-IconStudio-SourceIcon=example", patched)

    def test_reapplying_keeps_the_recorded_original_source_icon(self):
        source = "[Desktop Entry]\nName=Example\nIcon=example\nExec=example\n"
        first = studio.patch_desktop_icon(source, "org.meo.iconstudio.app.first", "one", "example")
        second = studio.patch_desktop_icon(first, "org.meo.iconstudio.app.second", "two", "example")
        self.assertIn("Icon=org.meo.iconstudio.app.second", second)
        self.assertIn("X-Meo-IconStudio-SourceIcon=example", second)
        self.assertEqual(second.count("X-Meo-IconStudio-SourceIcon="), 1)

    def test_render_keeps_transparent_canvas_and_requested_size(self):
        source = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        source.paste((20, 100, 240, 255), (8, 8, 56, 56))
        rendered = studio.render_icon(source, "original", {
            "surface": (250, 247, 255), "primary": (103, 80, 164),
            "surfaceHigh": (235, 230, 242), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
        }, "org.example.App.desktop")
        self.assertEqual(rendered.size, (1024, 1024))
        self.assertEqual(rendered.getpixel((0, 0))[3], 0)
        self.assertGreater(rendered.getpixel((512, 512))[3], 0)

    def test_pixel_shape_has_a_flower_silhouette_not_a_rounded_square(self):
        source = Image.new("RGBA", (64, 64), (42, 110, 240, 255))
        rendered = studio.render_icon(source, "original", {
            "surface": (250, 247, 255), "primary": (103, 80, 164),
            "surfaceHigh": (235, 230, 242), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
        }, "org.example.App.desktop", "pixel")
        # The flower reaches the centre of each side but deliberately leaves
        # its diagonal corners transparent, unlike the old rounded square.
        self.assertGreater(rendered.getpixel((512, 96))[3], 0)
        self.assertEqual(rendered.getpixel((118, 118))[3], 0)

    def test_circle_shape_is_transparent_outside_one_round_silhouette(self):
        source = Image.new("RGBA", (64, 64), (42, 110, 240, 255))
        rendered = studio.render_icon(source, "original", {
            "surface": (250, 247, 255), "primary": (103, 80, 164),
            "surfaceHigh": (235, 230, 242), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
        }, "org.example.App.desktop", "circle")
        self.assertEqual(rendered.getpixel((96, 96))[3], 0)
        self.assertGreater(rendered.getpixel((512, 96))[3], 0)
        self.assertGreater(rendered.getpixel((512, 512))[3], 0)

    def test_ai_import_clips_without_adding_a_second_container_color(self):
        source = Image.new("RGBA", (512, 512), (225, 30, 45, 255))
        rendered = studio.render_ai_icon(source, "circle")
        self.assertEqual(rendered.getpixel((96, 96))[3], 0)
        self.assertEqual(rendered.getpixel((512, 512)), (225, 30, 45, 255))

    def test_ai_easel_asset_recolors_without_losing_continuous_texture(self):
        source = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for x in range(64):
            for y in range(64):
                level = round(255 * x / 63)
                source.putpixel((x, y), (level, level, level, 255))
        asset = studio.normalized_easel_asset(source)
        light = {
            "onPrimaryContainer": (33, 0, 93), "primary": (103, 80, 164),
            "primaryContainer": (234, 221, 255),
        }
        dark = {
            "onPrimaryContainer": (232, 222, 255), "primary": (207, 189, 255),
            "primaryContainer": (79, 55, 139),
        }
        light_result = studio.colorize_easel_asset(asset, light)
        dark_result = studio.colorize_easel_asset(asset, dark)
        self.assertNotEqual(light_result.getpixel((32, 32)), dark_result.getpixel((32, 32)))
        self.assertGreater(len({pixel[:3] for pixel in studio.pixel_values(light_result)}), 16)

    def test_monet_keeps_internal_structure_of_an_opaque_multicolor_logo(self):
        source = Image.new("RGBA", (96, 96), (220, 50, 50, 255))
        source.paste((40, 170, 90, 255), (48, 0, 96, 48))
        source.paste((245, 190, 40, 255), (0, 48, 96, 96))
        source.paste((40, 90, 210, 255), (34, 34, 62, 62))
        colors = {
            "surface": (250, 247, 255), "surfaceHigh": (235, 230, 242),
            "primary": (103, 80, 164), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
            "onSurface": (29, 27, 32), "onSurfaceVariant": (73, 69, 79),
        }
        rendered = studio.render_icon(source, "monet", colors, "chrome", "circle")
        foreground_colors = {
            rendered.getpixel(point)[:3]
            for point in ((400, 400), (624, 400), (400, 624), (512, 512))
        }
        self.assertGreaterEqual(len(foreground_colors), 2)

    def test_monet_keeps_a_small_light_brand_mark_on_a_large_flat_field(self):
        source = Image.new("RGBA", (128, 128), (88, 101, 242, 255))
        for x in range(44, 84):
            for y in range(54, 74):
                source.putpixel((x, y), (255, 255, 255, 255))
        symbol = studio.normalized_symbol(source)
        levels = {red for red, _green, _blue, alpha in studio.pixel_values(symbol) if alpha > 0}
        self.assertGreaterEqual(len(levels), 2)
        colors = {
            "surface": (250, 247, 255), "surfaceHigh": (235, 230, 242),
            "primary": (103, 80, 164), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
            "onSurface": (29, 27, 32), "onSurfaceVariant": (73, 69, 79),
        }
        rendered = studio.render_icon(source, "monet", colors,
                                      "discord.desktop", "circle", symbol)
        field = rendered.getpixel((512, 420))[:3]
        mark = rendered.getpixel((512, 512))[:3]
        self.assertNotEqual(field, mark)

    def test_new_manifest_defaults_to_monet_circle(self):
        with tempfile.TemporaryDirectory() as directory:
            config = studio.load_config(Path(directory) / "missing.json")
        self.assertEqual(config["style"], "monet")
        self.assertEqual(config["shape"], "circle")
        self.assertEqual(config["schema"], 3)

    def test_source_icon_hash_depends_on_pixels_not_desktop_metadata(self):
        red = Image.new("RGBA", (8, 8), (255, 0, 0, 255))
        blue = Image.new("RGBA", (8, 8), (0, 0, 255, 255))
        self.assertEqual(studio.source_icon_hash(red), studio.source_icon_hash(red.copy()))
        self.assertNotEqual(studio.source_icon_hash(red), studio.source_icon_hash(blue))

    def test_user_owned_override_is_restored_without_deleting_the_file(self):
        with tempfile.TemporaryDirectory() as directory:
            local = Path(directory) / "app.desktop"
            local.write_text("[Desktop Entry]\nName=App\nIcon=original\nExec=app\n", encoding="utf-8")
            app = studio.DesktopApplication("app.desktop", local, local, "App", "original", "hash")
            manifest = {"applications": {}}
            studio.activate_desktop_entry(app, manifest)
            studio.restore_desktop_entry(app, manifest["applications"][app.desktop_id])
            restored = local.read_text(encoding="utf-8")
            self.assertIn("Icon=original", restored)
            self.assertIn("Exec=app", restored)
            self.assertNotIn("X-Meo-IconStudio", restored)

    def test_default_scheme_follows_the_active_kde_color_scheme(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            config.mkdir()
            (config / "kdeglobals").write_text(
                "[General]\nColorScheme=MeoDynamicDark\n", encoding="utf-8")
            with mock.patch.dict(os.environ, {
                "XDG_CONFIG_HOME": str(config),
                "XDG_DATA_HOME": str(data),
            }, clear=False):
                self.assertEqual(studio.default_scheme_path().name, "MeoDynamicDark.colors")

    def test_per_app_style_is_mirrored_to_dock_kconfig_without_changing_global_default(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config"
            app = studio.DesktopApplication(
                "org.example.App.desktop", Path("a"), Path("b"),
                "App", "example", "hash")
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}, clear=False):
                studio.write_dock_icon_modes([app], "mono", global_default=False)
            parser = configparser.ConfigParser(interpolation=None)
            parser.optionxform = str
            parser.read(config / "meodockrc", encoding="utf-8")
            self.assertEqual(parser.get("IconOverrides", "org.example.App"), "mono")
            self.assertFalse(parser.has_option("General", "IconMode"))

    def test_renderer_styles_map_to_distinct_dock_modes(self):
        app = studio.DesktopApplication(
            "org.example.App.desktop", Path("a"), Path("b"),
            "App", "example", "hash")
        for style, expected in (("original", "original"), ("monet", "tonal"),
                                ("pure", "tonal"), ("mono", "mono")):
            with self.subTest(style=style), tempfile.TemporaryDirectory() as directory:
                config = Path(directory) / "config"
                with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}, clear=False):
                    studio.write_dock_icon_modes([app], style, global_default=True)
                parser = configparser.ConfigParser(interpolation=None)
                parser.optionxform = str
                parser.read(config / "meodockrc", encoding="utf-8")
                self.assertEqual(parser.get("General", "IconMode"), expected)

    def test_ai_mode_is_a_per_app_override(self):
        app = studio.DesktopApplication(
            "org.example.App.desktop", Path("a"), Path("b"),
            "App", "example", "hash")
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config"
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}, clear=False):
                studio.write_dock_icon_modes([app], "ai", global_default=False)
            parser = configparser.ConfigParser(interpolation=None)
            parser.optionxform = str
            parser.read(config / "meodockrc", encoding="utf-8")
            self.assertEqual(parser.get("IconOverrides", "org.example.App"), "ai")

    def test_ai_pack_manifest_stays_inside_its_staging_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root.parent / "outside-ai-icon.png"
            Image.new("RGBA", (16, 16), (20, 40, 60, 255)).save(outside)
            manifest = root / "pack.json"
            manifest.write_text(
                '{"items":[{"desktopId":"org.example.App.desktop",'
                '"image":"../outside-ai-icon.png","shape":"circle","prompt":"Keep identity"}]}',
                encoding="utf-8")
            try:
                with self.assertRaisesRegex(ValueError, "escapes"):
                    studio.load_ai_pack(manifest)
            finally:
                outside.unlink(missing_ok=True)

    def test_ai_pack_dry_run_validates_every_application(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            Image.new("RGBA", (16, 16), (20, 40, 60, 255)).save(root / "icon.png")
            manifest = root / "pack.json"
            manifest.write_text(
                '{"packId":"test-pack","items":[{"desktopId":"org.example.App.desktop",'
                '"image":"icon.png","shape":"circle","prompt":"Keep identity"}]}',
                encoding="utf-8")
            app = studio.DesktopApplication(
                "org.example.App.desktop", Path("source.desktop"), Path("local.desktop"),
                "App", "example", "hash")
            result = studio.apply_ai_pack([app], manifest, root / "data",
                                          root / "scheme.colors", True)
            self.assertTrue(result["atomic"])
            self.assertEqual(result["rendered"], [app.desktop_id])

    def test_ai_pack_restores_all_managed_files_when_commit_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            output = root / "data"
            stage = root / "stage"
            stage.mkdir()
            for name in ("one.png", "two.png"):
                Image.new("RGBA", (16, 16), (20, 40, 60, 255)).save(stage / name)
            (stage / "pack.json").write_text(
                '{"items":['
                '{"desktopId":"one.desktop","image":"one.png","shape":"circle","prompt":"Keep identity"},'
                '{"desktopId":"two.desktop","image":"two.png","shape":"circle","prompt":"Keep identity"}'
                ']}', encoding="utf-8")
            apps = [
                studio.DesktopApplication("one.desktop", root / "one-source.desktop",
                                          output / "applications/one.desktop", "One", "one", "hash"),
                studio.DesktopApplication("two.desktop", root / "two-source.desktop",
                                          output / "applications/two.desktop", "Two", "two", "hash"),
            ]
            apps[0].local_path.parent.mkdir(parents=True)
            apps[0].local_path.write_bytes(b"old desktop")
            old_icon = studio.generated_paths(output, apps[0].generated_icon_name)[0]
            old_icon.parent.mkdir(parents=True)
            old_icon.write_bytes(b"old icon")
            manifest = config / "meo-icon-studio/manifest.json"
            manifest.parent.mkdir(parents=True)
            manifest.write_bytes(b'{"old":true}\n')
            dock = config / "meodockrc"
            dock.write_bytes(b"old dock\n")

            calls = 0
            def failing_apply(app, *_args, **_kwargs):
                nonlocal calls
                calls += 1
                if calls == 1:
                    app.local_path.write_bytes(b"new desktop")
                    studio.generated_paths(output, app.generated_icon_name)[0].write_bytes(b"new icon")
                    manifest.write_bytes(b"new manifest")
                    dock.write_bytes(b"new dock")
                    return {"rendered": []}
                raise RuntimeError("provider pack commit failed")

            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}, clear=False), \
                    mock.patch.object(studio, "apply_ai", side_effect=failing_apply), \
                    mock.patch.object(studio, "refresh_kde_caches"):
                with self.assertRaisesRegex(RuntimeError, "commit failed"):
                    studio.apply_ai_pack(apps, stage / "pack.json", output,
                                         root / "scheme.colors", False)
            self.assertEqual(apps[0].local_path.read_bytes(), b"old desktop")
            self.assertEqual(old_icon.read_bytes(), b"old icon")
            self.assertEqual(manifest.read_bytes(), b'{"old":true}\n')
            self.assertEqual(dock.read_bytes(), b"old dock\n")


if __name__ == "__main__":
    unittest.main()
