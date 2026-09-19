import importlib.util
import configparser
import io
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("app_icon_studio", ROOT / "tools/icons/app_icon_studio.py")
studio = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = studio
SPEC.loader.exec_module(studio)


class AppIconStudioTest(unittest.TestCase):
    def test_icon_contract_v1_matches_the_renderer_grid_tokens(self):
        contract = json.loads((ROOT / "tools/icons/meo_icon_contract_v1.json").read_text(encoding="utf-8"))
        self.assertEqual(contract["id"], "MeoIconContract")
        self.assertEqual(contract["version"], studio.ICON_CONTRACT_VERSION)
        self.assertEqual(contract["applicationIdentity"]["canvas"], "48u x 48u")
        self.assertEqual(contract["applicationIdentity"]["container"]["size"], "40u")
        self.assertEqual(contract["raster"]["deliverySizes"],
                         list(studio.RENDER_SIZES))
        self.assertEqual(contract["raster"]["smallMasterOversampling"], "8x")
        self.assertEqual(studio.ICON_GRID_UNITS, 48)
        self.assertEqual(studio.APP_CONTAINER_UNITS, 40)
        self.assertEqual(studio.APP_FOREGROUND_UNITS, 24)
        self.assertEqual(studio.PIXEL_FOREGROUND_UNITS, 22)
        self.assertEqual(studio.SQUIRCLE_RADIUS_UNITS, 12)
        self.assertEqual(studio.ROUNDED_RADIUS_UNITS, 8)
        self.assertEqual(studio.PIXEL_FLOWER_LOBE_OFFSET_UNITS, 12)
        self.assertEqual(studio.grid_pixels(48), studio.MASTER_SIZE)
        with self.assertRaises(ValueError):
            studio.grid_pixels(49)
        box = studio.application_container_box()
        self.assertEqual(box[2] - box[0], studio.grid_pixels(40))
        self.assertEqual(box[3] - box[1], studio.grid_pixels(40))

    def test_generated_names_are_unique_and_namespaced(self):
        one = studio.DesktopApplication("org.example.One.desktop", Path("a"), Path("b"), "One", "one", "hash")
        two = studio.DesktopApplication("org.example.Two.desktop", Path("a"), Path("b"), "Two", "two", "hash")
        self.assertTrue(one.generated_icon_name.startswith("org.meo.iconstudio.app."))
        self.assertNotEqual(one.generated_icon_name, two.generated_icon_name)

    def test_describe_exposes_canonical_identity_hash_not_desktop_text_hash(self):
        app = studio.DesktopApplication("org.example.One.desktop", Path("a"), Path("b"),
                                        "One", "org.example.One", "desktop-text-hash")
        identity = Image.new("RGBA", (4, 4), (20, 70, 180, 255))
        expected_identity_hash = studio.source_icon_hash(identity)
        with mock.patch.object(studio, "canonical_identity_source", return_value=identity):
            description = studio.describe_application(app, [app])
        self.assertEqual(description["schema"], 1)
        self.assertEqual(description["desktopEntryHash"], "desktop-text-hash")
        self.assertEqual(description["canonicalIdentityHash"], expected_identity_hash)
        self.assertNotEqual(description["canonicalIdentityHash"], description["desktopEntryHash"])
        self.assertTrue(description["canonicalIdentityAvailable"])

    def test_describe_cli_requires_explicit_ids_and_returns_identity_hash(self):
        app = studio.DesktopApplication("org.example.One.desktop", Path("a"), Path("b"),
                                        "One", "org.example.One", "desktop-text-hash")
        output = io.StringIO()
        with mock.patch.object(studio, "applications", return_value=[app]), \
                mock.patch.object(studio, "canonical_identity_hash", return_value="f" * 64), \
                mock.patch.object(sys, "argv", ["meo-app-icon-studio", "--describe", "--app", app.desktop_id]), \
                redirect_stdout(output):
            self.assertEqual(studio.main(), 0)
        payload = json.loads(output.getvalue())
        self.assertEqual(payload[0]["desktopId"], app.desktop_id)
        self.assertEqual(payload[0]["canonicalIdentityHash"], "f" * 64)
        self.assertEqual(payload[0]["desktopEntryHash"], "desktop-text-hash")

    def test_unity_hub_editor_uses_installed_editor_artwork_alias(self):
        candidates = studio.icon_name_candidates("unityhub-unity-editor")
        self.assertIn("unity-editor-icon", candidates)
        self.assertIn("unityhub", candidates)

    def test_vendor_hicolor_artwork_beats_a_tiny_theme_fallback(self):
        themed = Path("/home/user/.local/share/icons/Theme/16x16/apps/app.svg")
        vendor = Path("/usr/share/icons/hicolor/256x256/apps/app.png")
        self.assertGreater(studio.icon_source_score(vendor), studio.icon_source_score(themed))

    def test_direct_icon_lookup_uses_the_best_exact_file_without_full_index(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tiny = root / "icons/Breeze/16x16/apps/example.png"
            generated = root / "icons/MeoUser/512x512/apps/example.png"
            vendor = root / "icons/hicolor/256x256/apps/example.png"
            tiny.parent.mkdir(parents=True)
            generated.parent.mkdir(parents=True)
            vendor.parent.mkdir(parents=True)
            Image.new("RGBA", (16, 16), (240, 20, 20, 255)).save(tiny)
            Image.new("RGBA", (512, 512), (20, 240, 20, 255)).save(generated)
            Image.new("RGBA", (256, 256), (20, 80, 240, 255)).save(vendor)
            with mock.patch.object(studio, "data_roots", return_value=[root]), \
                    mock.patch.object(studio, "icon_path_index",
                                      side_effect=AssertionError("unexpected full index")):
                image = studio.source_image("example")
            self.assertIsNotNone(image)
            self.assertEqual(image.getpixel((0, 0)), (20, 80, 240, 255))

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

    def test_fallback_record_hashes_prompt_without_persisting_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_path = root / "source.desktop"
            source_path.write_text("[Desktop Entry]\nName=Example\nIcon=example\n", encoding="utf-8")
            app = studio.DesktopApplication("org.example.App.desktop", source_path,
                                            root / "data/app.desktop", "Example",
                                            "example", "source-hash")
            manifest = {"applications": {}}
            prompt = "do not write this provider text into the application record"
            studio.activate_desktop_entry(app, manifest, "monet", "circle", prompt)
            record = manifest["applications"][app.desktop_id]
            self.assertNotIn("prompt", record)
            self.assertEqual(record["promptRecipeVersion"], "v1")
            self.assertEqual(record["promptHash"],
                             hashlib.sha256(prompt.encode("utf-8")).hexdigest())

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

    def test_mono_shape_surface_uses_a_visible_dynamic_neutral_elevation(self):
        """A selected Mono shape must remain visible in both desktop modes."""
        source = Image.new("RGBA", (64, 64), (42, 110, 240, 255))

        def linear_channel(channel):
            normalized = channel / 255
            return (normalized / 12.92 if normalized <= 0.04045
                    else ((normalized + 0.055) / 1.055) ** 2.4)

        def relative_luminance(color):
            return (0.2126 * linear_channel(color[0])
                    + 0.7152 * linear_channel(color[1])
                    + 0.0722 * linear_channel(color[2]))

        def contrast(left, right):
            lighter, darker = sorted((relative_luminance(left),
                                      relative_luminance(right)), reverse=True)
            return (lighter + 0.05) / (darker + 0.05)

        self.assertEqual(studio.MONO_CONTAINER_TONE_FRACTION, 1 / 6)
        for scheme_name in ("MeoLight.colors", "MeoDark.colors"):
            with self.subTest(scheme=scheme_name):
                colors = studio.scheme_colors(ROOT / "themes/color-schemes" / scheme_name)
                expected_fill = studio.mono_container_fill(colors)
                rendered = studio.render_icon(source, "mono", colors, "mono-surface")
                box = studio.application_container_box()
                # Centered horizontally above the 24u foreground box is
                # fully inside the selected circle and free of the glyph.
                actual_fill = rendered.getpixel((studio.MASTER_SIZE // 2, box[1] + 100))[:3]
                self.assertEqual(actual_fill, expected_fill)
                self.assertGreaterEqual(contrast(colors["surface"], expected_fill), 1.4)

    def test_ai_material_cannot_replace_the_canonical_identity(self):
        material = Image.new("RGBA", (512, 512), (225, 30, 45, 255))
        identity = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        identity_draw = ImageDraw.Draw(identity)
        identity_draw.rectangle((8, 28, 56, 36), fill=(30, 80, 180, 255))
        identity_draw.rectangle((28, 8, 36, 56), fill=(30, 80, 180, 255))
        colors = {
            "surface": (250, 247, 255), "surfaceHigh": (235, 230, 242),
            "primary": (103, 80, 164), "primaryContainer": (234, 221, 255),
            "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
            "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
            "onSurface": (29, 27, 32),
        }
        foreground = studio.render_ai_identity_foreground(material, identity, colors)
        self.assertEqual(foreground.getpixel((0, 0))[3], 0)
        center = foreground.width // 2
        self.assertEqual(foreground.getpixel((center, center))[3], 255)
        self.assertEqual(foreground.getpixel((80, 80))[3], 0)
        rendered = studio.render_ai_icon(material, identity, colors, "circle")
        self.assertEqual(rendered.getpixel((96, 96))[3], 0)
        self.assertGreater(rendered.getpixel((512, 512))[3], 0)

    def test_ai_structural_mask_keeps_omnistore_compartments_at_small_sizes(self):
        """A colour-only original detail must remain a reviewed AI cutout."""
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root)
        app = studio.DesktopApplication(
            "omnistore.desktop", root / "omnistore.desktop", root / "local-omnistore.desktop",
            "OmniStore", "org.meo.OmniStore", "hash")
        identity = studio.reviewed_color_source(app)
        structural = studio.reviewed_ai_structural_source(app)
        self.assertIsNotNone(identity)
        self.assertIsNotNone(structural)
        unmasked_alpha = studio.normalized_symbol(
            studio.fit_square(identity, studio.AI_IDENTITY_WORK_SIDE)).getchannel("A")
        structural_alpha = studio.normalized_symbol(
            studio.fit_square(structural, studio.AI_IDENTITY_WORK_SIDE)).getchannel("A")
        reviewed_cuts = ImageChops.subtract(unmasked_alpha, structural_alpha)
        self.assertGreater(sum(1 for value in studio.pixel_values(reviewed_cuts)
                               if value >= 128), 1000)

        material = Image.new("RGBA", (128, 128), (0, 0, 0, 255))
        for x in range(material.width):
            for y in range(material.height):
                level = 48 + ((x * 5 + y * 3) % 160)
                material.putpixel((x, y), (level, level, level, 255))
        colors = studio.scheme_colors(ROOT / "themes/color-schemes/MeoLight.colors")
        variants = studio.render_ai_variants(app, material, identity, colors, "circle")
        for size in studio.OPTICAL_RENDER_SIZES:
            with self.subTest(size=size):
                masked = variants[size].resize((size, size), Image.Resampling.LANCZOS)
                unmasked = studio.render_ai_icon(
                    material, identity, colors, "circle",
                    master_size=size * studio.SMALL_MASTER_SCALE,
                ).resize((size, size), Image.Resampling.LANCZOS)
                difference = ImageChops.difference(masked, unmasked)
                changed_pixels = sum(
                    1 for red, green, blue, alpha in studio.pixel_values(difference)
                    if max(red, green, blue, alpha) >= 16)
                self.assertGreaterEqual(changed_pixels, 4)

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
        self.assertEqual(config["schema"], 4)
        self.assertEqual(config["contractVersion"], "1")
        self.assertFalse(config["overlay"]["active"])

    def test_kconfig_flag_entry_does_not_break_dark_scheme_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            config.mkdir()
            (config / "kdeglobals").write_text(
                "[General]\nColorScheme[$d]\nColorScheme=MeoDynamicDark\n",
                encoding="utf-8")
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}, clear=False):
                self.assertTrue(studio.active_kde_is_dark())

    def test_overlay_resolution_rejects_system_and_absolute_icon_names(self):
        system_entries = [
            studio.DesktopApplication(f"{icon}.desktop", Path("a"), Path("b"),
                                      "System", icon, "hash")
            for icon in ("preferences-system", "system-users", "meoarch-logo")
        ]
        absolute = studio.DesktopApplication("absolute.desktop", Path("a"), Path("b"),
                                             "Absolute", "/usr/share/pixmaps/app.svg", "hash")
        for system in system_entries:
            with self.subTest(icon=system.icon):
                self.assertEqual(studio.icon_resolution(system, [system]).method,
                                 studio.DESKTOP_FALLBACK_METHOD)
                self.assertEqual(studio.icon_resolution(system, [system]).collision_risk,
                                 studio.COLLISION_SHARED)
        self.assertEqual(studio.icon_resolution(absolute, [absolute]).collision_risk,
                         studio.COLLISION_ABSOLUTE)

    def test_system_icon_scan_uses_packaged_xdg_theme_before_source_fallback(self):
        """An installed Studio must not lose semantic collision protection."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            packaged_icon = root / "icons/MeoSymbols/16x16/actions/runtime-semantic.svg"
            packaged_icon.parent.mkdir(parents=True)
            packaged_icon.write_text("<svg/>", encoding="utf-8")
            app = studio.DesktopApplication(
                "runtime-semantic.desktop", Path("source"), Path("local"),
                "Semantic collision", "runtime-semantic", "hash")
            with mock.patch.object(studio, "data_roots", return_value=[root]), \
                    mock.patch.object(studio, "SYSTEM_ICON_NAMES", None):
                self.assertIn("runtime-semantic", studio.system_icon_names())
                resolution = studio.icon_resolution(app, [app])
            self.assertEqual(resolution.method, studio.DESKTOP_FALLBACK_METHOD)
            self.assertEqual(resolution.collision_risk, studio.COLLISION_SHARED)

    def test_overlay_apply_writes_no_desktop_copy_and_original_restores_theme(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            cache = root / "cache"
            config.mkdir()
            (config / "kdeglobals").write_text(
                "[General]\nColorScheme[$d]\nColorScheme=MeoDynamicLight\n\n"
                "[Icons]\nTheme=MeoSymbols\n", encoding="utf-8")
            app = studio.DesktopApplication(
                "org.example.Unique.desktop", root / "source.desktop",
                data / "applications/org.example.Unique.desktop", "Unique",
                "org.example.Unique", "source-hash")
            source = Image.new("RGBA", (32, 32), (50, 100, 150, 255))
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
                    "XDG_CACHE_HOME": str(cache),
            }, clear=False), \
                    mock.patch.object(studio, "source_image", return_value=source), \
                    mock.patch.object(studio, "refresh_kde_caches"):
                result = studio.apply([app], "monet", "circle", "Keep identity",
                                      data, root / "MeoDynamicLight.colors", False,
                                      all_apps=[app])
                self.assertEqual(result["overlay"], [app.desktop_id])
                self.assertFalse(app.local_path.exists())
                for size in studio.RENDER_SIZES:
                    self.assertTrue((data / "icons/MeoUser" /
                                     f"{size}x{size}/apps/org.example.Unique.png").is_file())
                    self.assertTrue((data / "icons/MeoUserDark" /
                                     f"{size}x{size}/apps/org.example.Unique.png").is_file())
                self.assertIn("Inherits=MeoSymbols,breeze,hicolor",
                              (data / "icons/MeoUser/index.theme").read_text(encoding="utf-8"))
                self.assertEqual(studio.current_kde_icon_theme(), "MeoUser")
                reset = studio.apply([app], "original", "circle", "ignored", data,
                                     root / "MeoDynamicLight.colors", False, all_apps=[app])
                self.assertEqual(reset["style"], "original")
                for size in studio.RENDER_SIZES:
                    self.assertFalse((data / "icons/MeoUser" /
                                      f"{size}x{size}/apps/org.example.Unique.png").exists())
                    self.assertFalse((data / "icons/MeoUserDark" /
                                      f"{size}x{size}/apps/org.example.Unique.png").exists())
                self.assertEqual(studio.current_kde_icon_theme(), "MeoSymbols")

    def test_qt_theme_lookup_resolves_the_user_overlay_asset(self):
        """Exercise the same QIcon theme lookup Plasma task entries use.

        File existence alone cannot prove that a user-level icon theme wins over
        fallback themes. Qt's PNG upload can differ by one rounding level from
        Pillow at antialiased edges, so compare it with a one-channel tolerance.
        """
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        try:
            from PySide6.QtGui import QGuiApplication, QIcon, QImage
        except ImportError:
            self.skipTest("PySide6 is required by the packaged Studio renderer")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            cache = root / "cache"
            config.mkdir()
            app_record = studio.DesktopApplication(
                "org.example.Unique.desktop", root / "source.desktop",
                data / "applications/org.example.Unique.desktop", "Unique",
                "org.example.Unique", "source-hash")
            source = Image.new("RGBA", (32, 32), (50, 100, 150, 255))
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
                    "XDG_CACHE_HOME": str(cache),
            }, clear=False), \
                    mock.patch.object(studio, "source_image", return_value=source), \
                    mock.patch.object(studio, "refresh_kde_caches"):
                studio.apply([app_record], "monet", "circle", "Keep identity",
                             data, root / "MeoDynamicLight.colors", False,
                             all_apps=[app_record])
                qt_app = QGuiApplication.instance() or QGuiApplication(["meo-icon-overlay-test"])
                _ = qt_app
                QIcon.setThemeSearchPaths([str(data / "icons"),
                                           str(ROOT / "themes/icons"),
                                           "/usr/share/icons"])
                QIcon.setThemeName("MeoUser")
                icon = QIcon.fromTheme("org.example.Unique")
                self.assertFalse(icon.isNull())
                available = {(size.width(), size.height()) for size in icon.availableSizes()}
                self.assertTrue({(16, 16), (22, 22), (32, 32), (512, 512)}.issubset(available))
                for requested in (16, 22, 32, 512):
                    qimage = icon.pixmap(requested, requested).toImage().convertToFormat(
                        QImage.Format.Format_RGBA8888)
                    resolved = Image.frombytes("RGBA", (qimage.width(), qimage.height()),
                                               bytes(qimage.bits()), "raw", "RGBA",
                                               qimage.bytesPerLine())
                    expected = Image.open(
                        data / f"icons/MeoUser/{requested}x{requested}/apps/org.example.Unique.png").convert("RGBA")
                    extrema = ImageChops.difference(resolved, expected).getextrema()
                    self.assertLessEqual(max(high for _low, high in extrema), 1)

    def test_first_party_mono_uses_the_reviewed_contract_glyph(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            cache = root / "cache"
            config.mkdir()
            app = studio.DesktopApplication(
                "org.meo.settings.desktop", root / "source.desktop",
                data / "applications/org.meo.settings.desktop", "Meo Settings",
                "org.meo.settings", "source-hash")
            for size in studio.OPTICAL_RENDER_SIZES:
                optical_master = studio.reviewed_optical_source(app, size)
                self.assertIsNotNone(optical_master)
                self.assertEqual(optical_master.size,
                                 (size * studio.SMALL_MASTER_SCALE,
                                  size * studio.SMALL_MASTER_SCALE))
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
                    "XDG_CACHE_HOME": str(cache),
            }, clear=False), \
                    mock.patch.object(studio, "source_image", return_value=None), \
                    mock.patch.object(studio, "refresh_kde_caches"):
                glyph = studio.reviewed_mono_source(app)
                self.assertIsNotNone(glyph)
                result = studio.apply([app], "mono", "circle", "Keep identity",
                                      data, root / "MeoDynamicLight.colors", False,
                                      all_apps=[app])
                self.assertEqual(result["rendered"][0]["identitySource"], "reviewed-mono")
                manifest = studio.load_config(config / "meo-icon-studio/manifest.json")
                self.assertEqual(manifest["applications"][app.desktop_id]["identitySource"],
                                 "reviewed-mono")

    def test_reviewed_mono_glyphs_keep_transparent_cuts_and_one_dynamic_tint(self):
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root)
        apps = {
            "omnistore.desktop": studio.DesktopApplication(
                "omnistore.desktop", root / "omnistore.desktop", root / "local-omni.desktop",
                "OmniStore", "org.meo.OmniStore", "hash"),
            "org.meo.welcome.desktop": studio.DesktopApplication(
                "org.meo.welcome.desktop", root / "welcome.desktop", root / "local-welcome.desktop",
                "Welcome", "org.meo.welcome", "hash"),
        }
        omnistore = studio.reviewed_mono_source(apps["omnistore.desktop"])
        welcome = studio.reviewed_mono_source(apps["org.meo.welcome.desktop"])
        self.assertIsNotNone(omnistore)
        self.assertIsNotNone(welcome)
        # The panel cutout and flower centre are alpha holes, not white paint.
        self.assertEqual(omnistore.getpixel((384, 554))[3], 0)
        self.assertEqual(welcome.getpixel((512, 512))[3], 0)
        settings = studio.reviewed_mono_source(studio.DesktopApplication(
            "org.meo.settings.desktop", root / "settings.desktop", root / "local-settings.desktop",
            "Settings", "org.meo.settings", "hash"))
        self.assertIsNotNone(settings)
        colors = {
            "surface": (250, 247, 255), "onSurface": (29, 27, 32),
            "primary": (103, 80, 164), "primaryContainer": (234, 221, 255),
            "onPrimaryContainer": (33, 0, 93),
        }
        solid = studio.colorize_symbol(studio.normalized_symbol(settings), colors,
                                       monochrome=True, solid_monochrome=True)
        opaque_colors = {pixel[:3] for pixel in studio.pixel_values(solid)
                         if pixel[3] >= 250}
        self.assertEqual(opaque_colors, {colors["onSurface"]})

    def test_meo_color_writes_reviewed_optical_masters_at_small_sizes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            cache = root / "cache"
            config.mkdir()
            app = studio.DesktopApplication(
                "org.meo.settings.desktop", root / "source.desktop",
                data / "applications/org.meo.settings.desktop", "Meo Settings",
                "org.meo.settings", "source-hash")
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
                    "XDG_CACHE_HOME": str(cache),
            }, clear=False), \
                    mock.patch.object(studio, "source_image", return_value=None), \
                    mock.patch.object(studio, "reviewed_optical_source",
                                      wraps=studio.reviewed_optical_source) as optical, \
                    mock.patch.object(studio, "refresh_kde_caches"):
                result = studio.apply([app], "monet", "circle", "Keep identity",
                                      data, root / "MeoDynamicLight.colors", False,
                                      all_apps=[app])
            self.assertEqual(result["overlay"], [app.desktop_id])
            self.assertEqual(result["rendered"][0]["identitySource"], "reviewed-color")
            self.assertEqual([call.args[1] for call in optical.call_args_list],
                             list(studio.OPTICAL_RENDER_SIZES))
            for size in studio.RENDER_SIZES:
                path = data / "icons/MeoUser" / f"{size}x{size}/apps/org.meo.settings.png"
                self.assertTrue(path.is_file(), path)
                with Image.open(path) as rendered:
                    self.assertEqual(rendered.size, (size, size))
            index = (data / "icons/MeoUser/index.theme").read_text(encoding="utf-8")
            self.assertIn("Directories=16x16/apps,22x22/apps,32x32/apps", index)

    def test_attested_generation_manifest_keeps_original_and_generated_hashes_distinct(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            stage = root / "stage"
            cache = root / "cache"
            config.mkdir()
            stage.mkdir()
            Image.new("RGBA", (32, 32), (20, 40, 60, 255)).save(stage / "icon.png")
            app = studio.DesktopApplication(
                "org.meo.settings.desktop", root / "source.desktop",
                data / "applications/org.meo.settings.desktop", "Meo Settings",
                "org.meo.settings", "source-hash")
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
                    "XDG_CACHE_HOME": str(cache),
            }, clear=False):
                source_hash = studio.canonical_identity_hash(app)
                self.assertIsNotNone(source_hash)
                (stage / "pack.json").write_text(json.dumps({
                    "schema": studio.AI_PACK_STAGING_SCHEMA,
                    "packId": "provenance-pack",
                    "provider": "Meo Account",
                    "model": "image-test",
                    "styleId": "paper",
                    "promptRecipeVersion": "v2",
                    "items": [{
                        "desktopId": app.desktop_id,
                        "image": "icon.png",
                        "shape": "circle",
                        "prompt": "do not persist this prompt",
                        "sourceIconHash": source_hash,
                        "imageSha256": studio.file_sha256(stage / "icon.png"),
                    }],
                }), encoding="utf-8")
                with mock.patch.object(studio, "refresh_kde_caches"):
                    result = studio.apply_ai_pack([app], stage / "pack.json", data,
                                                  root / "MeoDynamicLight.colors", False)
                generated = Path(result["generationManifest"])
                payload = json.loads(generated.read_text(encoding="utf-8"))
                self.assertEqual(payload["contractVersion"], "1")
                self.assertEqual(payload["stagingSchema"], studio.AI_PACK_STAGING_SCHEMA)
                self.assertEqual(payload["styleId"], "paper")
                self.assertEqual(payload["sourceIconHashes"][app.desktop_id], source_hash)
                self.assertEqual(payload["stagedImageHashes"][app.desktop_id],
                                 studio.file_sha256(stage / "icon.png"))
                self.assertEqual(payload["sourceIntegrity"][app.desktop_id]["status"], "verified")
                self.assertTrue(payload["sourceIntegrity"][app.desktop_id]["verified"])
                self.assertEqual(payload["generatedAssetHashes"][app.desktop_id],
                                 studio.file_sha256(studio.ai_asset_path(app)))
                self.assertIn(app.desktop_id, payload["outputHashes"])
                output_hashes = payload["outputHashes"][app.desktop_id]
                self.assertEqual(len(output_hashes), len(studio.RENDER_SIZES) * 2)
                for size in studio.RENDER_SIZES:
                    self.assertIn(f"icons/MeoUser/{size}x{size}/apps/org.meo.settings.png",
                                  output_hashes)
                    self.assertIn(f"icons/MeoUserDark/{size}x{size}/apps/org.meo.settings.png",
                                  output_hashes)
                self.assertNotIn("do not persist this prompt",
                                 generated.read_text(encoding="utf-8"))

    def test_attested_ai_pack_rejects_a_stale_original_identity_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config"
            data = root / "data"
            stage = root / "stage"
            config.mkdir()
            stage.mkdir()
            Image.new("RGBA", (32, 32), (20, 40, 60, 255)).save(stage / "icon.png")
            app = studio.DesktopApplication(
                "org.meo.settings.desktop", root / "source.desktop",
                data / "applications/org.meo.settings.desktop", "Meo Settings",
                "org.meo.settings", "source-hash")
            (stage / "pack.json").write_text(json.dumps({
                "schema": studio.AI_PACK_STAGING_SCHEMA,
                "items": [{
                    "desktopId": app.desktop_id,
                    "image": "icon.png",
                    "shape": "circle",
                    "prompt": "Keep identity",
                    "sourceIconHash": "0" * 64,
                    "imageSha256": studio.file_sha256(stage / "icon.png"),
                }],
            }), encoding="utf-8")
            with mock.patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": str(config),
                    "XDG_DATA_HOME": str(data),
            }, clear=False), mock.patch.object(studio, "refresh_kde_caches"):
                with self.assertRaisesRegex(ValueError, "no longer matches"):
                    studio.apply_ai_pack([app], stage / "pack.json", data,
                                         root / "MeoDynamicLight.colors", False)
            self.assertFalse((data / "icons").exists())

    def test_attested_ai_pack_dry_run_checks_the_current_original_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage = root / "stage"
            stage.mkdir()
            Image.new("RGBA", (32, 32), (20, 40, 60, 255)).save(stage / "icon.png")
            app = studio.DesktopApplication(
                "org.meo.settings.desktop", root / "source.desktop",
                root / "data/applications/org.meo.settings.desktop", "Meo Settings",
                "org.meo.settings", "source-hash")
            (stage / "pack.json").write_text(json.dumps({
                "schema": studio.AI_PACK_STAGING_SCHEMA,
                "items": [{
                    "desktopId": app.desktop_id,
                    "image": "icon.png",
                    "shape": "circle",
                    "prompt": "Keep identity",
                    "sourceIconHash": "0" * 64,
                    "imageSha256": studio.file_sha256(stage / "icon.png"),
                }],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no longer matches"):
                studio.apply_ai_pack([app], stage / "pack.json", root / "data",
                                     root / "MeoDynamicLight.colors", True)

    def test_attested_ai_pack_requires_a_source_identity_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            Image.new("RGBA", (16, 16), (20, 40, 60, 255)).save(root / "icon.png")
            manifest = root / "pack.json"
            manifest.write_text(json.dumps({
                "schema": studio.AI_PACK_STAGING_SCHEMA,
                "items": [{
                    "desktopId": "org.example.App.desktop",
                    "image": "icon.png",
                    "shape": "circle",
                    "prompt": "Keep identity",
                }],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "requires every source identity hash"):
                studio.load_ai_pack(manifest)

    def test_attested_ai_pack_rejects_a_swapped_staging_image(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            Image.new("RGBA", (16, 16), (20, 40, 60, 255)).save(root / "icon.png")
            manifest = root / "pack.json"
            manifest.write_text(json.dumps({
                "schema": studio.AI_PACK_STAGING_SCHEMA,
                "items": [{
                    "desktopId": "org.example.App.desktop",
                    "image": "icon.png",
                    "shape": "circle",
                    "prompt": "Keep identity",
                    "sourceIconHash": "a" * 64,
                    "imageSha256": "0" * 64,
                }],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "staged image no longer matches"):
                studio.load_ai_pack(manifest)

    def test_ai_pack_preflight_rejects_a_fully_transparent_provider_response(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(root / "icon.png")
            manifest = root / "pack.json"
            manifest.write_text(json.dumps({
                "items": [{
                    "desktopId": "org.example.App.desktop",
                    "image": "icon.png",
                    "shape": "circle",
                    "prompt": "Keep identity",
                }],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no visible material"):
                studio.load_ai_pack(manifest)

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
            with mock.patch.object(studio, "canonical_identity_source",
                                   return_value=Image.new("RGBA", (16, 16), (20, 40, 60, 255))):
                result = studio.apply_ai_pack([app], manifest, root / "data",
                                              root / "scheme.colors", True)
            self.assertTrue(result["atomic"])
            self.assertEqual(result["rendered"], [app.desktop_id])

    def test_attested_ai_pack_preview_is_renderer_only_and_reuses_one_material(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage = root / "account-stage"
            previews = root / "settings-preview"
            stage.mkdir()
            material = stage / "material.png"
            Image.new("RGBA", (64, 64), (20, 40, 160, 255)).save(material)
            apps = [
                studio.DesktopApplication(
                    "one.desktop", root / "one.desktop",
                    root / "data/applications/one.desktop", "One", "one", "one-hash"),
                studio.DesktopApplication(
                    "two.desktop", root / "two.desktop",
                    root / "data/applications/two.desktop", "Two", "two", "two-hash"),
            ]
            identities = [
                Image.new("RGBA", (32, 32), (180, 40, 60, 255)),
                Image.new("RGBA", (32, 32), (40, 180, 90, 255)),
            ]
            (stage / "pack.json").write_text(json.dumps({
                "schema": studio.AI_PACK_STAGING_SCHEMA,
                "packId": "one-material-preview",
                "styleId": "paper",
                "promptRecipeVersion": "v2",
                "items": [{
                    "desktopId": app.desktop_id,
                    "image": "material.png",
                    "imageSha256": studio.file_sha256(material),
                    "sourceIconHash": studio.source_icon_hash(identity),
                    "shape": "circle",
                    "prompt": "meo-style:paper:v2",
                } for app, identity in zip(apps, identities)],
            }), encoding="utf-8")
            with mock.patch.object(studio, "canonical_identity_source",
                                   side_effect=identities), \
                    mock.patch.object(studio, "load_ai_material",
                                      wraps=studio.load_ai_material) as material_loader:
                result = studio.preview_ai_pack(
                    apps, stage / "pack.json", previews, root / "MeoDynamicLight.colors")
            self.assertEqual(result["packId"], "one-material-preview")
            self.assertEqual(result["applicationCount"], 2)
            self.assertEqual([preview["desktopId"] for preview in result["previews"]],
                             ["one.desktop", "two.desktop"])
            # Preflight validates the shared material once and preview normalizes
            # it once: it must not become one provider-material decode per app.
            self.assertLessEqual(material_loader.call_count, 2)
            for preview in result["previews"]:
                preview_path = Path(preview["preview"])
                self.assertTrue(preview_path.is_file(), preview_path)
                with Image.open(preview_path) as image:
                    self.assertEqual(image.size, (128, 128))
            self.assertFalse((root / "data").exists())
            self.assertFalse((root / "config").exists())

    def test_preview_cli_requires_a_private_output_directory(self):
        app = studio.DesktopApplication(
            "org.example.App.desktop", Path("source.desktop"), Path("local.desktop"),
            "App", "example", "hash")
        output = io.StringIO()
        with mock.patch.object(studio, "applications", return_value=[app]), \
                mock.patch.object(studio, "default_scheme_path",
                                  return_value=Path("/tmp/scheme.colors")), \
                mock.patch.object(studio, "preview_ai_pack",
                                  return_value={"applicationCount": 1}) as preview, \
                mock.patch.object(sys, "argv", [
                    "meo-app-icon-studio",
                    "--preview-ai-pack", "/tmp/account/pack.json",
                    "--preview-output", "/tmp/settings/preview",
                ]), redirect_stdout(output):
            self.assertEqual(studio.main(), 0)
        preview.assert_called_once_with(
            [app], Path("/tmp/account/pack.json"), Path("/tmp/settings/preview"),
            Path("/tmp/scheme.colors"))
        self.assertEqual(json.loads(output.getvalue())["applicationCount"], 1)

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
                    mock.patch.object(studio, "canonical_identity_source",
                                      return_value=Image.new("RGBA", (16, 16), (20, 40, 60, 255))), \
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
