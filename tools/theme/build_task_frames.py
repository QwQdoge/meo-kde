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
    background: str
    focus: str
    attention: str


TARGETS = (
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoLight/widgets/tasks.svg",
        text="#1c1b1f",
        background="#fffbfe",
        focus="#6750a4",
        attention="#b3261e",
    ),
    ThemeTarget(
        ROOT / "themes/desktoptheme/MeoDark/widgets/tasks.svg",
        text="#e6e0e9",
        background="#141218",
        focus="#d0bcff",
        attention="#ffb4ab",
    ),
)

SIZE = 48
# The task manager gives each launcher a 48 dp hit target. Do not paint that
# entire target: touching full-size circles read as a row of pill cells instead
# of one calm floating surface with separate app icons. Keep a 3 dp transparent
# gutter and render a 42 dp circular icon well inside. A 1 dp centre patch
# remains because KSvg's FrameSvg needs a non-zero stretch region.
WELL_INSET = 3
WELL_SIZE = SIZE - 2 * WELL_INSET
CORNER = (WELL_SIZE - 1) / 2
CENTER = 1


@dataclass(frozen=True)
class Indicator:
    width: int
    height: int
    opacity: str
    color_class: str


def frame(
    name: str,
    y: int,
    color_class: str,
    opacity: str,
    indicator: Indicator | None = None,
) -> list[str]:
    left_x = WELL_INSET
    top_y = y + WELL_INSET
    center_x = left_x + CORNER
    center_y = top_y + CORNER
    right_x = center_x + CENTER
    bottom_y = center_y + CENTER
    well_right = left_x + WELL_SIZE
    well_bottom = top_y + WELL_SIZE
    lines = [f'  <g class="{color_class}" fill="currentColor">']
    lines.extend(
        (
            f'    <rect id="{name}-center" x="{center_x}" y="{center_y}" width="{CENTER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-top" x="{center_x}" y="{top_y}" width="{CENTER}" height="{CORNER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-left" x="{left_x}" y="{center_y}" width="{CORNER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <rect id="{name}-right" x="{right_x}" y="{center_y}" width="{CORNER}" height="{CENTER}" opacity="{opacity}"/>',
            f'    <path id="{name}-topleft" d="M{center_x} {top_y}A{CORNER} {CORNER} 0 0 0 {left_x} {center_y}H{center_x}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-topright" d="M{right_x} {top_y}A{CORNER} {CORNER} 0 0 1 {well_right} {center_y}H{right_x}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-bottomleft" d="M{left_x} {bottom_y}A{CORNER} {CORNER} 0 0 0 {center_x} {well_bottom}V{bottom_y}Z" opacity="{opacity}"/>',
            f'    <path id="{name}-bottomright" d="M{right_x} {bottom_y}V{well_bottom}A{CORNER} {CORNER} 0 0 0 {well_right} {bottom_y}Z" opacity="{opacity}"/>',
        )
    )
    lines.append(
        f'    <rect id="{name}-bottom" x="{center_x}" y="{bottom_y}" width="{CENTER}" height="{CORNER}" opacity="{opacity}"/>'
    )
    lines.append("  </g>")
    if indicator:
        indicator_x = (SIZE - indicator.width) // 2
        indicator_y = y + WELL_INSET + WELL_SIZE - indicator.height - 3
        lines.extend(
            (
                f'  <g id="{name}-indicator" class="{indicator.color_class}" fill="currentColor">',
                f'    <rect x="{indicator_x}" y="{indicator_y}" width="{indicator.width}" height="{indicator.height}" rx="{indicator.height / 2:g}" opacity="{indicator.opacity}"/>',
                "  </g>",
            )
        )
    return lines


def bar_frame(name: str, y: int, color_class: str, lead: int, opacity: str) -> list[str]:
    """A nine-slice frame whose only visible content is a short bar.

    The left and right columns are `lead` wide and the middle column is
    SIZE - 2 * lead wide, so on a 48 dp task button the bar is that middle
    column wide, centred, and sits a couple of dp above the Shelf's edge. Every
    other slice is transparent. Plasma's FrameSvg needs all nine slices, so each
    is present as an invisible rect; the bar is drawn inside the bottom-centre
    slice.
    """

    top_h = 1
    bottom_h = 7
    mid_h = SIZE - top_h - bottom_h
    center_w = SIZE - 2 * lead
    bar_h = 3
    bar_offset = 2
    cols = ((0, lead), (lead, center_w), (lead + center_w, lead))
    rows = ((y, top_h), (y + top_h, mid_h), (y + top_h + mid_h, bottom_h))
    names = (
        ("topleft", "top", "topright"),
        ("left", "center", "right"),
        ("bottomleft", "bottom", "bottomright"),
    )
    lines = [f'  <g class="{color_class}" fill="currentColor">']
    for r, (ry, rh) in enumerate(rows):
        for c, (cx, cw) in enumerate(cols):
            part = names[r][c]
            if part == "bottom":
                lines.extend(
                    (
                        f'    <g id="{name}-{part}">',
                        f'      <rect x="{cx}" y="{ry}" width="{cw}" height="{rh}" opacity="0"/>',
                        f'      <rect x="{cx}" y="{ry + bar_offset}" width="{cw}" height="{bar_h}" rx="{bar_h / 2:g}" opacity="{opacity}"/>',
                        "    </g>",
                    )
                )
            else:
                lines.append(
                    f'    <rect id="{name}-{part}" x="{cx}" y="{ry}" width="{cw}" height="{rh}" opacity="0"/>'
                )
    lines.append("  </g>")
    return lines


def render(target: ThemeTarget) -> str:
    # Keep every running task discoverable, not only the focused window.
    # GoogleBook-style taskbars show a short marker for an open application and
    # strengthen it for the active task. Minimized tasks retain the same shape
    # at lower opacity so state changes do not make the marker jump in width.
    running = Indicator(12, 2, "0.72", "ColorScheme-ButtonFocus")
    running_hover = Indicator(12, 2, "0.88", "ColorScheme-ButtonFocus")

    # Task.qml uses normal/focus/minimized/attention prefixes for real task
    # states. When hovered, it asks for <base>-hover before the generic hover
    # frame. Keep each semantic state visible in that path: a generic hover
    # frame alone would erase the active or running indicator.
    # Running tasks show a short bar under the icon in the dynamic accent
    # color: shorter and softer for an open window, longer and solid for the
    # active one, short and faint for a minimized one. A bar frame is its own
    # slice grid, so hovering keeps the same bar (a touch stronger) instead of
    # a well that could not be combined with it.
    states = (
        ("normal", "bar", ("ColorScheme-ButtonFocus", 19, "0.6")),
        ("focus", "bar", ("ColorScheme-ButtonFocus", 15, "1")),
        ("minimized", "bar", ("ColorScheme-ButtonFocus", 20, "0.35")),
        ("attention", "well", ("ColorScheme-NeutralText", "0.14", Indicator(18, 4, "1", "ColorScheme-NeutralText"))),
        # Progress is painted in a clipped overlay by the native task manager.
        ("progress", "well", ("ColorScheme-ButtonFocus", "0.12", running)),
        ("normal-hover", "bar", ("ColorScheme-ButtonFocus", 17, "0.85")),
        ("focus-hover", "bar", ("ColorScheme-ButtonFocus", 13, "1")),
        ("minimized-hover", "bar", ("ColorScheme-ButtonFocus", 18, "0.5")),
        ("attention-hover", "well", ("ColorScheme-NeutralText", "0.18", Indicator(18, 4, "1", "ColorScheme-NeutralText"))),
        # Pure pinned launchers use an empty base prefix; give only hover feedback.
        ("launcher-hover", "well", ("ColorScheme-Background", "0.10", None)),
        # Safe fallback for future/native task states that do not have a variant.
        ("hover", "well", ("ColorScheme-Background", "0.10", None)),
    )
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="{SIZE * len(states)}" viewBox="0 0 96 {SIZE * len(states)}">',
        '  <style id="current-color-scheme" type="text/css">',
        f'    .ColorScheme-Text {{ color: {target.text}; }}',
        f'    .ColorScheme-Background {{ color: {target.background}; }}',
        f'    .ColorScheme-ButtonFocus {{ color: {target.focus}; }}',
        f'    .ColorScheme-NeutralText {{ color: {target.attention}; }}',
        '  </style>',
    ]
    for index, (name, kind, args) in enumerate(states):
        if kind == "bar":
            color_class, lead, opacity = args
            lines.extend(bar_frame(name, index * SIZE, color_class, lead, opacity))
        else:
            color_class, opacity, indicator = args
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
