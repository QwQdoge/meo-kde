#!/usr/bin/env python3
"""Generate Meo shell FrameSvg assets for the Plasma desktop themes."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class ThemeTarget:
    path: Path
    background: str
    surface_opacity: str


PANEL_TARGETS = (
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/widgets/panel-background.svg",
        background="#fffbfe",
        # The normal frame is also used by a top panel. Keep it visibly
        # translucent instead of turning the floating Dock opaque.
        surface_opacity="0.68",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/widgets/panel-background.svg",
        background="#141218",
        surface_opacity="0.68",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/translucent/widgets/panel-background.svg",
        background="#fffbfe",
        surface_opacity="0.58",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/translucent/widgets/panel-background.svg",
        background="#141218",
        surface_opacity="0.58",
    ),
)

MENUBAR_TARGETS = (
    ROOT / "themes/desktoptheme/MeoLight/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoDark/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoLight/translucent/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoDark/translucent/widgets/menubaritem.svg",
)


def frame_paths(prefix: str, radius: int) -> tuple[str, ...]:
    """Return one nine-slice FrameSvg variant centered on the shared seam."""

    name = f"{prefix}-" if prefix else ""
    start = 32 - radius
    end = 34 + radius
    return (
        f'    <path id="{name}center" d="M32 32h2v2h-2z"/>',
        f'    <path id="{name}top" d="M32 {start}h2v{radius}h-2z"/>',
        f'    <path id="{name}bottom" d="M32 34h2v{radius}h-2z"/>',
        f'    <path id="{name}left" d="M{start} 32h{radius}v2H{start}z"/>',
        f'    <path id="{name}right" d="M34 32h{radius}v2h-{radius}z"/>',
        f'    <path id="{name}topleft" d="M32 {start}A{radius} {radius} 0 0 0 {start} 32h{radius}z"/>',
        f'    <path id="{name}topright" d="M34 {start}a{radius} {radius} 0 0 1 {radius} {radius}H34z"/>',
        f'    <path id="{name}bottomleft" d="M{start} 34a{radius} {radius} 0 0 0 {radius} {radius}V34z"/>',
        f'    <path id="{name}bottomright" d="M34 {end}a{radius} {radius} 0 0 0 {radius}-{radius}H34z"/>',
    )


def frame_margin_hints(prefix: str) -> tuple[str, ...]:
    """Keep every prefix's content margins at the shared 4 dp inset."""

    name = f"{prefix}-" if prefix else ""
    return (
        f'  <rect id="{name}hint-top-margin" x="31" y="18" width="4" height="4" fill="#ff00ff"/>',
        f'  <rect id="{name}hint-bottom-margin" x="31" y="44" width="4" height="4" fill="#ff00ff"/>',
        f'  <rect id="{name}hint-left-margin" x="18" y="31" width="4" height="4" fill="#ff00ff"/>',
        f'  <rect id="{name}hint-right-margin" x="44" y="31" width="4" height="4" fill="#ff00ff"/>',
    )


def menubar_frame(prefix: str, origin_x: int, radius: int = 8) -> tuple[str, ...]:
    """Return a compact rounded nine-slice used by Plasma AppMenu delegates."""

    left = origin_x + 2
    center_left = left + radius
    center_right = origin_x + 40 - radius
    right = origin_x + 40
    top = 2
    center_top = top + radius
    center_bottom = 32 - radius
    bottom = 32
    center_width = center_right - center_left
    center_height = center_bottom - center_top
    return (
        f'  <rect id="{prefix}-center" x="{center_left}" y="{center_top}" width="{center_width}" height="{center_height}"/>',
        f'  <rect id="{prefix}-top" x="{center_left}" y="{top}" width="{center_width}" height="{radius}"/>',
        f'  <rect id="{prefix}-bottom" x="{center_left}" y="{center_bottom}" width="{center_width}" height="{radius}"/>',
        f'  <rect id="{prefix}-left" x="{left}" y="{center_top}" width="{radius}" height="{center_height}"/>',
        f'  <rect id="{prefix}-right" x="{center_right}" y="{center_top}" width="{radius}" height="{center_height}"/>',
        f'  <path id="{prefix}-topleft" d="M{center_left} {top}A{radius} {radius} 0 0 0 {left} {center_top}H{center_left}Z"/>',
        f'  <path id="{prefix}-topright" d="M{center_right} {top}A{radius} {radius} 0 0 1 {right} {center_top}H{center_right}Z"/>',
        f'  <path id="{prefix}-bottomleft" d="M{left} {center_bottom}A{radius} {radius} 0 0 0 {center_left} {bottom}V{center_bottom}Z"/>',
        f'  <path id="{prefix}-bottomright" d="M{center_right} {center_bottom}H{right}A{radius} {radius} 0 0 1 {center_right} {bottom}Z"/>',
    )


def menubar_hints(prefix: str, origin_x: int) -> tuple[str, ...]:
    """Use an 8 dp content inset, matching the compact top-bar rhythm."""

    return (
        f'  <rect id="{prefix}-hint-top-margin" x="{origin_x + 20}" y="2" width="2" height="8" fill="#ff00ff"/>',
        f'  <rect id="{prefix}-hint-bottom-margin" x="{origin_x + 20}" y="24" width="2" height="8" fill="#ff00ff"/>',
        f'  <rect id="{prefix}-hint-left-margin" x="{origin_x + 2}" y="16" width="8" height="2" fill="#ff00ff"/>',
        f'  <rect id="{prefix}-hint-right-margin" x="{origin_x + 32}" y="16" width="8" height="2" fill="#ff00ff"/>',
    )


def render_menubar() -> str:
    """Render KDE's standard widgets/menubaritem contract without forking AppMenu."""

    normal = menubar_frame("normal", 0)
    hover = menubar_frame("hover", 42)
    pressed = menubar_frame("pressed", 84)
    return "\n".join(
        (
            '<svg xmlns="http://www.w3.org/2000/svg" width="126" height="34" viewBox="0 0 126 34">',
            '  <style id="current-color-scheme" type="text/css">',
            '    .ColorScheme-ButtonFocus { color: #6750a4; }',
            '  </style>',
            '  <g fill="transparent">',
            *normal,
            '  </g>',
            '  <g class="ColorScheme-ButtonFocus" fill="currentColor">',
            *hover,
            *pressed,
            '  </g>',
            *menubar_hints("normal", 0),
            *menubar_hints("hover", 42),
            *menubar_hints("pressed", 84),
            '</svg>',
            '',
        )
    )


def render(target: ThemeTarget) -> str:
    # Plasma clamps a panel to the unprefixed FrameSvg's minimum drawing size
    # before it resolves its edge prefix.  Keep that fallback at 32 dp so a
    # compact top panel can be restored. The bottom edge has an explicit 32 dp
    # variant, preserving the large rounded silhouette used by the floating Dock.
    # The north variant avoids falling back to a bottom-oriented frame while the
    # panel changes location. Use KDE's ButtonBackground semantic class because
    # Meo's HCT projection maps it to surfaceContainerLow. This gives the panel
    # a visible wallpaper-derived tonal layer without hard-coding the live seed.
    compact_frame = frame_paths("", 16)
    north_frame = frame_paths("north", 16)
    south_frame = frame_paths("south", 32)
    compact_hints = frame_margin_hints("")
    north_hints = frame_margin_hints("north")
    south_hints = frame_margin_hints("south")
    return "\n".join(
        (
            '<svg xmlns="http://www.w3.org/2000/svg" width="66" height="66" viewBox="0 0 66 66">',
            '  <style id="current-color-scheme" type="text/css">',
            f'    .ColorScheme-ButtonBackground {{ color: {target.background}; }}',
            '  </style>',
            f'  <g class="ColorScheme-ButtonBackground" fill="currentColor" fill-opacity="{target.surface_opacity}">',
            *compact_frame,
            *north_frame,
            *south_frame,
            '  </g>',
            *compact_hints,
            *north_hints,
            *south_hints,
            '  <rect id="hint-stretch-borders" x="0" y="0" width="1" height="1" fill="#ff00ff"/>',
            '  <rect id="hint-compose-over-border" x="1" y="0" width="1" height="1" fill="#ff00ff"/>',
            '</svg>',
            '',
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected_by_target = {target.path: render(target) for target in PANEL_TARGETS}
    menubar = render_menubar()
    expected_by_target.update({path: menubar for path in MENUBAR_TARGETS})

    if args.check:
        stale = [
            str(path.relative_to(ROOT))
            for path, expected in expected_by_target.items()
            if not path.exists() or path.read_text(encoding="utf-8") != expected
        ]
        if stale:
            print("Stale generated floating Dock assets: " + ", ".join(stale))
            return 1
        return 0

    for path, expected in expected_by_target.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
