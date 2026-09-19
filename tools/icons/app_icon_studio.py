#!/usr/bin/env python3
"""Build and apply Meo's per-application Material icon treatment.

Application identity, KDE system semantics, and dynamic status indicators are
separate tracks. For an application whose original icon name is demonstrably
private, this tool renders a user-level FreeDesktop overlay:

    MeoUser -> MeoSymbols -> breeze -> hicolor
    MeoUserDark -> MeoSymbolsDark -> breeze-dark -> breeze -> hicolor

The overlay avoids copying a whole desktop entry, so an upstream application
update keeps its current Exec, Actions, MIME and DBus metadata. A shared,
absolute, or runtime-private icon name cannot safely use the overlay and is
handled by the deliberately narrow, manifest-owned desktop-entry fallback.
Status, device, action, authentication, MIME, and other KDE system icons are
never rendered as application identities.

The deterministic renderer is offline. Meo Settings may obtain consented AI
artwork through the separate Account flow; this tool never transmits a prompt
or credential and records only non-secret generation provenance.
"""

from __future__ import annotations

import argparse
import configparser
from collections import Counter
import hashlib
import json
from math import sqrt
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Mapping
from urllib.parse import quote

from PIL import Image, ImageChops, ImageDraw, ImageFilter


APP_GROUP = "Desktop Entry"
MANAGED_KEY = "X-Meo-IconStudio-Managed"
SOURCE_HASH_KEY = "X-Meo-IconStudio-SourceHash"
SOURCE_ICON_KEY = "X-Meo-IconStudio-SourceIcon"
ICON_PREFIX = "org.meo.iconstudio.app"
# Plasma can request a launcher icon at its native panel / grid size. Keeping
# the small fixed directories in the user overlay prevents a 128 px fallback
# from becoming the de-facto 16 px master. Large artwork is still delivered
# from the canonical 48u composition at high resolution.
RENDER_SIZES = (16, 22, 32, 128, 256, 512)
OPTICAL_RENDER_SIZES = (16, 22, 32)
# Small reviewed masters are rendered at a fixed oversampling factor, then
# written at their native icon-theme size. This keeps optical correction crisp
# without repeating the expensive 1024 px color analysis three times.
SMALL_MASTER_SCALE = 8
MASTER_SIZE = 1024
# Provider raster is material only. Sampling it at a bounded size keeps pack
# commit latency independent of an unnecessarily huge provider image; the
# canonical glyph retains a 512px working master before final icon rastering.
AI_MATERIAL_SAMPLE_SIDE = 256
AI_IDENTITY_WORK_SIDE = 512
AI_MAX_IMAGE_PIXELS = 16_000_000
SYMBOL_SCHEMA = 2
CONFIG_SCHEMA = 4
ICON_CONTRACT_VERSION = "1"
# Staging schema 2 adds a source-identity fingerprint.  Schema 1 remains
# readable for locally generated developer fixtures, but it is explicitly
# marked unverified in provenance and must not be used by a production
# one-tap Account pack flow.
AI_PACK_STAGING_SCHEMA = 2
# MeoIconContract v1: composition is authored on a 48u grid, then rendered
# into the large raster master. Keep these integers named and shared with
# docs/icons/ICON_CONTRACT_V1.md; the final pixels need not be grid aligned.
ICON_GRID_UNITS = 48
APP_CONTAINER_UNITS = 40
APP_FOREGROUND_UNITS = 24
PIXEL_FOREGROUND_UNITS = 22
SQUIRCLE_RADIUS_UNITS = 12
ROUNDED_RADIUS_UNITS = 8
PIXEL_FLOWER_CENTER_RADIUS_UNITS = 12
PIXEL_FLOWER_LOBE_RADIUS_UNITS = 8
PIXEL_FLOWER_LOBE_OFFSET_UNITS = 12
OUTLINE_DILATION_HALF_WIDTH_PX = 4
# Mono keeps one dynamic foreground tint, but its selected launcher shape must
# still read against both light and dark desktop surfaces. This named 1/6
# neutral elevation is deliberately derived from semantic roles rather than
# hard-coded near-black/near-white raster values.
MONO_CONTAINER_TONE_FRACTION = 1 / 6
OVERLAY_SCHEMA = 1
OVERLAY_THEMES = {False: "MeoUser", True: "MeoUserDark"}
OVERLAY_METHOD = "overlay-name"
DESKTOP_FALLBACK_METHOD = "desktop-fallback"
ORIGINAL_ONLY_METHOD = "original-only"
COLLISION_NONE = "none"
COLLISION_SHARED = "shared-system-name"
COLLISION_ABSOLUTE = "absolute-path"
COLLISION_PRIVATE = "runtime-private"
ICON_NAME_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
STYLES = ("monet", "original", "pure", "mono")
# Pixel's themed icons use a shared mask around recognisable app marks rather
# than replacing every app with a generic glyph. "pixel" remains the optional
# eight-lobed shape seen in the Android themed-icon picker; Circle is default.
SHAPES = ("circle", "pixel", "squircle", "rounded")
DEFAULT_PROMPT = (
    "Preserve the application's recognizable identity, key silhouette, internal "
    "cut lines, and negative spaces. Create one centered Pixel-inspired Easel "
    "icon using the locked Monet palette and subtle paper, crayon, or watercolor "
    "texture. No words, watermark, mockup, perspective, extra badge, or second "
    "container. Keep it readable at 128 px."
)
ICON_PATH_INDEX: dict[str, Path] | None = None
ICON_FILE_SUFFIXES = (".svg", ".png", ".webp", ".xpm", ".jpg", ".jpeg")
ICON_THEME_CONTEXTS = ("apps", "applications", "categories", "mimetypes", "devices", "places")
GENERATED_OR_SEMANTIC_THEME_NAMES = frozenset({
    "meosymbols", "meosymbolsdark", "meouser", "meouserdark",
})
ICON_FALLBACK_ALIASES = {
    # Unity Hub creates editor launchers with this historical icon name even
    # when the installed theme ships only the normal Unity Editor artwork.
    "unityhub-unity-editor": ("unity-editor-icon", "unityhub", "com.unity.UnityHub"),
}
SYSTEM_ICON_NAMES: set[str] | None = None
# Some KDE/FDO semantic names are aliases or live outside the local
# MeoSymbols source tree (for example, ``system-users`` maps to a category
# asset). They are still global names, not application-identity namespaces.
# Keep this narrow, explicit reserve list alongside MeoSymbols discovery so an
# older launcher cannot accidentally recolor authentication/settings/system UI.
RESERVED_SYSTEM_ICON_NAMES = frozenset({
    "preferences-system", "preferences-system-users", "system-users",
    "dialog-password", "bluetooth", "network-wireless", "audio-volume-high",
    "video-display", "preferences-desktop-notification", "battery",
    "meoarch-logo",
})
IDENTITY_MANIFEST_FILENAME = "manifest.json"
IDENTITY_RUNTIME_ROOT = Path("/usr/share/meo-icon-studio/application-identities")


def grid_pixels(units: int, master_size: int = MASTER_SIZE) -> int:
    """Convert an integer MeoIconContract grid measurement to raster pixels."""
    if not 0 <= units <= ICON_GRID_UNITS:
        raise ValueError(f"grid measurement outside 0..{ICON_GRID_UNITS}: {units}")
    if master_size < 1:
        raise ValueError(f"invalid raster master size: {master_size}")
    return round(master_size * units / ICON_GRID_UNITS)


def application_container_box(master_size: int = MASTER_SIZE) -> tuple[int, int, int, int]:
    """Center the 40u application container in the 48u composition canvas."""
    size = grid_pixels(APP_CONTAINER_UNITS, master_size)
    inset = (master_size - size) // 2
    return inset, inset, inset + size, inset + size


def application_identity_roots() -> tuple[Path, ...]:
    """Return packaged then source-tree roots for first-party identity data.

    The installed Studio package owns reviewed mono glyph inputs. The source
    tree fallback makes developer validation use the exact same manifest
    without pretending that a developer-local executable is production-owned.
    """
    source_root = Path(__file__).resolve().parents[2] / "assets" / "icons" / "application-identities"
    return IDENTITY_RUNTIME_ROOT, source_root


def application_identity_manifest() -> tuple[Path, dict[str, dict]]:
    """Load the small reviewed first-party identity registry defensively."""
    for root in application_identity_roots():
        path = root / IDENTITY_MANIFEST_FILENAME
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if (not isinstance(payload, dict)
                or payload.get("id") != "MeoIconManifest"
                or payload.get("contractVersion") != ICON_CONTRACT_VERSION
                or not isinstance(payload.get("applications"), list)):
            continue
        records = {str(record.get("desktopId", "")): record
                   for record in payload["applications"]
                   if isinstance(record, dict) and str(record.get("desktopId", "")).strip()}
        return root, records
    return Path(), {}


def reviewed_mono_source(app: DesktopApplication) -> Image.Image | None:
    """Return the contract-reviewed mono glyph for a first-party app, if any."""
    root, records = application_identity_manifest()
    record = records.get(app.desktop_id)
    if not record:
        return None
    relative = str(record.get("monoGlyphSource", "")).strip()
    if not relative or Path(relative).is_absolute():
        return None
    path = (root / relative).resolve()
    if root not in path.parents or not path.is_file():
        return None
    return qicon_file_image(path)


def reviewed_color_source(app: DesktopApplication) -> Image.Image | None:
    """Return the contract-reviewed color identity for a first-party app."""
    root, records = application_identity_manifest()
    record = records.get(app.desktop_id)
    if not record:
        return None
    relative = str(record.get("colorSource", "")).strip()
    if not relative or Path(relative).is_absolute():
        return None
    path = (root / relative).resolve()
    if root not in path.parents or not path.is_file():
        return None
    return qicon_file_image(path)


def reviewed_ai_structural_source(app: DesktopApplication,
                                  raster_size: int = MASTER_SIZE) -> Image.Image | None:
    """Return an approved alpha structure which AI material must preserve.

    Most identities use their canonical color artwork's alpha as sufficient
    geometry. A mark whose recognisable small details are colour-only can name
    an AI structural mask in MeoIconManifest. The mask has no palette authority:
    it can only retain reviewed transparent cuts and never replace the identity
    silhouette with generated artwork.
    """
    root, records = application_identity_manifest()
    record = records.get(app.desktop_id)
    if not record:
        return None
    relative = str(record.get("aiStructuralMaskSource", "")).strip()
    if not relative or Path(relative).is_absolute():
        return None
    path = (root / relative).resolve()
    if root not in path.parents or not path.is_file():
        return None
    return qicon_file_image(path, raster_size)


def reviewed_optical_source(app: DesktopApplication, size: int) -> Image.Image | None:
    """Return a reviewed small color master for a first-party identity.

    The identity sheet records small masters explicitly rather than relying on
    an accidental downscale of the 48u composition. They are deliberately
    used only for Meo Color: Mono has its own reviewed glyph, and AI artwork
    must remain the validated provider output rather than silently mixing a
    second identity asset into it.
    """
    if size not in OPTICAL_RENDER_SIZES:
        return None
    root, records = application_identity_manifest()
    record = records.get(app.desktop_id)
    if not record:
        return None
    masters = record.get("opticalMasters", {})
    if not isinstance(masters, dict):
        return None
    relative = str(masters.get(str(size), "")).strip()
    if not relative or Path(relative).is_absolute():
        return None
    path = (root / relative).resolve()
    if root not in path.parents or not path.is_file():
        return None
    return qicon_file_image(path, size * SMALL_MASTER_SCALE)


@dataclass(frozen=True)
class DesktopApplication:
    desktop_id: str
    source_path: Path
    local_path: Path
    name: str
    icon: str
    source_hash: str

    @property
    def generated_icon_name(self) -> str:
        digest = hashlib.sha256(self.desktop_id.encode("utf-8")).hexdigest()[:24]
        return f"{ICON_PREFIX}.{digest}"


@dataclass(frozen=True)
class IconResolution:
    """The audited way a launcher can receive a Meo application treatment.

    An icon theme has a name namespace, not a desktop-ID namespace.  The
    studio must therefore make the safety decision before writing an overlay
    asset instead of assuming that an Applications-context path isolates it
    from a same-named system semantic icon.
    """

    method: str
    collision_risk: str
    original_fallback: str
    overlay_icon_name: str = ""

    def as_manifest(self) -> dict[str, str]:
        return {
            "method": self.method,
            "collisionRisk": self.collision_risk,
            "originalFallback": self.original_fallback,
            "overlayIconName": self.overlay_icon_name,
        }


def xdg_path(variable: str, fallback: Path) -> Path:
    raw = os.environ.get(variable, "").strip()
    return Path(raw).expanduser() if raw else fallback


def data_roots() -> list[Path]:
    local = xdg_path("XDG_DATA_HOME", Path.home() / ".local/share")
    extra = [Path(part).expanduser() for part in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if part]
    return [local, *extra]


def config_root() -> Path:
    return xdg_path("XDG_CONFIG_HOME", Path.home() / ".config") / "meo-icon-studio"


def cache_root() -> Path:
    return xdg_path("XDG_CACHE_HOME", Path.home() / ".cache") / "meo-icon-studio"


def default_output_root() -> Path:
    return xdg_path("XDG_DATA_HOME", Path.home() / ".local/share")


def kdeglobals_path() -> Path:
    return xdg_path("XDG_CONFIG_HOME", Path.home() / ".config") / "kdeglobals"


def kconfig_parser() -> configparser.ConfigParser:
    """Read permissive KDE INI syntax without rewriting an unrelated file.

    KConfig accepts flag keys such as ``ColorScheme[$d]`` that have no
    ``=value``.  Python's default ConfigParser rejects those valid files, which
    used to make a normal dynamic-color refresh fail before rendering any icon.
    """
    parser = configparser.ConfigParser(interpolation=None, allow_no_value=True,
                                       strict=False)
    parser.optionxform = str
    return parser


def ini_value(path: Path, section_name: str, key: str) -> str:
    parser = kconfig_parser()
    try:
        parser.read(path, encoding="utf-8")
    except (OSError, configparser.Error):
        return ""
    return parser.get(section_name, key, fallback="") or ""


def patch_ini_value(text: str, section_name: str, key: str, value: str | None) -> str:
    """Change one KConfig value while preserving all unrelated content.

    ``None`` means remove the key.  This is intentionally line based: using
    ConfigParser.write() would discard comments, ordering and KConfig flag
    entries from a user's live kdeglobals file.
    """
    lines = text.splitlines(keepends=True)
    result: list[str] = []
    in_section = False
    key_written = False

    def write_missing_key() -> None:
        nonlocal key_written
        if value is not None and not key_written:
            result.append(f"{key}={value}\n")
            key_written = True

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                write_missing_key()
            in_section = stripped == f"[{section_name}]"
            result.append(line)
            continue
        if in_section and stripped.startswith(f"{key}="):
            if value is not None and not key_written:
                result.append(f"{key}={value}\n")
                key_written = True
            continue
        result.append(line)
    if in_section:
        write_missing_key()
    elif value is not None:
        if result and not result[-1].endswith("\n"):
            result[-1] += "\n"
        if result and result[-1].strip():
            result.append("\n")
        result.extend((f"[{section_name}]\n", f"{key}={value}\n"))
    return "".join(result)


def current_kde_icon_theme() -> str:
    return ini_value(kdeglobals_path(), "Icons", "Theme")


def write_kde_icon_theme(theme: str | None) -> None:
    path = kdeglobals_path()
    try:
        current = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        current = ""
    write_atomic(path, patch_ini_value(current, "Icons", "Theme", theme))


def overlay_theme_name(dark: bool) -> str:
    return OVERLAY_THEMES[dark]


def overlay_theme_root(output_root: Path, dark: bool) -> Path:
    return output_root / "icons" / overlay_theme_name(dark)


def overlay_generated_paths(output_root: Path, icon_name: str, dark: bool) -> list[Path]:
    root = overlay_theme_root(output_root, dark)
    return [root / f"{size}x{size}" / "apps" / f"{icon_name}.png"
            for size in RENDER_SIZES]


def overlay_index_text(theme_name: str, inherits: list[str]) -> str:
    directories = ",".join(f"{size}x{size}/apps" for size in RENDER_SIZES)
    sections = "".join(
        f"\n[{size}x{size}/apps]\nSize={size}\nContext=Applications\nType=Fixed\n"
        for size in RENDER_SIZES
    )
    return ("[Icon Theme]\n"
            f"Name={theme_name}\n"
            "Comment=Meo user application icon overlay\n"
            f"Inherits={','.join(inherits)}\n"
            f"Directories={directories}\n"
            f"{sections}")


def overlay_inherits(previous_theme: str, dark: bool) -> list[str]:
    """Return the conservative lookup chain for a user application overlay."""
    values = ["MeoSymbolsDark" if dark else "MeoSymbols"]
    # Preserve a non-Meo user selection below Meo system semantics.  It keeps
    # the app fallback useful without allowing an overlay to inherit itself.
    if previous_theme and previous_theme not in {*OVERLAY_THEMES.values(), *values}:
        values.append(previous_theme)
    if dark:
        values.extend(("breeze-dark", "breeze", "hicolor"))
    else:
        values.extend(("breeze", "hicolor"))
    return list(dict.fromkeys(values))


def ensure_overlay_themes(output_root: Path, previous_theme: str) -> None:
    for dark in (False, True):
        root = overlay_theme_root(output_root, dark)
        root.mkdir(parents=True, exist_ok=True)
        write_atomic(root / "index.theme",
                     overlay_index_text(overlay_theme_name(dark),
                                        overlay_inherits(previous_theme, dark)))


def system_icon_names() -> set[str]:
    """Names already owned by the Meo system-semantic theme.

    Context paths do not form a FreeDesktop namespace, so a same basename is
    unsafe for an app identity overlay even when the caller normally looks in
    Applications. Installed Studio must inspect the package-owned theme under
    the XDG data roots; the source-tree theme is only a developer fallback.
    """
    global SYSTEM_ICON_NAMES
    if SYSTEM_ICON_NAMES is not None:
        return SYSTEM_ICON_NAMES
    names: set[str] = set()
    runtime_roots = [root / "icons" / "MeoSymbols" for root in data_roots()]
    source_root = Path(__file__).resolve().parents[2] / "themes" / "icons" / "MeoSymbols"
    for root in dict.fromkeys([*runtime_roots, source_root]):
        if root.is_dir():
            names.update(path.stem.removesuffix("-symbolic") for path in root.rglob("*.svg"))
    SYSTEM_ICON_NAMES = names
    return names


def icon_resolution(app: DesktopApplication,
                    all_apps: Iterable[DesktopApplication]) -> IconResolution:
    """Classify whether a launcher can safely be switched by icon-name overlay."""
    icon = app.icon.strip()
    if Path(icon).is_absolute():
        return IconResolution(DESKTOP_FALLBACK_METHOD, COLLISION_ABSOLUTE,
                              "source-icon-name")
    if not ICON_NAME_PATTERN.fullmatch(icon):
        return IconResolution(DESKTOP_FALLBACK_METHOD, COLLISION_PRIVATE,
                              "source-icon-name")
    counts = Counter(candidate.icon for candidate in all_apps)
    if (counts[icon] != 1 or icon in system_icon_names()
            or icon in RESERVED_SYSTEM_ICON_NAMES):
        return IconResolution(DESKTOP_FALLBACK_METHOD, COLLISION_SHARED,
                              "source-icon-name")
    return IconResolution(OVERLAY_METHOD, COLLISION_NONE, "theme-lookup", icon)


def overlay_records(manifest: dict) -> list[dict]:
    records = manifest.get("applications", {})
    if not isinstance(records, dict):
        return []
    return [record for record in records.values() if isinstance(record, dict)
            and isinstance(record.get("resolution"), dict)
            and record["resolution"].get("method") == OVERLAY_METHOD]


def activate_overlay_theme(manifest: dict, output_root: Path, dark: bool) -> None:
    overlay = manifest.setdefault("overlay", {})
    if not isinstance(overlay, dict):
        overlay = {}
        manifest["overlay"] = overlay
    current = current_kde_icon_theme()
    previous = str(overlay.get("previousTheme", ""))
    if not overlay.get("active") and current not in OVERLAY_THEMES.values():
        previous = current
    ensure_overlay_themes(output_root, previous)
    target = overlay_theme_name(dark)
    write_kde_icon_theme(target)
    overlay.update({
        "schema": OVERLAY_SCHEMA,
        "active": True,
        "previousTheme": previous,
        "activeTheme": target,
    })


def deactivate_overlay_theme(manifest: dict) -> None:
    overlay = manifest.get("overlay")
    if not isinstance(overlay, dict) or not overlay.get("active"):
        return
    if current_kde_icon_theme() in OVERLAY_THEMES.values():
        previous = str(overlay.get("previousTheme", "")).strip()
        write_kde_icon_theme(previous or None)
    overlay["active"] = False
    overlay["activeTheme"] = ""


def desktop_file_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def desktop_value(text: str, key: str) -> str:
    section = False
    prefix = f"{key}="
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped == f"[{APP_GROUP}]"
            continue
        if section and stripped.startswith(prefix):
            return stripped[len(prefix):].strip()
    return ""


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes"}


def visible_application(path: Path, text: str) -> bool:
    return (desktop_value(text, "Type") == "Application"
            and not truthy(desktop_value(text, "Hidden"))
            and not truthy(desktop_value(text, "NoDisplay")))


def desktop_id_for(root: Path, path: Path) -> str:
    relative = path.relative_to(root / "applications")
    return "-".join(relative.with_suffix("").parts) + ".desktop"


def local_desktop_path(desktop_id: str, output_root: Path) -> Path:
    return output_root / "applications" / desktop_id


def applications(output_root: Path) -> list[DesktopApplication]:
    # First root wins, matching normal XDG desktop-entry precedence.
    seen: set[str] = set()
    result: list[DesktopApplication] = []
    for root in data_roots():
        application_root = root / "applications"
        if not application_root.is_dir():
            continue
        for path in sorted(application_root.rglob("*.desktop")):
            desktop_id = desktop_id_for(root, path)
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            try:
                text = desktop_file_text(path)
            except OSError:
                continue
            if not visible_application(path, text):
                continue
            icon = desktop_value(text, SOURCE_ICON_KEY) if truthy(desktop_value(text, MANAGED_KEY)) else desktop_value(text, "Icon")
            if not icon:
                continue
            result.append(DesktopApplication(
                desktop_id=desktop_id,
                source_path=path,
                local_path=local_desktop_path(desktop_id, output_root),
                name=desktop_value(text, "Name") or desktop_id.removesuffix(".desktop"),
                icon=icon,
                source_hash=hashlib.sha256(text.encode("utf-8")).hexdigest(),
            ))
    return result


def load_config(path: Path) -> dict:
    defaults = {
        "schema": CONFIG_SCHEMA,
        "contractVersion": ICON_CONTRACT_VERSION,
        "style": "monet",
        "shape": "circle",
        "prompt": DEFAULT_PROMPT,
        "applications": {},
        "overlay": {"schema": OVERLAY_SCHEMA, "active": False},
    }
    if not path.exists():
        return defaults
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return defaults
    if not isinstance(payload, dict):
        return defaults
    # Schema 4 records the application-resolution mechanism and the active
    # user icon-theme overlay. Preserve explicit older preferences; the
    # retired ``pure`` spelling is the same renderer as ``monet``.
    payload["schema"] = CONFIG_SCHEMA
    payload.setdefault("contractVersion", ICON_CONTRACT_VERSION)
    payload.setdefault("style", "monet")
    payload.setdefault("shape", "circle")
    if payload["style"] == "pure":
        payload["style"] = "monet"
    payload.setdefault("prompt", DEFAULT_PROMPT)
    payload.setdefault("applications", {})
    if not isinstance(payload["applications"], dict):
        payload["applications"] = {}
    payload.setdefault("overlay", {"schema": OVERLAY_SCHEMA, "active": False})
    if not isinstance(payload["overlay"], dict):
        payload["overlay"] = {"schema": OVERLAY_SCHEMA, "active": False}
    payload["overlay"].setdefault("schema", OVERLAY_SCHEMA)
    payload["overlay"].setdefault("active", False)
    return payload


def save_config(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def parse_color(value: str, fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 3:
        return fallback
    try:
        color = tuple(max(0, min(255, int(part))) for part in parts)
    except ValueError:
        return fallback
    return color if len(color) == 3 else fallback


def scheme_colors(scheme_path: Path) -> dict[str, tuple[int, int, int]]:
    defaults = {
        "surface": (250, 247, 255), "surfaceHigh": (235, 230, 242),
        "primary": (103, 80, 164), "primaryContainer": (234, 221, 255),
        "secondaryContainer": (232, 222, 248), "tertiaryContainer": (255, 216, 228),
        "outline": (121, 116, 126), "onPrimaryContainer": (33, 0, 93),
        "onSurface": (29, 27, 32), "onSurfaceVariant": (73, 69, 79),
    }
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(scheme_path, encoding="utf-8")
    material = parser["MeoMaterial"] if parser.has_section("MeoMaterial") else {}
    button = parser["Colors:Button"] if parser.has_section("Colors:Button") else {}
    selection = parser["Colors:Selection"] if parser.has_section("Colors:Selection") else {}
    window = parser["Colors:Window"] if parser.has_section("Colors:Window") else {}
    return {
        "surface": parse_color(window.get("BackgroundNormal", ""), defaults["surface"]),
        "surfaceHigh": parse_color(material.get("surfaceContainerHigh", button.get("BackgroundAlternate", "")), defaults["surfaceHigh"]),
        "primary": parse_color(material.get("primary", selection.get("BackgroundNormal", "")), defaults["primary"]),
        "primaryContainer": parse_color(material.get("primaryContainer", ""), defaults["primaryContainer"]),
        "secondaryContainer": parse_color(material.get("secondaryContainer", ""), defaults["secondaryContainer"]),
        "tertiaryContainer": parse_color(material.get("tertiaryContainer", ""), defaults["tertiaryContainer"]),
        "outline": parse_color(material.get("outline", ""), defaults["outline"]),
        "onPrimaryContainer": parse_color(material.get("onPrimaryContainer", ""), defaults["onPrimaryContainer"]),
        "onSurface": parse_color(material.get("onSurface", window.get("ForegroundNormal", "")), defaults["onSurface"]),
        "onSurfaceVariant": parse_color(material.get("onSurfaceVariant", button.get("ForegroundInactive", "")), defaults["onSurfaceVariant"]),
    }


def active_kde_is_dark() -> bool:
    """Return the current KDE appearance mode without changing it."""
    scheme = ini_value(kdeglobals_path(), "General", "ColorScheme")
    return "dark" in scheme.casefold()


def default_scheme_path(dark: bool | None = None) -> Path:
    if dark is None:
        dark = active_kde_is_dark()
    name = "MeoDynamicDark.colors" if dark else "MeoDynamicLight.colors"
    return default_output_root() / "color-schemes" / name


def scheme_is_dark(scheme_path: Path) -> bool:
    """Respect an explicit dark scheme in deterministic/staging invocations."""
    name = scheme_path.name.casefold()
    return "dark" in name if "dark" in name or "light" in name else active_kde_is_dark()


def blend(left: tuple[int, int, int], right: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(round(a * (1.0 - amount) + b * amount) for a, b in zip(left, right))


def mono_container_fill(colors: dict[str, tuple[int, int, int]]) -> tuple[int, int, int]:
    """Return the neutral selected-shape surface for a mono app identity.

    The foreground remains the one dynamic onSurface tint. Mixing that
    semantic tone into the active surface at the named contract fraction keeps
    a Circle, Pixel flower, Squircle, or Rounded shape visible in both modes
    without inventing a second brand color.
    """
    return blend(colors["surface"], colors["onSurface"], MONO_CONTAINER_TONE_FRACTION)


def rgba(color: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return (*color, alpha)


def qimage_to_pillow(image) -> Image.Image | None:
    from PySide6.QtCore import QBuffer, QIODevice

    if image.isNull():
        return None
    buffer = QBuffer()
    buffer.open(QIODevice.WriteOnly)
    if not image.save(buffer, "PNG"):
        return None
    return Image.open(__import__("io").BytesIO(bytes(buffer.data()))).convert("RGBA")


def qicon_image(icon_name: str) -> Image.Image | None:
    # Qt handles SVG and theme inheritance correctly.  Force a known base
    # theme so an existing Meo override can never become its own source.
    try:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        from PySide6.QtGui import QGuiApplication, QIcon
    except ImportError:
        return None
    app = QGuiApplication.instance() or QGuiApplication(["meo-app-icon-studio"])
    _ = app
    QIcon.setThemeSearchPaths([str(root / "icons") for root in data_roots()])
    for theme in ("breeze", "Breeze", "hicolor", "Adwaita"):
        QIcon.setThemeName(theme)
        icon = QIcon.fromTheme(icon_name)
        if icon.isNull():
            continue
        rendered = qimage_to_pillow(icon.pixmap(MASTER_SIZE, MASTER_SIZE).toImage())
        if rendered is not None:
            return rendered
    return None


def qicon_file_image(path: Path, size: int = MASTER_SIZE) -> Image.Image | None:
    try:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        from PySide6.QtGui import QGuiApplication, QIcon
    except ImportError:
        return None
    app = QGuiApplication.instance() or QGuiApplication(["meo-app-icon-studio"])
    _ = app
    return qimage_to_pillow(QIcon(str(path)).pixmap(size, size).toImage())


def icon_source_score(path: Path) -> int:
    """Prefer faithful vendor/AppStream artwork over a tiny themed fallback."""
    parts = path.parts
    score = 0
    if "flatpak" in parts or "appstream" in parts:
        score += 500
    if "hicolor" in parts:
        score += 400
    if "pixmaps" in parts:
        score += 350
    if "scalable" in parts:
        score += 160
    for part in parts:
        match = re.fullmatch(r"(\d+)x(\d+)", part)
        if match:
            score += min(150, max(int(match.group(1)), int(match.group(2))) // 2)
    if path.suffix.lower() == ".svg":
        score += 20
    return score


def icon_path_index() -> dict[str, Path]:
    global ICON_PATH_INDEX
    if ICON_PATH_INDEX is not None:
        return ICON_PATH_INDEX
    index: dict[str, Path] = {}
    roots: list[Path] = []
    for root in data_roots():
        roots.extend((root / "icons", root / "pixmaps"))
    # Flatpak keeps faithful application artwork in AppStream, not always in
    # the active icon theme.  It is still local application metadata, so it is
    # a safe source for preserving the user's installed app identity.
    roots.extend((
        default_output_root() / "flatpak" / "appstream",
        Path("/var/lib/flatpak/appstream"),
    ))
    for directory in roots:
        if not directory.is_dir():
            continue
        for directory_path, _, files in os.walk(directory):
            for filename in files:
                path = Path(directory_path) / filename
                if path.suffix.lower() not in ICON_FILE_SUFFIXES or path.stem.startswith(ICON_PREFIX):
                    continue
                relative_parts = path.relative_to(directory).parts
                if ("apps" in relative_parts
                        and any(part.casefold() in GENERATED_OR_SEMANTIC_THEME_NAMES
                                for part in relative_parts)):
                    # MeoSymbols are generic semantic glyphs and MeoUser is a
                    # prior generated overlay. Neither is a valid source for
                    # a brand-preserving application treatment.
                    continue
                current = index.get(path.stem)
                if current is None or icon_source_score(path) > icon_source_score(current):
                    index[path.stem] = path
    ICON_PATH_INDEX = index
    return index


def icon_name_candidates(icon: str) -> list[str]:
    # Freedesktop icon *names* often contain dots (for example
    # `com.obsproject.Studio`); they are not filenames unless they have a
    # recognized raster/vector suffix.
    icon_path = Path(icon)
    icon_name = icon_path.stem if icon_path.suffix.lower() in ICON_FILE_SUFFIXES else icon
    candidates = [icon_name]
    if icon_name.endswith(".desktop"):
        candidates.append(icon_name.removesuffix(".desktop"))
    else:
        candidates.append(icon_name + ".desktop")
    if "." in icon_name:
        candidates.append(icon_name.rsplit(".", 1)[-1])
    candidates.extend(ICON_FALLBACK_ALIASES.get(icon_name, ()))
    return list(dict.fromkeys(candidates))


def direct_icon_path(candidates: Iterable[str]) -> Path | None:
    """Find a named icon by cheap direct probes before a full filesystem scan.

    Common application artwork lives in one of a small set of known
    FreeDesktop directories. Probing those exact filenames preserves the
    existing source-score rules while avoiding an O(all installed icons) walk
    for normal hicolor/Breeze application icons. The exhaustive index remains
    the safe fallback for Flatpak/AppStream and unusual theme layouts.
    """
    names = tuple(dict.fromkeys(str(name) for name in candidates if name))
    if not names:
        return None
    found: list[Path] = []
    for root in data_roots():
        pixmaps = root / "pixmaps"
        for name in names:
            for suffix in ICON_FILE_SUFFIXES:
                path = pixmaps / f"{name}{suffix}"
                if path.is_file():
                    found.append(path)
        icon_root = root / "icons"
        if not icon_root.is_dir():
            continue
        try:
            themes = tuple(path for path in icon_root.iterdir() if path.is_dir())
        except OSError:
            continue
        for theme in themes:
            # Never use Meo's semantic theme as an application-identity
            # source; doing so would turn a later user treatment into a
            # generic category glyph.
            if theme.name.casefold() in GENERATED_OR_SEMANTIC_THEME_NAMES:
                continue
            directories = [theme / "scalable" / context
                           for context in ICON_THEME_CONTEXTS]
            directories.extend(theme / "symbolic" / context
                               for context in ICON_THEME_CONTEXTS)
            try:
                size_roots = tuple(path for path in theme.iterdir()
                                   if path.is_dir() and re.fullmatch(r"\d+x\d+", path.name))
            except OSError:
                size_roots = ()
            for size_root in size_roots:
                directories.extend(size_root / context for context in ICON_THEME_CONTEXTS)
            for directory in directories:
                for name in names:
                    for suffix in ICON_FILE_SUFFIXES:
                        path = directory / f"{name}{suffix}"
                        if path.is_file():
                            found.append(path)
    return max(found, key=icon_source_score, default=None)


def source_image(icon: str) -> Image.Image | None:
    raw_path = Path(icon).expanduser()
    if raw_path.is_file():
        try:
            return Image.open(raw_path).convert("RGBA")
        except OSError:
            return qicon_file_image(raw_path)
    candidates = icon_name_candidates(icon)
    icon_name = candidates[0]
    direct = direct_icon_path(candidates)
    if direct is not None:
        try:
            return Image.open(direct).convert("RGBA")
        except OSError:
            rendered = qicon_file_image(direct)
            if rendered is not None:
                return rendered
    # Qt resolves normal theme inheritance without a filesystem walk. It is
    # intentionally below direct scored files so a vendor hicolor/AppStream
    # asset still wins over a tiny generic theme fallback.
    rendered = qicon_image(icon_name)
    if rendered is not None:
        return rendered
    paths = icon_path_index()
    path = next((paths.get(candidate) for candidate in candidates if paths.get(candidate) is not None), None)
    if path is not None:
        try:
            return Image.open(path).convert("RGBA")
        except OSError:
            rendered = qicon_file_image(path)
            if rendered is not None:
                return rendered
    return None


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def pixel_values(image: Image.Image):
    """Use Pillow's non-deprecated flattened pixel iterator."""
    return image.get_flattened_data()


def foreground_luminance(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if not bounds:
        return 0.5
    crop = image.crop(bounds)
    alpha_values = crop.getchannel("A")
    pixels = list(pixel_values(crop.convert("RGB")))
    weights = list(pixel_values(alpha_values))
    total = sum(weights) or 1
    return sum(((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0) * weight
               for (r, g, b), weight in zip(pixels, weights)) / total


def recolor_alpha(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    result = Image.new("RGBA", image.size, rgba(color, 0))
    result.putalpha(image.getchannel("A"))
    return result


def normalized_symbol(source: Image.Image) -> Image.Image:
    """Extract a palette-independent three-level symbol from app artwork.

    Alpha-only recolouring turns an opaque Chrome logo into a featureless disk.
    Quantised luminance retains its centre and three sectors, Steam's linkage,
    and Obsidian's main facets while remaining independent from wallpaper hue.
    The RGB channel stores a stable layer level; alpha retains holes and edges.
    """
    source = source.copy().convert("RGBA")
    bounds = alpha_bounds(source)
    if bounds:
        source = source.crop(bounds)
    pixels = list(pixel_values(source))
    visible = sorted(
        (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255.0
        for red, green, blue, alpha in pixels if alpha >= 24
    )
    if not visible:
        return source
    # Logos such as Discord and Code OSS use a large flat field with a much
    # smaller white mark.  30/70 quantiles both land on the field and erase
    # that mark, so use robust outer percentiles and split their tonal range.
    low = visible[round((len(visible) - 1) * 0.01)]
    high = visible[round((len(visible) - 1) * 0.99)]
    detailed = high - low >= 0.075
    encoded = Image.new("RGBA", source.size, (0, 0, 0, 0))
    output = []
    for red, green, blue, alpha in pixels:
        if alpha < 1:
            output.append((0, 0, 0, 0))
            continue
        luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255.0
        if not detailed:
            level = 96
        elif luminance <= low + (high - low) * 0.34:
            level = 48
        elif luminance >= low + (high - low) * 0.67:
            level = 224
        else:
            level = 136
        output.append((level, level, level, alpha))
    encoded.putdata(output)
    return encoded


def source_icon_hash(source: Image.Image) -> str:
    """Fingerprint decoded icon pixels, independent of desktop-file metadata."""
    rgba_source = source.convert("RGBA")
    digest = hashlib.sha256()
    digest.update(f"{rgba_source.width}x{rgba_source.height}:RGBA\n".encode("ascii"))
    digest.update(rgba_source.tobytes())
    return digest.hexdigest()


def canonical_identity_source(app: DesktopApplication) -> Image.Image | None:
    """Resolve the original identity which an AI result is allowed to style.

    First-party applications use their reviewed canonical color master; all
    other identities resolve installed original artwork while deliberately
    excluding Meo overlays. Provider artwork is never an identity source.
    """
    return reviewed_color_source(app) or source_image(app.icon)


def canonical_identity_hash(app: DesktopApplication) -> str | None:
    """Fingerprint the original identity which an AI result is allowed to style."""
    source = canonical_identity_source(app)
    return source_icon_hash(source) if source is not None else None


def describe_application(app: DesktopApplication,
                         all_apps: Iterable[DesktopApplication]) -> dict:
    """Return non-secret identity metadata for an Account pack preparation.

    ``DesktopApplication.source_hash`` fingerprints the desktop-entry text and
    is useful only for detecting a changed launcher.  An Account-generated
    material pack instead has to bind the reviewed or installed *icon pixels*
    which Studio will use at commit time.  Keep the two values explicitly
    distinct so a caller cannot accidentally attest the wrong thing.
    """
    identity_hash = canonical_identity_hash(app)
    return {
        "schema": 1,
        "desktopId": app.desktop_id,
        "name": app.name,
        "iconName": app.icon,
        "desktopEntryHash": app.source_hash,
        "canonicalIdentityHash": identity_hash or "",
        "canonicalIdentityAvailable": identity_hash is not None,
        "resolution": icon_resolution(app, all_apps).as_manifest(),
    }


def symbol_for(source: Image.Image, source_hash: str, *, persist: bool) -> Image.Image:
    """Load or create the reusable symbol layer for a source icon revision."""
    cache_path = cache_root() / "symbols" / f"v{SYMBOL_SCHEMA}-{source_hash}.png"
    if cache_path.is_file():
        try:
            return Image.open(cache_path).convert("RGBA")
        except OSError:
            pass
    symbol = normalized_symbol(source)
    if persist:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = cache_path.with_suffix(".png.tmp")
        symbol.save(temporary, "PNG", optimize=True)
        temporary.replace(cache_path)
    return symbol


def colorize_symbol(symbol: Image.Image, colors: dict[str, tuple[int, int, int]],
                    *, monochrome: bool = False,
                    solid_monochrome: bool = False) -> Image.Image:
    surface_dark = foreground_luminance(Image.new("RGBA", (1, 1), rgba(colors["surface"]))) < 0.5
    if monochrome and solid_monochrome:
        # Reviewed first-party mono glyphs carry their own transparent
        # negative space, so Pixel-like themed treatment can be a literal
        # single dynamic tint rather than a simulated three-tone logo.
        return recolor_alpha(symbol, colors["onSurface"])
    if monochrome:
        deep = (245, 245, 245) if surface_dark else (20, 20, 20)
        middle = (205, 205, 205) if surface_dark else (58, 58, 58)
        light = (164, 164, 164) if surface_dark else (98, 98, 98)
    else:
        deep = colors["onPrimaryContainer"]
        middle = blend(deep, colors["primary"], 0.42)
        light = blend(colors["primary"], colors["primaryContainer"], 0.28)
    result = Image.new("RGBA", symbol.size, (0, 0, 0, 0))
    mapped = []
    for level, _green, _blue, alpha in pixel_values(symbol):
        color = deep if level < 96 else middle if level < 192 else light
        mapped.append((*color, alpha))
    result.putdata(mapped)
    return result


def normalized_easel_asset(source: Image.Image) -> Image.Image:
    """Keep AI texture as palette-independent continuous luminance + alpha."""
    source = source.copy().convert("RGBA")
    bounds = alpha_bounds(source)
    if bounds:
        source = source.crop(bounds)
    output = []
    for red, green, blue, alpha in pixel_values(source):
        luminance = round(0.2126 * red + 0.7152 * green + 0.0722 * blue)
        output.append((luminance, luminance, luminance, alpha))
    asset = Image.new("RGBA", source.size, (0, 0, 0, 0))
    asset.putdata(output)
    return asset


def colorize_easel_asset(asset: Image.Image,
                         colors: dict[str, tuple[int, int, int]]) -> Image.Image:
    """Map texture continuously through the active Monet foreground ramp."""
    deep = colors["onPrimaryContainer"]
    middle = blend(deep, colors["primary"], 0.58)
    light = blend(colors["primary"], colors["primaryContainer"], 0.18)
    # Build the continuous 8-bit ramp once.  Applying an AI material should
    # not call three-channel floating-point blending for every texture pixel.
    ramp = []
    for level in range(256):
        amount = level / 255.0
        ramp.append(blend(deep, middle, amount * 2.0) if amount < 0.5
                    else blend(middle, light, (amount - 0.5) * 2.0))
    output = []
    for level, _green, _blue, alpha in pixel_values(asset):
        color = ramp[level]
        output.append((*color, alpha))
    result = Image.new("RGBA", asset.size, (0, 0, 0, 0))
    result.putdata(output)
    return result


def ai_asset_path(app: DesktopApplication) -> Path:
    return cache_root() / "ai-assets" / f"v1-{app.generated_icon_name}.png"


def save_ai_asset(app: DesktopApplication, asset: Image.Image) -> None:
    path = ai_asset_path(app)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".png.tmp")
    asset.save(temporary, "PNG", optimize=True)
    temporary.replace(path)


def symbol_needs_original_fallback(source: Image.Image, symbol: Image.Image) -> bool:
    """Reject a solid opaque mask when the source still contains real detail."""
    source_pixels = [pixel for pixel in pixel_values(source.convert("RGBA")) if pixel[3] >= 24]
    if not source_pixels:
        return False
    symbol_levels = {red for red, _green, _blue, alpha in pixel_values(symbol) if alpha >= 24}
    opaque_ratio = sum(1 for *_rgb, alpha in source_pixels if alpha >= 240) / len(source_pixels)
    color_bins = {(red // 32, green // 32, blue // 32)
                  for red, green, blue, _alpha in source_pixels}
    return len(symbol_levels) < 2 and opaque_ratio >= 0.80 and len(color_bins) >= 2


def fit_square(image: Image.Image, maximum_side: int) -> Image.Image:
    """Scale a mark to its optical box, including low-resolution legacy icons."""
    if image.width < 1 or image.height < 1:
        return image
    scale = min(maximum_side / image.width, maximum_side / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def container_mask(box: tuple[int, int, int, int], shape: str,
                   master_size: int = MASTER_SIZE) -> Image.Image:
    """Return a shared themed-icon mask with clean, non-overlapping outlines."""
    mask = Image.new("L", (master_size, master_size), 0)
    draw = ImageDraw.Draw(mask)
    left, top, right, bottom = box
    size = right - left
    if shape == "circle":
        draw.ellipse(box, fill=255)
    elif shape == "squircle":
        draw.rounded_rectangle(box, radius=grid_pixels(SQUIRCLE_RADIUS_UNITS, master_size), fill=255)
    elif shape == "rounded":
        draw.rounded_rectangle(box, radius=grid_pixels(ROUNDED_RADIUS_UNITS, master_size), fill=255)
    else:
        # An eight-petal Material/Pixel flower: a central 12u disk joined to
        # 8u lobes at a 12u offset. Diagonal centers use exactly 1/sqrt(2),
        # rather than an unexplained decimal approximation. Rendering it as
        # one alpha mask avoids seams from separately drawn circles.
        center_x = (left + right) / 2
        center_y = (top + bottom) / 2
        center_radius = grid_pixels(PIXEL_FLOWER_CENTER_RADIUS_UNITS, master_size)
        lobe_radius = grid_pixels(PIXEL_FLOWER_LOBE_RADIUS_UNITS, master_size)
        offset = grid_pixels(PIXEL_FLOWER_LOBE_OFFSET_UNITS, master_size)
        draw.ellipse((center_x - center_radius, center_y - center_radius,
                      center_x + center_radius, center_y + center_radius), fill=255)
        for direction_x, direction_y in ((1, 0), (1, 1), (0, 1), (-1, 1),
                                          (-1, 0), (-1, -1), (0, -1), (1, -1)):
            diagonal = 1 / sqrt(2) if direction_x and direction_y else 1
            x = center_x + direction_x * offset * diagonal
            y = center_y + direction_y * offset * diagonal
            draw.ellipse((x - lobe_radius, y - lobe_radius,
                          x + lobe_radius, y + lobe_radius), fill=255)
    return mask


def draw_themed_container(canvas: Image.Image, box: tuple[int, int, int, int], shape: str,
                          fill: tuple[int, int, int], outline: tuple[int, int, int] | None,
                          master_size: int = MASTER_SIZE) -> None:
    mask = container_mask(box, shape, master_size)
    if outline is not None:
        # Expand only the silhouette; the filled mask below covers the inner
        # edge, yielding one calm MD outline rather than a line around petals.
        outline_mask = mask.filter(ImageFilter.MaxFilter(
            OUTLINE_DILATION_HALF_WIDTH_PX * 2 + 1))
        canvas.paste(rgba(outline, 112), mask=outline_mask)
    canvas.paste(rgba(fill), mask=mask)


def render_icon(source: Image.Image, style: str, colors: dict[str, tuple[int, int, int]], seed: str,
                shape: str = "circle", symbol: Image.Image | None = None,
                master_size: int = MASTER_SIZE,
                solid_monochrome: bool = False) -> Image.Image:
    if shape not in SHAPES:
        raise ValueError(f"Unsupported icon shape: {shape}")
    source = source.copy().convert("RGBA")
    source_bounds = alpha_bounds(source)
    if source_bounds:
        source = source.crop(source_bounds)
    canvas = Image.new("RGBA", (master_size, master_size), (0, 0, 0, 0))
    box = application_container_box(master_size)
    container_size = box[2] - box[0]
    normalized_style = "monet" if style == "pure" else style
    symbol = symbol or normalized_symbol(source)
    surface_dark = foreground_luminance(Image.new("RGBA", (1, 1), rgba(colors["surface"]))) < 0.5
    if normalized_style == "original":
        fill = blend(colors["surfaceHigh"], colors["primaryContainer"], 0.22)
        foreground = source
    elif normalized_style == "monet":
        fill = blend(colors["surface"], colors["primaryContainer"], 0.14 if not surface_dark else 0.28)
        foreground = (source if symbol_needs_original_fallback(source, symbol)
                      else colorize_symbol(symbol, colors))
    else:
        fill = mono_container_fill(colors)
        foreground = colorize_symbol(symbol, colors, monochrome=True,
                                     solid_monochrome=solid_monochrome)
    draw_themed_container(canvas, box, shape, fill,
                          colors["outline"] if normalized_style == "original" else None,
                          master_size)
    bounds = alpha_bounds(foreground)
    if bounds:
        foreground = foreground.crop(bounds)
    max_side = grid_pixels(PIXEL_FOREGROUND_UNITS if shape == "pixel"
                           else APP_FOREGROUND_UNITS, master_size)
    foreground = fit_square(foreground, max_side)
    position = ((master_size - foreground.width) // 2, (master_size - foreground.height) // 2)
    canvas.alpha_composite(foreground, dest=position)
    return canvas


def render_ai_identity_foreground(material_source: Image.Image, identity_source: Image.Image,
                                  colors: dict[str, tuple[int, int, int]],
                                  structural_mask_source: Image.Image | None = None) -> Image.Image:
    """Apply provider material to a fixed canonical identity, never vice versa.

    The provider may vary texture and tonal grain, but it cannot choose the
    logo silhouette, erase approved negative space, add lettering, or replace
    a first-party identity with a generic generated picture.  The normalized
    canonical symbol supplies alpha and its internal tonal structure; the AI
    raster supplies only a color-neutral material field.
    """
    # No delivered application icon exceeds 512px. Normalize at that bounded
    # canonical working size rather than quantising a provider-independent
    # 1024px SVG raster only to downsample it again moments later.
    symbol = normalized_symbol(fit_square(identity_source, AI_IDENTITY_WORK_SIDE))
    bounds = alpha_bounds(symbol)
    if not bounds:
        return Image.new("RGBA", symbol.size, (0, 0, 0, 0))
    identity_alpha = symbol.getchannel("A")
    if structural_mask_source is not None:
        structural_symbol = normalized_symbol(
            fit_square(structural_mask_source, AI_IDENTITY_WORK_SIDE))
        structural_alpha = structural_symbol.getchannel("A")
        # The reviewed mask is an intersection: it can preserve a canonical
        # transparent cut, but cannot create visible geometry outside the
        # original identity alpha.
        identity_alpha = ImageChops.multiply(identity_alpha, structural_alpha)
        if identity_alpha.getbbox() is None:
            return Image.new("RGBA", symbol.size, (0, 0, 0, 0))
    material = fit_square(normalized_easel_asset(material_source), AI_MATERIAL_SAMPLE_SIDE)
    # A provider's alpha is not allowed to redefine the mark.  Identity alpha
    # remains the sole geometry authority; material alpha merely arrived with
    # the provider image and is discarded after its luminance was sampled.
    material.putalpha(255)
    textured = colorize_easel_asset(material, colors)
    textured = textured.resize(symbol.size, Image.Resampling.LANCZOS)
    textured.putalpha(identity_alpha)
    # Preserve canonical internal cuts/regions above the material so an
    # opaque multicolour original remains recognisable at launcher scale.
    detail = colorize_symbol(symbol, colors)
    detail_alpha = ImageChops.multiply(detail.getchannel("A"), identity_alpha)
    detail_alpha = detail_alpha.point(lambda alpha: round(alpha * 0.38))
    detail.putalpha(detail_alpha)
    textured.alpha_composite(detail)
    return textured


def render_ai_icon(material_source: Image.Image, identity_source: Image.Image,
                   colors: dict[str, tuple[int, int, int]],
                   shape: str = "circle",
                   structural_mask_source: Image.Image | None = None,
                   master_size: int = MASTER_SIZE) -> Image.Image:
    """Render approved AI material inside a canonical application identity.

    This intentionally differs from an unrestricted image-to-icon pipeline:
    generated artwork is not fitted directly to the launcher silhouette.  It
    is used only as material on the installed/reviewed app mark, then that mark
    is placed once inside the selected Meo container.
    """
    if shape not in SHAPES:
        raise ValueError(f"Unsupported icon shape: {shape}")
    canvas = Image.new("RGBA", (master_size, master_size), (0, 0, 0, 0))
    box = application_container_box(master_size)
    surface_dark = foreground_luminance(Image.new("RGBA", (1, 1), rgba(colors["surface"]))) < 0.5
    fill = blend(colors["surface"], colors["primaryContainer"],
                 0.28 if surface_dark else 0.14)
    draw_themed_container(canvas, box, shape, fill, None)
    foreground = render_ai_identity_foreground(material_source, identity_source, colors,
                                                structural_mask_source)
    bounds = alpha_bounds(foreground)
    if bounds:
        foreground = foreground.crop(bounds)
    max_side = grid_pixels(PIXEL_FOREGROUND_UNITS if shape == "pixel"
                           else APP_FOREGROUND_UNITS, master_size)
    foreground = fit_square(foreground, max_side)
    position = ((master_size - foreground.width) // 2,
                (master_size - foreground.height) // 2)
    canvas.alpha_composite(foreground, dest=position)
    return canvas


def render_ai_variants(app: DesktopApplication, material_source: Image.Image,
                       identity_source: Image.Image,
                       colors: dict[str, tuple[int, int, int]],
                       shape: str) -> dict[int, Image.Image]:
    """Render AI material with reviewed structural detail at delivery sizes."""
    structural_mask = reviewed_ai_structural_source(app)
    canonical = render_ai_icon(material_source, identity_source, colors, shape,
                               structural_mask_source=structural_mask)
    variants = {size: canonical for size in RENDER_SIZES}
    # A normal 1024px master is enough for identities without a reviewed
    # structure. For identities such as OmniStore, rasterise the transparent
    # review mask at each optical output master before downsampling, so its
    # small canonical cuts survive instead of becoming colour-only noise.
    if structural_mask is None:
        return variants
    for size in OPTICAL_RENDER_SIZES:
        small_structural_mask = reviewed_ai_structural_source(app,
                                                               size * SMALL_MASTER_SCALE)
        variants[size] = render_ai_icon(
            material_source, identity_source, colors, shape,
            structural_mask_source=small_structural_mask or structural_mask,
            master_size=size * SMALL_MASTER_SCALE)
    return variants


def generated_paths(output_root: Path, generated_name: str) -> list[Path]:
    return [output_root / "icons" / "hicolor" / f"{size}x{size}" / "apps" / f"{generated_name}.png"
            for size in RENDER_SIZES]


def render_deterministic_variants(app: DesktopApplication, source: Image.Image, style: str,
                                  colors: dict[str, tuple[int, int, int]], seed: str,
                                  shape: str, symbol: Image.Image,
                                  *, solid_monochrome: bool = False) -> dict[int, Image.Image]:
    """Render canonical artwork plus audited optical masters where available."""
    canonical = render_icon(source, style, colors, seed, shape, symbol,
                            solid_monochrome=solid_monochrome)
    variants = {size: canonical for size in RENDER_SIZES}
    normalized_style = "monet" if style == "pure" else style
    if normalized_style != "monet":
        return variants
    for size in OPTICAL_RENDER_SIZES:
        optical = reviewed_optical_source(app, size)
        if optical is None:
            continue
        variants[size] = render_icon(optical, normalized_style, colors, seed, shape,
                                     normalized_symbol(optical),
                                     size * SMALL_MASTER_SCALE)
    return variants


def write_rendered_icon(rendered: Image.Image | Mapping[int, Image.Image],
                        destinations: Iterable[Path]) -> None:
    for destination in destinations:
        destination.parent.mkdir(parents=True, exist_ok=True)
        size = int(destination.parent.parent.name.split("x")[0])
        source = rendered.get(size) if isinstance(rendered, Mapping) else rendered
        if source is None:
            raise ValueError(f"No rendered icon master for {size}px output")
        source.resize((size, size), Image.Resampling.LANCZOS).save(
            destination, "PNG", optimize=True)


def remove_files(paths: Iterable[Path]) -> None:
    for path in paths:
        if path.is_file() or path.is_symlink():
            path.unlink()


def ensure_hicolor_index(output_root: Path) -> None:
    # hicolor may already be supplied by /usr.  A user-local index is only
    # needed when a test/staging root has no inherited one.
    index = output_root / "icons" / "hicolor" / "index.theme"
    if index.exists():
        return
    index.parent.mkdir(parents=True, exist_ok=True)
    index.write_text(
        "[Icon Theme]\nName=hicolor\nComment=Fallback icon theme\n"
        "Directories=16x16/apps,22x22/apps,32x32/apps,128x128/apps,256x256/apps,512x512/apps\n\n"
        "[16x16/apps]\nSize=16\nContext=Applications\nType=Fixed\n\n"
        "[22x22/apps]\nSize=22\nContext=Applications\nType=Fixed\n\n"
        "[32x32/apps]\nSize=32\nContext=Applications\nType=Fixed\n\n"
        "[128x128/apps]\nSize=128\nContext=Applications\nType=Fixed\n\n"
        "[256x256/apps]\nSize=256\nContext=Applications\nType=Fixed\n\n"
        "[512x512/apps]\nSize=512\nContext=Applications\nType=Fixed\n",
        encoding="utf-8",
    )


def patch_desktop_icon(text: str, icon_name: str, source_hash: str, source_icon: str) -> str:
    lines = text.splitlines(keepends=True)
    section = False
    icon_written = managed_written = hash_written = source_icon_written = False
    result: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if section:
                if not icon_written:
                    result.append(f"Icon={icon_name}\n")
                if not managed_written:
                    result.append(f"{MANAGED_KEY}=true\n")
                if not hash_written:
                    result.append(f"{SOURCE_HASH_KEY}={source_hash}\n")
                if not source_icon_written:
                    result.append(f"{SOURCE_ICON_KEY}={source_icon}\n")
            section = stripped == f"[{APP_GROUP}]"
        if section and stripped.startswith("Icon="):
            result.append(f"Icon={icon_name}\n")
            icon_written = True
        elif section and stripped.startswith(f"{MANAGED_KEY}="):
            result.append(f"{MANAGED_KEY}=true\n")
            managed_written = True
        elif section and stripped.startswith(f"{SOURCE_HASH_KEY}="):
            result.append(f"{SOURCE_HASH_KEY}={source_hash}\n")
            hash_written = True
        elif section and stripped.startswith(f"{SOURCE_ICON_KEY}="):
            result.append(f"{SOURCE_ICON_KEY}={source_icon}\n")
            source_icon_written = True
        else:
            result.append(line)
    if section:
        if not icon_written:
            result.append(f"Icon={icon_name}\n")
        if not managed_written:
            result.append(f"{MANAGED_KEY}=true\n")
        if not hash_written:
            result.append(f"{SOURCE_HASH_KEY}={source_hash}\n")
        if not source_icon_written:
            result.append(f"{SOURCE_ICON_KEY}={source_icon}\n")
    return "".join(result)


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".meo-tmp")
    temporary.write_text(text, encoding="utf-8")
    temporary.replace(path)


def dock_config_path() -> Path:
    return config_root().parent / "meodockrc"


def write_dock_icon_modes(apps: list[DesktopApplication], style: str,
                          global_default: bool) -> None:
    """Mirror application rendering choices into the Dock's KConfig file."""
    path = dock_config_path()
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    if path.exists():
        parser.read(path, encoding="utf-8")
    if not parser.has_section("General"):
        parser.add_section("General")
    if not parser.has_section("IconOverrides"):
        parser.add_section("IconOverrides")
    dock_mode = {"original": "original", "pure": "tonal", "monet": "tonal",
                 "mono": "mono", "ai": "ai"}[style]
    if global_default:
        parser.set("General", "IconMode", dock_mode)
        for app in apps:
            parser.remove_option(
                "IconOverrides", quote(app.desktop_id.removesuffix(".desktop"), safe=""))
    else:
        for app in apps:
            parser.set("IconOverrides",
                       quote(app.desktop_id.removesuffix(".desktop"), safe=""),
                       dock_mode)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".meo-tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        parser.write(stream, space_around_delimiters=False)
    temporary.replace(path)


def remove_dock_icon_modes(apps: list[DesktopApplication]) -> None:
    path = dock_config_path()
    if not path.exists():
        return
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    if parser.has_section("IconOverrides"):
        for app in apps:
            parser.remove_option(
                "IconOverrides", quote(app.desktop_id.removesuffix(".desktop"), safe=""))
    temporary = path.with_suffix(path.suffix + ".meo-tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        parser.write(stream, space_around_delimiters=False)
    temporary.replace(path)


def activate_desktop_entry(app: DesktopApplication, manifest: dict,
                           style: str = "monet", shape: str = "circle",
                           prompt: str = DEFAULT_PROMPT) -> None:
    existing = app.local_path.exists()
    source_text = desktop_file_text(app.local_path if existing else app.source_path)
    original_icon = desktop_value(source_text, "Icon")
    records = manifest.setdefault("applications", {})
    previous = records.get(app.desktop_id, {})
    records[app.desktop_id] = {
        "createdLocalOverride": bool(previous.get("createdLocalOverride", not existing)),
        "originalIcon": previous.get("originalIcon", original_icon),
        "generatedIconName": app.generated_icon_name,
        "sourceHash": app.source_hash,
        "style": style,
        "shape": shape,
        # A fallback entry needs no reusable raw prompt: it stores an asset,
        # not provider input. Keep the top-level editable preference separate
        # and retain only auditable recipe provenance per application.
        "promptRecipeVersion": "v1",
        "promptHash": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
    }
    original_icon = str(records[app.desktop_id]["originalIcon"])
    write_atomic(app.local_path, patch_desktop_icon(source_text, app.generated_icon_name,
                                                     app.source_hash, original_icon))


def activate_overlay_entry(app: DesktopApplication, manifest: dict,
                           resolution: IconResolution, style: str,
                           shape: str, prompt: str, output_root: Path) -> None:
    """Record an overlay-managed app without creating a desktop entry copy."""
    if resolution.method != OVERLAY_METHOD or not resolution.overlay_icon_name:
        raise ValueError("overlay activation requires a name-safe resolution")
    records = manifest.setdefault("applications", {})
    previous = records.get(app.desktop_id, {})
    # A legacy studio record may have changed Icon= to a unique hicolor name.
    # Restore it before switching to the identity's real icon name, otherwise
    # the overlay would never be consulted by KIconTheme.
    previous_resolution = previous.get("resolution", {}) if isinstance(previous, dict) else {}
    if not isinstance(previous_resolution, dict):
        previous_resolution = {}
    if isinstance(previous, dict) and previous_resolution.get("method") != OVERLAY_METHOD:
        restore_desktop_entry(app, previous)
        remove_files(generated_paths(output_root, app.generated_icon_name))
    records[app.desktop_id] = {
        "originalIcon": str(previous.get("originalIcon", app.icon)) if isinstance(previous, dict) else app.icon,
        "overlayIconName": resolution.overlay_icon_name,
        "sourceHash": app.source_hash,
        "style": style,
        "shape": shape,
        # The editable user preference remains top-level; pack provenance
        # stores only a recipe hash/version, never one per-app full prompt.
        "promptRecipeVersion": "v1",
        "promptHash": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
        "resolution": resolution.as_manifest(),
    }


def remove_overlay_entry_assets(app: DesktopApplication, record: dict, output_root: Path) -> None:
    resolution = record.get("resolution", {}) if isinstance(record, dict) else {}
    if not isinstance(resolution, dict) or resolution.get("method") != OVERLAY_METHOD:
        return
    icon_name = str(resolution.get("overlayIconName", record.get("overlayIconName", app.icon))).strip()
    if not icon_name:
        return
    for dark in (False, True):
        remove_files(overlay_generated_paths(output_root, icon_name, dark))


def restore_desktop_entry(app: DesktopApplication, record: dict) -> None:
    if not app.local_path.exists():
        return
    text = desktop_file_text(app.local_path)
    if desktop_value(text, MANAGED_KEY).lower() != "true":
        return
    if record.get("createdLocalOverride"):
        app.local_path.unlink()
        return
    original_icon = str(record.get("originalIcon", ""))
    lines = []
    section = False
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped == f"[{APP_GROUP}]"
        if section and (stripped.startswith("Icon=") or stripped.startswith(f"{MANAGED_KEY}=")
                        or stripped.startswith(f"{SOURCE_HASH_KEY}=")
                        or stripped.startswith(f"{SOURCE_ICON_KEY}=")):
            if stripped.startswith("Icon=") and original_icon:
                lines.append(f"Icon={original_icon}\n")
            continue
        lines.append(line)
    write_atomic(app.local_path, "".join(lines))


def refresh_kde_caches(output_root: Path) -> None:
    theme_roots = [output_root / "icons" / "hicolor"]
    theme_roots.extend(overlay_theme_root(output_root, dark) for dark in (False, True))
    commands = []
    for root in theme_roots:
        if root.is_dir():
            # The icon-theme specification allows caches to use the top-level
            # theme directory mtime as their freshness signal.
            root.touch(exist_ok=True)
            commands.append(("gtk-update-icon-cache", ["-f", str(root)]))
    # A staging root is useful for validation and must not mutate the live KDE
    # service cache.  Runtime application uses the normal XDG data root.
    if output_root.resolve() == default_output_root().resolve():
        commands.append(("kbuildsycoca6", ["--noincremental"]))
    for program, arguments in commands:
        executable = shutil.which(program)
        if executable:
            subprocess.run([executable, *arguments], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           check=False, timeout=30)


def select_apps(all_apps: list[DesktopApplication], ids: Iterable[str]) -> list[DesktopApplication]:
    requested = set(ids)
    if not requested:
        return all_apps
    available = {app.desktop_id: app for app in all_apps}
    missing = sorted(requested - set(available))
    if missing:
        raise ValueError("Unknown application id: " + ", ".join(missing))
    return [available[desktop_id] for desktop_id in sorted(requested)]


def apply(apps: list[DesktopApplication], style: str, shape: str, prompt: str, output_root: Path,
          scheme_path: Path, dry_run: bool, global_default: bool = True,
          update_global_preferences: bool = True, refresh: bool = True,
          all_apps: Iterable[DesktopApplication] | None = None) -> dict:
    style = "monet" if style == "pure" else style
    if style == "original":
        result = reset(apps, output_root, dry_run)
        result.update({"style": "original", "shape": "follow-original",
                       "scheme": str(scheme_path)})
        if not dry_run and update_global_preferences:
            manifest_path = config_root() / "manifest.json"
            manifest = load_config(manifest_path)
            manifest["style"] = "original"
            manifest["shape"] = "circle"
            manifest["prompt"] = prompt
            save_config(manifest_path, manifest)
        return result

    colors = scheme_colors(scheme_path)
    manifest_path = config_root() / "manifest.json"
    manifest = load_config(manifest_path)
    if update_global_preferences:
        manifest["style"] = style
        manifest["shape"] = shape
        manifest["prompt"] = prompt
    candidates = list(all_apps) if all_apps is not None else apps
    summary = {"rendered": [], "skipped": [], "style": style, "shape": shape,
               "scheme": str(scheme_path), "overlay": [], "fallback": []}
    legacy_apps: list[DesktopApplication] = []
    overlay_written = False
    for app in apps:
        normalized_style = "monet" if style == "pure" else style
        reviewed_mono = reviewed_mono_source(app) if normalized_style == "mono" else None
        reviewed_color = reviewed_color_source(app) if normalized_style == "monet" else None
        source = reviewed_mono or reviewed_color or source_image(app.icon)
        if source is None:
            reason = ("reviewed monochrome glyph and original icon could not be resolved"
                      if normalized_style == "mono" else "original icon could not be resolved")
            summary["skipped"].append({"desktopId": app.desktop_id, "reason": reason})
            continue
        identity_source = ("reviewed-mono" if reviewed_mono is not None
                           else "reviewed-color" if reviewed_color is not None
                           else "original-artwork")
        icon_hash = source_icon_hash(source)
        symbol = symbol_for(source, icon_hash, persist=not dry_run)
        rendered = render_deterministic_variants(
            app, source, style, colors, app.desktop_id, shape, symbol,
            solid_monochrome=reviewed_mono is not None)
        resolution = icon_resolution(app, candidates)
        if not dry_run:
            if resolution.method == OVERLAY_METHOD:
                overlay = manifest.get("overlay", {})
                previous_theme = str(overlay.get("previousTheme", "")) if isinstance(overlay, dict) else ""
                if not previous_theme and current_kde_icon_theme() not in OVERLAY_THEMES.values():
                    previous_theme = current_kde_icon_theme()
                ensure_overlay_themes(output_root, previous_theme)
                for dark in (False, True):
                    write_rendered_icon(rendered,
                                        overlay_generated_paths(output_root,
                                                                resolution.overlay_icon_name,
                                                                dark))
                activate_overlay_entry(app, manifest, resolution, style, shape, prompt, output_root)
                overlay_written = True
            else:
                ensure_hicolor_index(output_root)
                write_rendered_icon(rendered, generated_paths(output_root, app.generated_icon_name))
                remove_overlay_entry_assets(app, manifest.get("applications", {}).get(app.desktop_id, {}),
                                            output_root)
                activate_desktop_entry(app, manifest, style, shape, prompt)
                manifest["applications"][app.desktop_id]["resolution"] = resolution.as_manifest()
                legacy_apps.append(app)
            manifest["applications"][app.desktop_id]["symbolHash"] = icon_hash
            manifest["applications"][app.desktop_id]["symbolSchema"] = SYMBOL_SCHEMA
            manifest["applications"][app.desktop_id]["identitySource"] = identity_source
        target_icon = resolution.overlay_icon_name if resolution.method == OVERLAY_METHOD else app.generated_icon_name
        summary["rendered"].append({"desktopId": app.desktop_id,
                                    "icon": target_icon,
                                    "symbolHash": icon_hash,
                                    "symbolSchema": SYMBOL_SCHEMA,
                                    "identitySource": identity_source,
                                    "resolution": resolution.as_manifest()})
        summary["overlay" if resolution.method == OVERLAY_METHOD else "fallback"].append(app.desktop_id)
    if not dry_run:
        if overlay_written:
            activate_overlay_theme(manifest, output_root, scheme_is_dark(scheme_path))
        elif not overlay_records(manifest):
            deactivate_overlay_theme(manifest)
        save_config(manifest_path, manifest)
        # A retired standalone Dock consumed this config.  Retain it only for
        # legacy desktop-fallback migration, never as the truth for overlay
        # behavior; Plasma's real task manager resolves KIconTheme directly.
        if legacy_apps:
            write_dock_icon_modes(legacy_apps, style, global_default)
        if refresh:
            refresh_kde_caches(output_root)
    return summary


def load_ai_material(image_path: Path) -> Image.Image:
    """Decode a staged provider raster before it can enter an atomic commit."""
    if not image_path.is_file() or image_path.stat().st_size > 12_000_000:
        raise ValueError("The generated image is missing or too large")
    try:
        with Image.open(image_path) as opened:
            width, height = opened.size
            if width < 1 or height < 1 or width * height > AI_MAX_IMAGE_PIXELS:
                raise ValueError("The generated image dimensions are unsupported")
            source = opened.convert("RGBA")
            source.load()
    except ValueError:
        raise
    except Exception as error:
        raise ValueError("The generated image is not a supported image") from error
    if alpha_bounds(source) is None:
        raise ValueError("The generated image has no visible material")
    return source


def apply_ai(app: DesktopApplication, image_path: Path, shape: str, prompt: str,
             output_root: Path, scheme_path: Path, dry_run: bool,
             *, refresh: bool = True,
             all_apps: Iterable[DesktopApplication] | None = None,
             identity_source: Image.Image | None = None,
             material_asset: Image.Image | None = None) -> dict:
    """Activate one consent-produced image without changing other apps."""
    if identity_source is None:
        identity_source = canonical_identity_source(app)
    if identity_source is None:
        raise ValueError("The current application identity could not be resolved")
    colors = scheme_colors(scheme_path)
    # Account's style-pack contract permits every selected identity to share
    # one approved generated material.  Keep it immutable here so a single
    # provider response is normalized once and applied to canonical local
    # identity sources, rather than asking a provider to redraw every logo.
    asset = material_asset if material_asset is not None else normalized_easel_asset(
        load_ai_material(image_path))
    rendered = render_ai_variants(app, asset, identity_source, colors, shape)
    summary = {"rendered": [], "skipped": [], "style": "ai", "shape": shape,
               "scheme": str(scheme_path), "overlay": [], "fallback": []}
    candidates = list(all_apps) if all_apps is not None else [app]
    resolution = icon_resolution(app, candidates)
    if not dry_run:
        save_ai_asset(app, asset)
        manifest_path = config_root() / "manifest.json"
        manifest = load_config(manifest_path)
        if resolution.method == OVERLAY_METHOD:
            overlay = manifest.get("overlay", {})
            previous_theme = str(overlay.get("previousTheme", "")) if isinstance(overlay, dict) else ""
            if not previous_theme and current_kde_icon_theme() not in OVERLAY_THEMES.values():
                previous_theme = current_kde_icon_theme()
            ensure_overlay_themes(output_root, previous_theme)
            for dark in (False, True):
                write_rendered_icon(rendered,
                                    overlay_generated_paths(output_root,
                                                            resolution.overlay_icon_name,
                                                            dark))
            activate_overlay_entry(app, manifest, resolution, "ai", shape, prompt, output_root)
            activate_overlay_theme(manifest, output_root, scheme_is_dark(scheme_path))
        else:
            ensure_hicolor_index(output_root)
            write_rendered_icon(rendered, generated_paths(output_root, app.generated_icon_name))
            remove_overlay_entry_assets(app, manifest.get("applications", {}).get(app.desktop_id, {}),
                                        output_root)
            activate_desktop_entry(app, manifest, "ai", shape, prompt)
            manifest["applications"][app.desktop_id]["resolution"] = resolution.as_manifest()
            # Keep the obsolete standalone Dock compatibility one-way: an
            # overlay does not rely on this file, but legacy fallbacks retain
            # their prior visual mode until migration is complete.
            write_dock_icon_modes([app], "ai", global_default=False)
        if resolution.method != OVERLAY_METHOD and not overlay_records(manifest):
            deactivate_overlay_theme(manifest)
        save_config(manifest_path, manifest)
        if refresh:
            refresh_kde_caches(output_root)
    target_icon = resolution.overlay_icon_name if resolution.method == OVERLAY_METHOD else app.generated_icon_name
    summary["rendered"].append({"desktopId": app.desktop_id,
                                "icon": target_icon,
                                "resolution": resolution.as_manifest()})
    summary["overlay" if resolution.method == OVERLAY_METHOD else "fallback"].append(app.desktop_id)
    return summary


def refresh_managed(apps: list[DesktopApplication], output_root: Path,
                    scheme_path: Path, dry_run: bool,
                    all_apps: Iterable[DesktopApplication] | None = None) -> dict:
    """Recolor each managed app from its own deterministic or AI source."""
    manifest = load_config(config_root() / "manifest.json")
    records = manifest.get("applications", {})
    summary = {"rendered": [], "skipped": [], "managedOnly": True,
               "scheme": str(scheme_path)}
    deterministic: dict[tuple[str, str, str], list[DesktopApplication]] = {}
    candidates = list(all_apps) if all_apps is not None else apps
    for app in apps:
        record = records.get(app.desktop_id, {})
        style = str(record.get("style", "monet"))
        shape = str(record.get("shape", "circle"))
        prompt = str(record.get("prompt", manifest.get("prompt", DEFAULT_PROMPT)))
        if style != "ai":
            deterministic.setdefault((style, shape, prompt), []).append(app)
            continue
        path = ai_asset_path(app)
        if not path.is_file():
            summary["skipped"].append({"desktopId": app.desktop_id,
                                       "reason": "AI texture asset is unavailable"})
            continue
        with Image.open(path) as opened:
            asset = opened.convert("RGBA")
            asset.load()
        identity_source = canonical_identity_source(app)
        if identity_source is None:
            summary["skipped"].append({"desktopId": app.desktop_id,
                                       "reason": "current application identity is unavailable"})
            continue
        rendered = render_ai_variants(app, asset, identity_source,
                                      scheme_colors(scheme_path), shape)
        resolution = icon_resolution(app, candidates)
        if not dry_run:
            previous_resolution = record.get("resolution", {}) if isinstance(record, dict) else {}
            previous_method = previous_resolution.get("method") if isinstance(previous_resolution, dict) else ""
            if previous_method == OVERLAY_METHOD and resolution.method != OVERLAY_METHOD:
                # A newly introduced name collision must never be silently
                # recolored through the old overlay.  Fall back to normal
                # upstream lookup until the user deliberately reapplies an
                # audited desktop fallback.
                remove_overlay_entry_assets(app, record, output_root)
                record["resolution"] = resolution.as_manifest()
                summary["skipped"].append({"desktopId": app.desktop_id,
                                           "reason": "icon-name resolution is no longer overlay-safe"})
                continue
            if resolution.method == OVERLAY_METHOD:
                for dark in (False, True):
                    write_rendered_icon(rendered,
                                        overlay_generated_paths(output_root,
                                                                resolution.overlay_icon_name,
                                                                dark))
            else:
                write_rendered_icon(rendered, generated_paths(output_root, app.generated_icon_name))
        summary["rendered"].append({"desktopId": app.desktop_id,
                                    "icon": (resolution.overlay_icon_name
                                             if resolution.method == OVERLAY_METHOD
                                             else app.generated_icon_name),
                                    "style": "ai",
                                    "resolution": resolution.as_manifest()})
    if not dry_run:
        # Persist only the in-memory AI safety updates before deterministic
        # groups invoke apply() and load the same manifest independently.
        save_config(config_root() / "manifest.json", manifest)
    for (style, shape, prompt), grouped_apps in deterministic.items():
        result = apply(grouped_apps, style, shape, prompt, output_root, scheme_path,
                       dry_run, global_default=False, update_global_preferences=False,
                       refresh=False, all_apps=candidates)
        summary["rendered"].extend(result["rendered"])
        summary["skipped"].extend(result["skipped"])
    if not dry_run:
        # Deterministic groups call apply(), which persists their own record
        # changes. Reload so this final safety check cannot overwrite them.
        final_manifest = load_config(config_root() / "manifest.json")
        if not overlay_records(final_manifest):
            deactivate_overlay_theme(final_manifest)
        save_config(config_root() / "manifest.json", final_manifest)
        refresh_kde_caches(output_root)
    return summary


def snapshot_files(paths: Iterable[Path]) -> dict[Path, bytes | None]:
    """Capture small managed files so a multi-app commit can be rolled back."""
    snapshot: dict[Path, bytes | None] = {}
    for path in paths:
        if path in snapshot:
            continue
        snapshot[path] = path.read_bytes() if path.is_file() else None
    return snapshot


def restore_snapshot(snapshot: dict[Path, bytes | None]) -> None:
    for path, content in snapshot.items():
        if content is None:
            if path.exists():
                path.unlink()
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".meo-rollback")
        temporary.write_bytes(content)
        temporary.replace(path)


def load_ai_pack(path: Path) -> dict:
    if not path.is_file() or path.stat().st_size > 2_000_000:
        raise ValueError("The AI icon pack manifest is missing or too large")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError("The AI icon pack manifest is invalid") from error
    if not isinstance(payload, dict):
        raise ValueError("The AI icon pack manifest is invalid")
    pack_schema = payload.get("schema", 1)
    if (isinstance(pack_schema, bool) or not isinstance(pack_schema, int)
            or not 1 <= pack_schema <= AI_PACK_STAGING_SCHEMA):
        raise ValueError("The AI icon pack staging schema is unsupported")
    items = payload.get("items")
    if not isinstance(items, list) or not 1 <= len(items) <= 128:
        raise ValueError("The AI icon pack must contain 1 to 128 applications")
    root = path.parent.resolve()
    normalized = []
    seen: set[str] = set()
    # A Pixel-like style pack commonly references the same generated material
    # for every app. Decode it once during preflight: repeated paths still
    # receive independent per-app source identity checks below.
    validated_images: set[Path] = set()
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("An AI icon pack item is invalid")
        desktop_id = str(item.get("desktopId", "")).strip()
        shape = str(item.get("shape", payload.get("shape", "circle"))).strip().lower()
        prompt = str(item.get("prompt", payload.get("prompt", DEFAULT_PROMPT))).strip()
        relative_image = str(item.get("image", "")).strip()
        source_icon_hash = str(item.get("sourceIconHash", "")).strip().lower()
        image_sha256 = str(item.get("imageSha256", "")).strip().lower()
        if (not desktop_id or desktop_id in seen or shape not in SHAPES
                or not 1 <= len(prompt) <= 4000 or not relative_image):
            raise ValueError("An AI icon pack item is invalid")
        if source_icon_hash and not re.fullmatch(r"[a-f0-9]{64}", source_icon_hash):
            raise ValueError("An AI icon pack source identity hash is invalid")
        if pack_schema >= AI_PACK_STAGING_SCHEMA and not source_icon_hash:
            raise ValueError("An attested AI icon pack requires every source identity hash")
        if image_sha256 and not re.fullmatch(r"[a-f0-9]{64}", image_sha256):
            raise ValueError("An AI icon pack image hash is invalid")
        if pack_schema >= AI_PACK_STAGING_SCHEMA and not image_sha256:
            raise ValueError("An attested AI icon pack requires every staged image hash")
        image_path = (root / relative_image).resolve()
        if image_path != root and root not in image_path.parents:
            raise ValueError("An AI icon pack image escapes its staging directory")
        if not image_path.is_file() or image_path.stat().st_size > 12_000_000:
            raise ValueError("An AI icon pack image is missing or too large")
        if image_sha256 and file_sha256(image_path) != image_sha256:
            raise ValueError("An AI icon pack staged image no longer matches its manifest")
        # Decode every item before an atomic pack snapshot. A malformed,
        # transparent, or decompression-sized provider response must fail the
        # preflight rather than make a later item trigger rollback.
        if image_path not in validated_images:
            load_ai_material(image_path)
            validated_images.add(image_path)
        seen.add(desktop_id)
        normalized.append({"desktopId": desktop_id, "shape": shape,
                           "prompt": prompt, "image": image_path,
                           "sourceIconHash": source_icon_hash,
                           "imageSha256": image_sha256})
    return {**payload, "schema": pack_schema, "items": normalized}


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalized_pack_id(payload: dict) -> str:
    candidate = str(payload.get("packId", "")).strip()
    if candidate and re.fullmatch(r"[A-Za-z0-9._-]{1,128}", candidate):
        return candidate
    # The staging payload cannot choose a filesystem path.  A deterministic
    # fallback is enough to retain provenance and rollback linkage.
    stable = json.dumps(payload.get("items", []), sort_keys=True, default=str).encode("utf-8")
    return f"pack-{hashlib.sha256(stable).hexdigest()[:24]}"


def generation_manifest_path(pack_id: str) -> Path:
    return config_root() / "generation-manifests" / f"{pack_id}.json"


def rendered_paths_for_record(app: DesktopApplication, record: dict,
                              output_root: Path) -> list[Path]:
    resolution = record.get("resolution", {}) if isinstance(record, dict) else {}
    if isinstance(resolution, dict) and resolution.get("method") == OVERLAY_METHOD:
        icon_name = str(resolution.get("overlayIconName", record.get("overlayIconName", app.icon)))
        return [path for dark in (False, True)
                for path in overlay_generated_paths(output_root, icon_name, dark)]
    return generated_paths(output_root, app.generated_icon_name)


def generation_manifest(payload: dict, apps: list[DesktopApplication], manifest: dict,
                        output_root: Path, scheme_path: Path,
                        *, source_hashes_by_app: Mapping[str, str] | None = None) -> dict:
    """Build non-secret provenance for one atomically applied AI style pack."""
    records = manifest.get("applications", {})
    stage_items = {item["desktopId"]: item for item in payload["items"]}
    source_hashes: dict[str, str] = {}
    staged_image_hashes: dict[str, str] = {}
    generated_asset_hashes: dict[str, str] = {}
    source_integrity: dict[str, dict[str, str | bool]] = {}
    output_hashes: dict[str, dict[str, str]] = {}
    for app in apps:
        record = records.get(app.desktop_id, {}) if isinstance(records, dict) else {}
        expected_source_hash = str(stage_items[app.desktop_id].get("sourceIconHash", ""))
        expected_image_hash = str(stage_items[app.desktop_id].get("imageSha256", ""))
        current_source_hash = (source_hashes_by_app.get(app.desktop_id)
                               if source_hashes_by_app is not None
                               else canonical_identity_hash(app))
        if current_source_hash:
            source_hashes[app.desktop_id] = current_source_hash
        if expected_image_hash:
            staged_image_hashes[app.desktop_id] = expected_image_hash
        source_integrity[app.desktop_id] = {
            "expectedHash": expected_source_hash,
            "currentHash": current_source_hash or "",
            "verified": bool(expected_source_hash and current_source_hash == expected_source_hash),
            "status": ("verified" if expected_source_hash and current_source_hash == expected_source_hash
                       else "legacy-unverified" if not expected_source_hash
                       else "unavailable"),
        }
        ai_asset = ai_asset_path(app)
        if ai_asset.is_file():
            generated_asset_hashes[app.desktop_id] = file_sha256(ai_asset)
        hashes = {str(path.relative_to(output_root)): file_sha256(path)
                  for path in rendered_paths_for_record(app, record, output_root)
                  if path.is_file()}
        output_hashes[app.desktop_id] = hashes
    return {
        "schema": 1,
        "stagingSchema": payload["schema"],
        "packId": normalized_pack_id(payload),
        "contractVersion": ICON_CONTRACT_VERSION,
        "styleId": str(payload.get("styleId", payload.get("stylePack", "easel-monet")))[:128],
        "provider": str(payload.get("provider", "account-managed"))[:128],
        "model": str(payload.get("model", "unspecified"))[:256],
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sourceAppIds": [app.desktop_id for app in apps],
        "sourceIconHashes": source_hashes,
        "stagedImageHashes": staged_image_hashes,
        "generatedAssetHashes": generated_asset_hashes,
        "sourceIntegrity": source_integrity,
        "outputHashes": output_hashes,
        "shape": str(payload.get("shape", "mixed"))[:32],
        "palette": scheme_path.name[:256],
        "promptRecipeVersion": str(payload.get("promptRecipeVersion", "v1"))[:128],
    }


def ai_pack_identity_sources(all_apps: list[DesktopApplication],
                             payload: dict) -> tuple[list[DesktopApplication],
                                                     dict[str, Image.Image],
                                                     dict[str, str]]:
    """Resolve and attest every current local identity before preview/commit.

    The Account service only controls a consented material field.  It cannot
    select an application's logo, so both preview and commit calculate these
    hashes from the exact same current local identity source.
    """
    app_map = {app.desktop_id: app for app in all_apps}
    missing = [item["desktopId"] for item in payload["items"]
               if item["desktopId"] not in app_map]
    if missing:
        raise ValueError("Unknown application id: " + ", ".join(missing))
    apps = [app_map[item["desktopId"]] for item in payload["items"]]
    identity_sources: dict[str, Image.Image] = {}
    identity_hashes: dict[str, str] = {}
    for app, item in zip(apps, payload["items"]):
        identity_source = canonical_identity_source(app)
        if identity_source is None:
            raise ValueError("The current application identity could not be resolved: "
                             + app.desktop_id)
        identity_sources[app.desktop_id] = identity_source
        current_source_hash = source_icon_hash(identity_source)
        identity_hashes[app.desktop_id] = current_source_hash
        expected_source_hash = item["sourceIconHash"]
        if expected_source_hash and current_source_hash != expected_source_hash:
            raise ValueError("The AI icon pack no longer matches the current application identity: "
                             + app.desktop_id)
    return apps, identity_sources, identity_hashes


def preview_ai_pack(all_apps: list[DesktopApplication], pack_path: Path,
                    preview_root: Path, scheme_path: Path) -> dict:
    """Render a staged, attested pack without changing icon-theme state.

    Preview is deliberately a renderer-only operation.  It makes no config,
    overlay, desktop-entry, Dock, cache, or provenance write, so Settings can
    present the exact canonical-identity result before asking Studio to commit
    the whole pack atomically.
    """
    payload = load_ai_pack(pack_path)
    apps, identity_sources, identity_hashes = ai_pack_identity_sources(all_apps, payload)
    preview_root = preview_root.resolve()
    if preview_root.exists() and not preview_root.is_dir():
        raise ValueError("The AI icon preview directory is invalid")
    preview_root.mkdir(parents=True, exist_ok=True)
    material_assets: dict[Path, Image.Image] = {}
    colors = scheme_colors(scheme_path)
    previews = []
    for index, (app, item) in enumerate(zip(apps, payload["items"])):
        image_path = item["image"]
        asset = material_assets.get(image_path)
        if asset is None:
            asset = normalized_easel_asset(load_ai_material(image_path))
            material_assets[image_path] = asset
        rendered = render_ai_variants(app, asset, identity_sources[app.desktop_id],
                                      colors, item["shape"])
        preview_path = preview_root / f"{index:03d}.png"
        # render_ai_variants intentionally retains a high-resolution canonical
        # master for regular delivery sizes. Preview is an actual 128px UI
        # asset, so apply the same final downsample as write_rendered_icon
        # rather than handing QML a 1024px image.
        rendered[128].resize((128, 128), Image.Resampling.LANCZOS).save(
            preview_path, format="PNG", optimize=True)
        previews.append({
            "desktopId": app.desktop_id,
            "name": app.name,
            "preview": str(preview_path),
            "sourceIconHash": identity_hashes[app.desktop_id],
            "shape": item["shape"],
        })
    return {
        "schema": 1,
        "packId": normalized_pack_id(payload),
        "styleId": str(payload.get("styleId", payload.get("stylePack", "easel-monet")))[:128],
        "applicationCount": len(previews),
        "previews": previews,
    }


def apply_ai_pack(all_apps: list[DesktopApplication], pack_path: Path,
                  output_root: Path, scheme_path: Path, dry_run: bool) -> dict:
    """Commit a staged AI pack as one recoverable user-visible operation."""
    payload = load_ai_pack(pack_path)
    # Account's production staging contract binds every generated material to
    # the exact original icon pixels it saw. Check this before any snapshot or
    # write so an application update cannot receive stale AI artwork.
    apps, identity_sources, identity_hashes = ai_pack_identity_sources(all_apps, payload)
    if dry_run:
        return {"rendered": [item["desktopId"] for item in payload["items"]],
                "style": "ai", "atomic": True, "dryRun": True}
    pack_id = normalized_pack_id(payload)
    managed_paths: list[Path] = [config_root() / "manifest.json", dock_config_path(),
                                 kdeglobals_path(), generation_manifest_path(pack_id),
                                 output_root / "icons" / "hicolor" / "index.theme"]
    for dark in (False, True):
        managed_paths.append(overlay_theme_root(output_root, dark) / "index.theme")
    for app in apps:
        # Always snapshot legacy paths as an overlay migration may restore a
        # previously managed desktop entry before committing its new asset.
        managed_paths.append(app.local_path)
        managed_paths.extend(generated_paths(output_root, app.generated_icon_name))
        resolution = icon_resolution(app, all_apps)
        if resolution.method == OVERLAY_METHOD:
            for dark in (False, True):
                managed_paths.extend(overlay_generated_paths(output_root,
                                                            resolution.overlay_icon_name,
                                                            dark))
        else:
            managed_paths.append(app.local_path)
            managed_paths.extend(generated_paths(output_root, app.generated_icon_name))
        managed_paths.append(ai_asset_path(app))
    snapshot = snapshot_files(managed_paths)
    rendered = []
    material_assets: dict[Path, Image.Image] = {}
    try:
        for app, item in zip(apps, payload["items"]):
            image_path = item["image"]
            asset = material_assets.get(image_path)
            if asset is None:
                asset = normalized_easel_asset(load_ai_material(image_path))
                material_assets[image_path] = asset
            result = apply_ai(app, item["image"], item["shape"], item["prompt"],
                              output_root, scheme_path, False, refresh=False,
                              all_apps=all_apps,
                              identity_source=identity_sources[app.desktop_id],
                              material_asset=asset)
            rendered.extend(result["rendered"])
        manifest_path = config_root() / "manifest.json"
        config = load_config(manifest_path)
        provenance = generation_manifest(payload, apps, config, output_root, scheme_path,
                                         source_hashes_by_app=identity_hashes)
        write_atomic(generation_manifest_path(pack_id),
                     json.dumps(provenance, indent=2, sort_keys=True) + "\n")
        config["lastAiPack"] = {
            "schema": 1,
            "packId": pack_id,
            "generationManifest": str(generation_manifest_path(pack_id)),
            "generationManifestHash": file_sha256(generation_manifest_path(pack_id)),
            "contractVersion": ICON_CONTRACT_VERSION,
            "styleId": provenance["styleId"],
            "applicationCount": len(apps),
        }
        save_config(manifest_path, config)
        refresh_kde_caches(output_root)
    except Exception:
        restore_snapshot(snapshot)
        refresh_kde_caches(output_root)
        raise
    return {"rendered": rendered, "style": "ai", "atomic": True,
            "packId": pack_id,
            "generationManifest": str(generation_manifest_path(pack_id)),
            "applicationCount": len(apps)}


def reset(apps: list[DesktopApplication], output_root: Path, dry_run: bool) -> dict:
    manifest_path = config_root() / "manifest.json"
    manifest = load_config(manifest_path)
    records = manifest.setdefault("applications", {})
    reset_ids: list[str] = []
    legacy_apps: list[DesktopApplication] = []
    for app in apps:
        record = records.get(app.desktop_id)
        if not record:
            continue
        if not dry_run:
            resolution = record.get("resolution", {}) if isinstance(record, dict) else {}
            method = resolution.get("method") if isinstance(resolution, dict) else ""
            if method == OVERLAY_METHOD:
                remove_overlay_entry_assets(app, record, output_root)
            else:
                restore_desktop_entry(app, record)
                remove_files(generated_paths(output_root, app.generated_icon_name))
                legacy_apps.append(app)
            asset = ai_asset_path(app)
            remove_files([asset])
        records.pop(app.desktop_id, None)
        reset_ids.append(app.desktop_id)
    if not dry_run:
        if not overlay_records(manifest):
            deactivate_overlay_theme(manifest)
        save_config(manifest_path, manifest)
        if legacy_apps:
            remove_dock_icon_modes(legacy_apps)
        refresh_kde_caches(output_root)
    return {"reset": reset_ids}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="emit visible applications as JSON")
    parser.add_argument("--describe", action="store_true",
                        help="emit canonical identity hashes for explicit --app IDs")
    parser.add_argument("--preview-ai-pack", type=Path,
                        help="render an attested staged AI pack without changing icon state")
    parser.add_argument("--preview-output", type=Path,
                        help="private directory for --preview-ai-pack PNG previews")
    parser.add_argument("--apply", action="store_true", help="render and activate selected applications")
    parser.add_argument("--reset", action="store_true", help="restore selected applications")
    parser.add_argument("--app", action="append", default=[], metavar="DESKTOP_ID", help="limit an action to a desktop-entry ID")
    parser.add_argument("--style", choices=STYLES, help="monet, original, or mono (pure is a legacy alias)")
    parser.add_argument("--shape", choices=SHAPES, help="circle, pixel, squircle, or rounded")
    parser.add_argument("--prompt", help="store an editable AI icon prompt; never transmitted by this tool")
    parser.add_argument("--ai-image", type=Path,
                        help="apply one consent-produced image to exactly one --app")
    parser.add_argument("--ai-pack", type=Path,
                        help="atomically apply a staged multi-application AI icon pack")
    parser.add_argument("--scheme", type=Path, help="path to a generated Meo .colors file")
    parser.add_argument("--dark", dest="dark", action="store_const", const=True, default=None,
                        help="force the dark Meo dynamic scheme")
    parser.add_argument("--light", dest="dark", action="store_const", const=False,
                        help="force the light Meo dynamic scheme")
    parser.add_argument("--managed-only", action="store_true",
                        help="apply only to applications already managed by Meo Icon Studio")
    parser.add_argument("--output-root", type=Path, default=default_output_root(), help="XDG data root for generated hicolor assets and desktop overrides")
    parser.add_argument("--dry-run", action="store_true", help="resolve and render without writing assets or desktop entries")
    arguments = parser.parse_args()
    if sum(bool(value) for value in (arguments.list, arguments.describe,
                                     arguments.preview_ai_pack, arguments.apply,
                                     arguments.reset)) != 1:
        parser.error("choose exactly one of --list, --describe, --preview-ai-pack, --apply, or --reset")
    if arguments.describe and not arguments.app:
        parser.error("--describe requires at least one --app")
    if bool(arguments.preview_ai_pack) != bool(arguments.preview_output):
        parser.error("--preview-ai-pack requires --preview-output")
    if arguments.preview_ai_pack and (arguments.app or arguments.managed_only
                                      or arguments.ai_image or arguments.ai_pack):
        parser.error("--preview-ai-pack cannot be combined with application mutation options")
    if arguments.preview_output and not arguments.preview_ai_pack:
        parser.error("--preview-output is valid only with --preview-ai-pack")
    if arguments.managed_only and (arguments.list or arguments.describe
                                  or arguments.reset or arguments.app):
        parser.error("--managed-only is valid only with --apply and without --app")
    if arguments.ai_image and (not arguments.apply or len(arguments.app) != 1
                               or arguments.managed_only or arguments.ai_pack):
        parser.error("--ai-image requires --apply and exactly one --app")
    if arguments.ai_pack and (not arguments.apply or arguments.app or arguments.managed_only):
        parser.error("--ai-pack requires --apply without --app or --managed-only")
    all_apps = applications(arguments.output_root)
    if arguments.list:
        print(json.dumps([{
            **asdict(app), "source_path": str(app.source_path), "local_path": str(app.local_path),
            "generated_icon_name": app.generated_icon_name,
            "resolution": icon_resolution(app, all_apps).as_manifest(),
        } for app in all_apps], indent=2))
        return 0
    if arguments.describe:
        try:
            selected = select_apps(all_apps, arguments.app)
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
        print(json.dumps([describe_application(app, all_apps) for app in selected], indent=2))
        return 0
    if arguments.preview_ai_pack:
        scheme = arguments.scheme or default_scheme_path(arguments.dark)
        try:
            print(json.dumps(preview_ai_pack(all_apps, arguments.preview_ai_pack,
                                             arguments.preview_output, scheme),
                             indent=2))
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
        return 0
    try:
        if arguments.managed_only:
            manifest = load_config(config_root() / "manifest.json")
            managed_ids = set(manifest.get("applications", {}))
            selected = [app for app in all_apps if app.desktop_id in managed_ids]
        else:
            selected = select_apps(all_apps, arguments.app)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2
    if arguments.reset:
        print(json.dumps(reset(selected, arguments.output_root, arguments.dry_run), indent=2))
        return 0
    config = load_config(config_root() / "manifest.json")
    style = arguments.style or str(config.get("style", "monet"))
    shape = arguments.shape or str(config.get("shape", "circle"))
    prompt = arguments.prompt if arguments.prompt is not None else str(config.get("prompt", DEFAULT_PROMPT))
    scheme = arguments.scheme or default_scheme_path(arguments.dark)
    if arguments.managed_only:
        print(json.dumps(refresh_managed(selected, arguments.output_root, scheme,
                                         arguments.dry_run, all_apps=all_apps), indent=2))
        return 0
    if arguments.ai_pack:
        try:
            result = apply_ai_pack(all_apps, arguments.ai_pack, arguments.output_root,
                                   scheme, arguments.dry_run)
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
        print(json.dumps(result, indent=2))
        return 0
    if arguments.ai_image:
        try:
            result = apply_ai(selected[0], arguments.ai_image, shape, prompt,
                              arguments.output_root, scheme, arguments.dry_run,
                              all_apps=all_apps)
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
        print(json.dumps(result, indent=2))
        return 0
    print(json.dumps(apply(selected, style, shape, prompt, arguments.output_root, scheme,
                           arguments.dry_run, global_default=not bool(arguments.app),
                           all_apps=all_apps), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
