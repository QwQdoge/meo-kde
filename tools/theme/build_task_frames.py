#!/usr/bin/env python3
"""Generate Material task-frame SVGs for Plasma's native task manager."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

@dataclass(frozen=True)
class ThemeTarget:
    path: Path
    text: str
    focus: str
    attention: str


TARGETS = (
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/widgets/tasks.svg",
        text="#1c1b1f",
        focus="#6750a4",
        attention="#b3261e",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/widgets/tasks.svg",
        text="#e6e0e9",
        focus="#d0bcff",
        attention="#ffb4ab",
    ),
)

SIZE = 48
# Match MeoTheme.shapeLarge. The 48 dp native task target keeps a full
# Material state layer while the icon stays a native Plasma/KDE icon.
CORNER = 16
CENTER = SIZE - 2 * CORNER


@dataclass(frozen=True)
class Indicator:
    width: int
    height: int
    opacity: str


def frame(
    name: str,
    y: int,
    color_class: str,
    opacity: str,
    indicator: Indicator | None = None,
) -> list[str]:
    center_x = CORNER
    center_y = y + CORNER
    right_x = CORNER + CENTER
    bottom_y = y + CORNER + CENTER
    lines = [f'  <g class="{color_class}" fill="currentColor">']
    lines.extend(
        (
            f'    <rect id="{name}-center" x="{center_x}" y="{center_y}" width="{CENTER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-top" x="{center_x}" y="{y}" width="{CENTER}" height="{CORNER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-left" x="0" y="{center_y}" width="{CORNER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-right" x="{right_x}" y="{center_y}" width="{CORNER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <path id="{name}-topleft" d="M{CORNER} {y}A{CORNER} {CORNER} 0 0 0 0 {center_y}H{CORNER}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-topright" d="M{right_x} {y}A{CORNER} {CORNER} 0 0 1 {SIZE} {center_y}H{right_x}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-bottomleft" d="M0 {bottom_y}A{CORNER} {CORNER} 0 0 0 {CORNER} {y + SIZE}V{bottom_y}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-bottomright" d="M{right_x} {bottom_y}V{y + SIZE}A{CORNER} {CORNER} 0 0 0 {SIZE} {bottom_y}Z" opacity="{opacity}"/>',
        )
    )
    if indicator:
        indicator_x = (SIZE - indicator.width) // 2
        indicator_y = y + SIZE - indicator.height - 2
        lines.append(f'    <g id="{name}-bottom">')
        lines.append(
            f'      <rect x="{center_x}" y="{bottom_y}" width="{CENTER}" height="{CORNER}" opacity="{opacity}"/>'
        )
        lines.append(
            f'      <rect x="{indicator_x}" y="{indicator_y}" width="{indicator.width}" height="{indicator.height}" rx="{indicator.height / 2:g}" opacity="{indicator.opacity}"/>'
        )
        lines.append("    </g>")
    else:
        lines.append(
            f'    <rect id="{name}-bottom" x="{center_x}" y="{bottom_y}" width="{CENTER}" height="{CORNER}" opacity="{opacity}"/>'
        )
    lines.append("  </g>")
    return lines


def render(target: ThemeTarget) -> str:
    # Task.qml uses normal/focus/minimized/attention prefixes for real task
    # states. When hovered, it asks for <base>-hover before the generic hover
    # frame. Keep each semantic state visible in that path: a generic hover
    # frame alone would erase the active or running indicator.
    states = (
        # Non-active running app: no bubble, only a restrained running marker.
        ("normal", "ColorScheme-Text", "0", Indicator(8, 3, "0.72")),
        # Active app: Pixel-style primary state layer plus a wider indicator.
        ("focus", "ColorScheme-ButtonFocus", "0.18", Indicator(16, 3, "0.96")),
        # Minimized apps remain discoverable without competing with the active task.
        ("minimized", "ColorScheme-Text", "0", Indicator(6, 2, "0.40")),
        ("attention", "ColorScheme-NeutralText", "0.20", Indicator(16, 3, "0.96")),
        # Progress is painted in a clipped overlay by the native task manager.
        ("progress", "ColorScheme-ButtonFocus", "0.12", None),
        # Per-state hover frames preserve the corresponding active/running cue.
        ("normal-hover", "ColorScheme-Text", "0.10", Indicator(8, 3, "0.82")),
        ("focus-hover", "ColorScheme-ButtonFocus", "0.24", Indicator(16, 3, "0.96")),
        ("minimized-hover", "ColorScheme-Text", "0.10", Indicator(6, 2, "0.56")),
        ("attention-hover", "ColorScheme-NeutralText", "0.26", Indicator(16, 3, "0.96")),
        # Pure pinned launchers use an empty base prefix; give only hover feedback.
        ("launcher-hover", "ColorScheme-Text", "0.10", None),
        # Safe fallback for future/native task states that do not have a variant.
        ("hover", "ColorScheme-Text", "0.10", None),
    )
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="{SIZE * len(states)}" viewBox="0 0 96 {SIZE * len(states)}">',
        '  <style id="current-color-scheme" type="text/css">',
        f'    .ColorScheme-Text {{ color: {target.text}; }}',
        f'    .ColorScheme-ButtonFocus {{ color: {target.focus}; }}',
        f'    .ColorScheme-NeutralText {{ color: {target.attention}; }}',
        '  </style>',
    ]
    for index, (name, color_class, opacity, indicator) in enumerate(states):
        lines.extend(frame(name, index * SIZE, color_class, opacity, indicator))
    lines.extend(
        (
            '  <g class="ColorScheme-ButtonFocus" fill="currentColor">',
            '    <rect id="group-expander-left" x="58" y="8" width="3" height="8" rx="1.5" opacity="0.72"/>',
            '    <rect id="group-expander-right" x="66" y="8" width="3" height="8" rx="1.5" opacity="0.72"/>',
            '    <rect id="group-expander-top" x="58" y="20" width="11" height="3" rx="1.5" opacity="0.72"/>',
            '    <rect id="group-expander-bottom" x="58" y="28" width="11" height="3" rx="1.5" opacity="0.72"/>',
            '  </g>',
            '  <rect id="normal-hint-top-margin" x="70" y="40" width="6" height="6" fill="#ff00ff"/>',
            '  <rect id="normal-hint-bottom-margin" x="78" y="40" width="6" height="6" fill="#ff00ff"/>',
            '  <rect id="normal-hint-left-margin" x="70" y="48" width="6" height="6" fill="#ff00ff"/>',
            '  <rect id="normal-hint-right-margin" x="78" y="48" width="6" height="6" fill="#ff00ff"/>',
            '  <rect id="hint-stretch-borders" width="1" height="1" fill="#ff00ff"/>',
            '  <rect id="hint-compose-over-border" x="1" width="1" height="1" fill="#ff00ff"/>',
            '</svg>',
            '',
        )
    )
    return "\n".join(lines)


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
            print("Stale generated task frames: " + ", ".join(stale))
            return 1
        return 0
    for target, expected in expected_by_target.items():
        target.path.parent.mkdir(parents=True, exist_ok=True)
        target.path.write_text(expected, encoding="utf-8")
        print(target.path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
