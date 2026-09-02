#!/usr/bin/env python3
"""Build and apply Meo's per-application Material icon treatment.

This is deliberately *not* an icon theme replacement.  It resolves an
installed application's original icon, renders a private hicolor asset with a
unique name, then changes only that application's user-local desktop entry.
Status, device, action, and other KDE icons keep their existing names and
therefore continue through the unchanged global icon theme.

The renderer is deterministic and offline.  The optional AI prompt is stored
as user preference; Meo Settings may send it through its separately consented
Account flow, but this tool itself never transmits it.
"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import quote

from PIL import Image, ImageDraw, ImageFilter


APP_GROUP = "Desktop Entry"
MANAGED_KEY = "X-Meo-IconStudio-Managed"
SOURCE_HASH_KEY = "X-Meo-IconStudio-SourceHash"
SOURCE_ICON_KEY = "X-Meo-IconStudio-SourceIcon"
ICON_PREFIX = "org.meo.iconstudio.app"
RENDER_SIZES = (128, 256, 512)
MASTER_SIZE = 1024
SYMBOL_SCHEMA = 2
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
ICON_FALLBACK_ALIASES = {
    # Unity Hub creates editor launchers with this historical icon name even
    # when the installed theme ships only the normal Unity Editor artwork.
    "unityhub-unity-editor": ("unity-editor-icon", "unityhub", "com.unity.UnityHub"),
}


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
    if not path.exists():
        return {"schema": 3, "style": "monet", "shape": "circle", "prompt": DEFAULT_PROMPT, "applications": {}}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"schema": 3, "style": "monet", "shape": "circle", "prompt": DEFAULT_PROMPT, "applications": {}}
    if not isinstance(payload, dict):
        return {"schema": 3, "style": "monet", "shape": "circle", "prompt": DEFAULT_PROMPT, "applications": {}}
    # Schema 3 makes Monet/Circle the new-install default and records the
    # palette-independent symbol layer. Preserve explicit older preferences;
    # the retired ``pure`` spelling is the same renderer as ``monet``.
    payload["schema"] = 3
    payload.setdefault("style", "monet")
    payload.setdefault("shape", "circle")
    if payload["style"] == "pure":
        payload["style"] = "monet"
    payload.setdefault("prompt", DEFAULT_PROMPT)
    payload.setdefault("applications", {})
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
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    kdeglobals = xdg_path("XDG_CONFIG_HOME", Path.home() / ".config") / "kdeglobals"
    parser.read(kdeglobals, encoding="utf-8")
    scheme = parser.get("General", "ColorScheme", fallback="")
    return "dark" in scheme.casefold()


def default_scheme_path(dark: bool | None = None) -> Path:
    if dark is None:
        dark = active_kde_is_dark()
    name = "MeoDynamicDark.colors" if dark else "MeoDynamicLight.colors"
    return default_output_root() / "color-schemes" / name


def blend(left: tuple[int, int, int], right: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(round(a * (1.0 - amount) + b * amount) for a, b in zip(left, right))


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


def qicon_file_image(path: Path) -> Image.Image | None:
    try:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        from PySide6.QtGui import QGuiApplication, QIcon
    except ImportError:
        return None
    app = QGuiApplication.instance() or QGuiApplication(["meo-app-icon-studio"])
    _ = app
    return qimage_to_pillow(QIcon(str(path)).pixmap(MASTER_SIZE, MASTER_SIZE).toImage())


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
    suffixes = {".png", ".svg", ".xpm", ".webp", ".jpg", ".jpeg"}
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
                if path.suffix.lower() not in suffixes or path.stem.startswith(ICON_PREFIX):
                    continue
                relative_parts = path.relative_to(directory).parts
                if ("apps" in relative_parts
                        and any(part in {"MeoSymbols", "MeoSymbolsDark"} for part in relative_parts)):
                    # These are the retired generic glyphs.  They are never a
                    # valid source for a brand-preserving application icon.
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
    icon_name = icon_path.stem if icon_path.suffix.lower() in {
        ".png", ".svg", ".xpm", ".webp", ".jpg", ".jpeg"
    } else icon
    candidates = [icon_name]
    if icon_name.endswith(".desktop"):
        candidates.append(icon_name.removesuffix(".desktop"))
    else:
        candidates.append(icon_name + ".desktop")
    if "." in icon_name:
        candidates.append(icon_name.rsplit(".", 1)[-1])
    candidates.extend(ICON_FALLBACK_ALIASES.get(icon_name, ()))
    return list(dict.fromkeys(candidates))


def source_image(icon: str) -> Image.Image | None:
    raw_path = Path(icon).expanduser()
    if raw_path.is_file():
        try:
            return Image.open(raw_path).convert("RGBA")
        except OSError:
            return qicon_file_image(raw_path)
    candidates = icon_name_candidates(icon)
    icon_name = candidates[0]
    paths = icon_path_index()
    path = next((paths.get(candidate) for candidate in candidates if paths.get(candidate) is not None), None)
    if path is not None:
        try:
            return Image.open(path).convert("RGBA")
        except OSError:
            rendered = qicon_file_image(path)
            if rendered is not None:
                return rendered
    # Some icon themes synthesize inherited/scale variants that have no
    # concrete file in the local index, so use Qt only as a final fallback.
    return qicon_image(icon_name)


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
                    *, monochrome: bool = False) -> Image.Image:
    surface_dark = foreground_luminance(Image.new("RGBA", (1, 1), rgba(colors["surface"]))) < 0.5
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
    output = []
    for level, _green, _blue, alpha in pixel_values(asset):
        amount = level / 255.0
        color = (blend(deep, middle, amount * 2.0) if amount < 0.5
                 else blend(middle, light, (amount - 0.5) * 2.0))
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


def container_mask(box: tuple[int, int, int, int], shape: str) -> Image.Image:
    """Return a shared themed-icon mask with clean, non-overlapping outlines."""
    mask = Image.new("L", (MASTER_SIZE, MASTER_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    left, top, right, bottom = box
    size = right - left
    if shape == "circle":
        draw.ellipse(box, fill=255)
    elif shape == "squircle":
        draw.rounded_rectangle(box, radius=int(size * 0.31), fill=255)
    elif shape == "rounded":
        draw.rounded_rectangle(box, radius=int(size * 0.19), fill=255)
    else:
        # An eight-petal Material/Pixel flower: a central disk joined to
        # cardinal and diagonal lobes. Rendering it as one alpha mask avoids
        # the internal ring seams that separate drawn circles would create.
        center_x = (left + right) / 2
        center_y = (top + bottom) / 2
        lobe_radius = size * 0.19
        offset = size * 0.31
        draw.ellipse((center_x - size * 0.31, center_y - size * 0.31,
                      center_x + size * 0.31, center_y + size * 0.31), fill=255)
        for direction_x, direction_y in ((1, 0), (1, 1), (0, 1), (-1, 1),
                                          (-1, 0), (-1, -1), (0, -1), (1, -1)):
            diagonal = 0.70710678 if direction_x and direction_y else 1.0
            x = center_x + direction_x * offset * diagonal
            y = center_y + direction_y * offset * diagonal
            draw.ellipse((x - lobe_radius, y - lobe_radius,
                          x + lobe_radius, y + lobe_radius), fill=255)
    return mask


def draw_themed_container(canvas: Image.Image, box: tuple[int, int, int, int], shape: str,
                          fill: tuple[int, int, int], outline: tuple[int, int, int] | None) -> None:
    mask = container_mask(box, shape)
    if outline is not None:
        # Expand only the silhouette; the filled mask below covers the inner
        # edge, yielding one calm MD outline rather than a line around petals.
        outline_mask = mask.filter(ImageFilter.MaxFilter(9))
        canvas.paste(rgba(outline, 112), mask=outline_mask)
    canvas.paste(rgba(fill), mask=mask)


def render_icon(source: Image.Image, style: str, colors: dict[str, tuple[int, int, int]], seed: str,
                shape: str = "circle", symbol: Image.Image | None = None) -> Image.Image:
    if shape not in SHAPES:
        raise ValueError(f"Unsupported icon shape: {shape}")
    source = source.copy().convert("RGBA")
    source_bounds = alpha_bounds(source)
    if source_bounds:
        source = source.crop(source_bounds)
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    container_size = int(MASTER_SIZE * 0.84)
    inset = (MASTER_SIZE - container_size) // 2
    box = (inset, inset, inset + container_size, inset + container_size)
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
        fill = (24, 24, 24) if surface_dark else (250, 250, 250)
        foreground = colorize_symbol(symbol, colors, monochrome=True)
    draw_themed_container(canvas, box, shape, fill,
                          colors["outline"] if normalized_style == "original" else None)
    bounds = alpha_bounds(foreground)
    if bounds:
        foreground = foreground.crop(bounds)
    max_side = int(container_size * (0.58 if shape == "pixel" else 0.64))
    foreground = fit_square(foreground, max_side)
    position = ((MASTER_SIZE - foreground.width) // 2, (MASTER_SIZE - foreground.height) // 2)
    canvas.alpha_composite(foreground, dest=position)
    return canvas


def render_ai_icon(source: Image.Image, shape: str = "circle") -> Image.Image:
    """Normalize one generated image without adding a second themed plate.

    Image providers frequently return complete app artwork, not a transparent
    foreground mark.  Applying ``render_icon(..., original)`` to that artwork
    would shrink it onto another opaque Material container.  Instead, fit the
    generated artwork directly to the selected silhouette and intersect its
    alpha with that mask.  Opaque square provider output therefore becomes a
    clean circle/squircle/etc., while already-transparent artwork is preserved.
    """
    if shape not in SHAPES:
        raise ValueError(f"Unsupported icon shape: {shape}")
    source = source.copy().convert("RGBA")
    bounds = alpha_bounds(source)
    if bounds:
        source = source.crop(bounds)
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    container_size = int(MASTER_SIZE * 0.84)
    inset = (MASTER_SIZE - container_size) // 2
    box = (inset, inset, inset + container_size, inset + container_size)
    foreground = fit_square(source, container_size)
    position = ((MASTER_SIZE - foreground.width) // 2,
                (MASTER_SIZE - foreground.height) // 2)
    canvas.alpha_composite(foreground, dest=position)
    clipped_alpha = Image.new("L", canvas.size, 0)
    clipped_alpha.paste(canvas.getchannel("A"), mask=container_mask(box, shape))
    canvas.putalpha(clipped_alpha)
    return canvas


def generated_paths(output_root: Path, generated_name: str) -> list[Path]:
    return [output_root / "icons" / "hicolor" / f"{size}x{size}" / "apps" / f"{generated_name}.png"
            for size in RENDER_SIZES]


def ensure_hicolor_index(output_root: Path) -> None:
    # hicolor may already be supplied by /usr.  A user-local index is only
    # needed when a test/staging root has no inherited one.
    index = output_root / "icons" / "hicolor" / "index.theme"
    if index.exists():
        return
    index.parent.mkdir(parents=True, exist_ok=True)
    index.write_text(
        "[Icon Theme]\nName=hicolor\nComment=Fallback icon theme\n"
        "Directories=128x128/apps,256x256/apps,512x512/apps\n\n"
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
        "prompt": prompt,
    }
    original_icon = str(records[app.desktop_id]["originalIcon"])
    write_atomic(app.local_path, patch_desktop_icon(source_text, app.generated_icon_name,
                                                     app.source_hash, original_icon))


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
    commands = [("gtk-update-icon-cache", ["-f", str(output_root / "icons" / "hicolor")])]
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
          update_global_preferences: bool = True, refresh: bool = True) -> dict:
    colors = scheme_colors(scheme_path)
    manifest_path = config_root() / "manifest.json"
    manifest = load_config(manifest_path)
    style = "monet" if style == "pure" else style
    if update_global_preferences:
        manifest["style"] = style
        manifest["shape"] = shape
        manifest["prompt"] = prompt
    summary = {"rendered": [], "skipped": [], "style": style, "shape": shape, "scheme": str(scheme_path)}
    if not dry_run:
        ensure_hicolor_index(output_root)
    for app in apps:
        source = source_image(app.icon)
        if source is None:
            summary["skipped"].append({"desktopId": app.desktop_id, "reason": "original icon could not be resolved"})
            continue
        icon_hash = source_icon_hash(source)
        symbol = symbol_for(source, icon_hash, persist=not dry_run)
        rendered = render_icon(source, style, colors, app.desktop_id, shape, symbol)
        if not dry_run:
            for destination in generated_paths(output_root, app.generated_icon_name):
                destination.parent.mkdir(parents=True, exist_ok=True)
                rendered.resize((int(destination.parent.parent.name.split("x")[0]),) * 2,
                                Image.Resampling.LANCZOS).save(destination, "PNG", optimize=True)
            activate_desktop_entry(app, manifest, style, shape, prompt)
            manifest["applications"][app.desktop_id]["symbolHash"] = icon_hash
            manifest["applications"][app.desktop_id]["symbolSchema"] = SYMBOL_SCHEMA
        summary["rendered"].append({"desktopId": app.desktop_id,
                                    "icon": app.generated_icon_name,
                                    "symbolHash": icon_hash,
                                    "symbolSchema": SYMBOL_SCHEMA})
    if not dry_run:
        save_config(manifest_path, manifest)
        write_dock_icon_modes(apps, style, global_default)
        if refresh:
            refresh_kde_caches(output_root)
    return summary


def apply_ai(app: DesktopApplication, image_path: Path, shape: str, prompt: str,
             output_root: Path, scheme_path: Path, dry_run: bool,
             *, refresh: bool = True) -> dict:
    """Activate one consent-produced image without changing other apps."""
    if not image_path.is_file() or image_path.stat().st_size > 12_000_000:
        raise ValueError("The generated image is missing or too large")
    try:
        with Image.open(image_path) as opened:
            source = opened.convert("RGBA")
            source.load()
    except Exception as error:
        raise ValueError("The generated image is not a supported image") from error
    colors = scheme_colors(scheme_path)
    asset = normalized_easel_asset(source)
    rendered = render_ai_icon(colorize_easel_asset(asset, colors), shape)
    summary = {"rendered": [], "skipped": [], "style": "ai", "shape": shape,
               "scheme": str(scheme_path)}
    if not dry_run:
        ensure_hicolor_index(output_root)
        save_ai_asset(app, asset)
        for destination in generated_paths(output_root, app.generated_icon_name):
            destination.parent.mkdir(parents=True, exist_ok=True)
            size = int(destination.parent.parent.name.split("x")[0])
            rendered.resize((size, size), Image.Resampling.LANCZOS).save(
                destination, "PNG", optimize=True)
        manifest_path = config_root() / "manifest.json"
        manifest = load_config(manifest_path)
        activate_desktop_entry(app, manifest, "ai", shape, prompt)
        save_config(manifest_path, manifest)
        write_dock_icon_modes([app], "ai", global_default=False)
        if refresh:
            refresh_kde_caches(output_root)
    summary["rendered"].append({"desktopId": app.desktop_id,
                                "icon": app.generated_icon_name})
    return summary


def refresh_managed(apps: list[DesktopApplication], output_root: Path,
                    scheme_path: Path, dry_run: bool) -> dict:
    """Recolor each managed app from its own deterministic or AI source."""
    manifest = load_config(config_root() / "manifest.json")
    records = manifest.get("applications", {})
    summary = {"rendered": [], "skipped": [], "managedOnly": True,
               "scheme": str(scheme_path)}
    deterministic: dict[tuple[str, str, str], list[DesktopApplication]] = {}
    for app in apps:
        record = records.get(app.desktop_id, {})
        style = str(record.get("style", "monet"))
        shape = str(record.get("shape", "circle"))
        prompt = str(record.get("prompt", DEFAULT_PROMPT))
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
        rendered = render_ai_icon(colorize_easel_asset(asset, scheme_colors(scheme_path)), shape)
        if not dry_run:
            for destination in generated_paths(output_root, app.generated_icon_name):
                destination.parent.mkdir(parents=True, exist_ok=True)
                size = int(destination.parent.parent.name.split("x")[0])
                rendered.resize((size, size), Image.Resampling.LANCZOS).save(
                    destination, "PNG", optimize=True)
        summary["rendered"].append({"desktopId": app.desktop_id,
                                    "icon": app.generated_icon_name, "style": "ai"})
    for (style, shape, prompt), grouped_apps in deterministic.items():
        result = apply(grouped_apps, style, shape, prompt, output_root, scheme_path,
                       dry_run, global_default=False, update_global_preferences=False,
                       refresh=False)
        summary["rendered"].extend(result["rendered"])
        summary["skipped"].extend(result["skipped"])
    if not dry_run:
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
    items = payload.get("items") if isinstance(payload, dict) else None
    if not isinstance(items, list) or not 1 <= len(items) <= 128:
        raise ValueError("The AI icon pack must contain 1 to 128 applications")
    root = path.parent.resolve()
    normalized = []
    seen: set[str] = set()
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("An AI icon pack item is invalid")
        desktop_id = str(item.get("desktopId", "")).strip()
        shape = str(item.get("shape", payload.get("shape", "circle"))).strip().lower()
        prompt = str(item.get("prompt", payload.get("prompt", DEFAULT_PROMPT))).strip()
        relative_image = str(item.get("image", "")).strip()
        if (not desktop_id or desktop_id in seen or shape not in SHAPES
                or not 1 <= len(prompt) <= 4000 or not relative_image):
            raise ValueError("An AI icon pack item is invalid")
        image_path = (root / relative_image).resolve()
        if image_path != root and root not in image_path.parents:
            raise ValueError("An AI icon pack image escapes its staging directory")
        if not image_path.is_file() or image_path.stat().st_size > 12_000_000:
            raise ValueError("An AI icon pack image is missing or too large")
        seen.add(desktop_id)
        normalized.append({"desktopId": desktop_id, "shape": shape,
                           "prompt": prompt, "image": image_path})
    return {**payload, "items": normalized}


def apply_ai_pack(all_apps: list[DesktopApplication], pack_path: Path,
                  output_root: Path, scheme_path: Path, dry_run: bool) -> dict:
    """Commit a staged AI pack as one recoverable user-visible operation."""
    payload = load_ai_pack(pack_path)
    app_map = {app.desktop_id: app for app in all_apps}
    missing = [item["desktopId"] for item in payload["items"]
               if item["desktopId"] not in app_map]
    if missing:
        raise ValueError("Unknown application id: " + ", ".join(missing))
    if dry_run:
        return {"rendered": [item["desktopId"] for item in payload["items"]],
                "style": "ai", "atomic": True, "dryRun": True}

    apps = [app_map[item["desktopId"]] for item in payload["items"]]
    managed_paths: list[Path] = [config_root() / "manifest.json", dock_config_path(),
                                 output_root / "icons" / "hicolor" / "index.theme"]
    for app in apps:
        managed_paths.append(app.local_path)
        managed_paths.extend(generated_paths(output_root, app.generated_icon_name))
        managed_paths.append(ai_asset_path(app))
    snapshot = snapshot_files(managed_paths)
    rendered = []
    try:
        for app, item in zip(apps, payload["items"]):
            result = apply_ai(app, item["image"], item["shape"], item["prompt"],
                              output_root, scheme_path, False, refresh=False)
            rendered.extend(result["rendered"])
        manifest_path = config_root() / "manifest.json"
        config = load_config(manifest_path)
        config["lastAiPack"] = {
            "schema": 1,
            "packId": str(payload.get("packId", ""))[:128],
            "stylePack": str(payload.get("stylePack", "easel-monet"))[:128],
            "applicationCount": len(apps),
            "promptHash": str(payload.get("promptHash", ""))[:128],
        }
        save_config(manifest_path, config)
        refresh_kde_caches(output_root)
    except Exception:
        restore_snapshot(snapshot)
        refresh_kde_caches(output_root)
        raise
    return {"rendered": rendered, "style": "ai", "atomic": True,
            "packId": str(payload.get("packId", "")),
            "applicationCount": len(apps)}


def reset(apps: list[DesktopApplication], output_root: Path, dry_run: bool) -> dict:
    manifest_path = config_root() / "manifest.json"
    manifest = load_config(manifest_path)
    records = manifest.setdefault("applications", {})
    reset_ids: list[str] = []
    for app in apps:
        record = records.get(app.desktop_id)
        if not record:
            continue
        if not dry_run:
            restore_desktop_entry(app, record)
            for path in generated_paths(output_root, app.generated_icon_name):
                if path.exists():
                    path.unlink()
            asset = ai_asset_path(app)
            if asset.exists():
                asset.unlink()
        records.pop(app.desktop_id, None)
        reset_ids.append(app.desktop_id)
    if not dry_run:
        save_config(manifest_path, manifest)
        remove_dock_icon_modes(apps)
        refresh_kde_caches(output_root)
    return {"reset": reset_ids}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="emit visible applications as JSON")
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
    if sum(bool(value) for value in (arguments.list, arguments.apply, arguments.reset)) != 1:
        parser.error("choose exactly one of --list, --apply, or --reset")
    if arguments.managed_only and (arguments.list or arguments.reset or arguments.app):
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
        } for app in all_apps], indent=2))
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
                                         arguments.dry_run), indent=2))
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
                              arguments.output_root, scheme, arguments.dry_run)
        except ValueError as error:
            print(str(error), file=sys.stderr)
            return 2
        print(json.dumps(result, indent=2))
        return 0
    print(json.dumps(apply(selected, style, shape, prompt, arguments.output_root, scheme,
                           arguments.dry_run, global_default=not bool(arguments.app)), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
