#!/usr/bin/env python3
"""Generate floating Material Dock backgrounds for the Plasma desktop themes."""

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


TARGETS = (
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/widgets/panel-background.svg",
        background="#fffbfe",
        surface_opacity="0.92",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/widgets/panel-background.svg",
        background="#141218",
        surface_opacity="0.92",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/translucent/widgets/panel-background.svg",
        background="#fffbfe",
        surface_opacity="0.84",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/translucent/widgets/panel-background.svg",
        background="#141218",
        surface_opacity="0.84",
    ),
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


def render(target: ThemeTarget) -> str:
    # Plasma clamps a panel to the unprefixed FrameSvg's minimum drawing size
    # before it resolves its edge prefix.  Keep that fallback at 32 dp so a
    # compact top panel can be restored.  The bottom edge has an explicit 28 dp
    # variant, preserving the large rounded silhouette used by the floating Dock.
    # The north variant avoids falling back to a bottom-oriented frame while the
    # panel changes location.  Surface colors stay in the semantic Background
    # role, so dynamic Material colors remain seam-free across the slices.
    compact_frame = frame_paths("", 16)
    north_frame = frame_paths("north", 16)
    south_frame = frame_paths("south", 28)
    compact_hints = frame_margin_hints("")
    north_hints = frame_margin_hints("north")
    south_hints = frame_margin_hints("south")
    return "\n".join(
        (
            '<svg xmlns="http://www.w3.org/2000/svg" width="66" height="66" viewBox="0 0 66 66">',
            '  <style id="current-color-scheme" type="text/css">',
            f'    .ColorScheme-Background {{ color: {target.background}; }}',
            '  </style>',
            f'  <g class="ColorScheme-Background" fill="currentColor" fill-opacity="{target.surface_opacity}">',
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
    expected_by_target = {target: render(target) for target in TARGETS}

    if args.check:
        stale = [
            str(target.path.relative_to(ROOT))
            for target, expected in expected_by_target.items()
            if not target.path.exists() or target.path.read_text(encoding="utf-8") != expected
        ]
        if stale:
            print("Stale generated floating Dock assets: " + ", ".join(stale))
            return 1
        return 0

    for target, expected in expected_by_target.items():
        target.path.parent.mkdir(parents=True, exist_ok=True)
        target.path.write_text(expected, encoding="utf-8")
        print(target.path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
