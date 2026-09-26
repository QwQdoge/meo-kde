#!/usr/bin/env python3
"""Generate Meo Plasma view-item frames.

PlasmaComponents and other shell delegates consume widgets/viewitem.svg from
the active Plasma Style.  Providing the supported theme asset lets Plasma keep
owning menu/delegate behavior while Meo replaces the inherited Breeze visual
states.  The geometry mirrors the rounded action-card language used by
MeoContextMenu and the native Meo QStyle.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
THEMES = {
    "MeoLight": {
        "surface": "#ece6f0",
        "hover": "#e8def8",
        "accent": "#6750a4",
    },
    "MeoDark": {
        "surface": "#36343b",
        "hover": "#4a4458",
        "accent": "#d0bcff",
    },
}
FRAME = 48
BORDER = 16
CENTER = FRAME - BORDER * 2
GAP = 2
STATES = (
    ("normal", "ColorScheme-ButtonBackground", 0.88),
    ("hover", "ColorScheme-ButtonHover", 1.00),
    ("selected", "ColorScheme-Highlight", 0.86),
    ("selected+hover", "ColorScheme-Highlight", 1.00),
)


def frame(prefix: str, offset: int, css_class: str, opacity: float) -> str:
    x = offset
    r = BORDER
    c = CENTER
    common = (
        f' class="{css_class}" fill="currentColor" '
        f'fill-opacity="{opacity:.2f}"'
    )
    return f"""
  <g id="{prefix}">
    <rect id="{prefix}-center" x="{x+r}" y="{r}" width="{c}" height="{c}"{common}/>
    <rect id="{prefix}-top" x="{x+r}" y="0" width="{c}" height="{r}"{common}/>
    <rect id="{prefix}-bottom" x="{x+r}" y="{FRAME-r}" width="{c}" height="{r}"{common}/>
    <rect id="{prefix}-left" x="{x}" y="{r}" width="{r}" height="{c}"{common}/>
    <rect id="{prefix}-right" x="{x+FRAME-r}" y="{r}" width="{r}" height="{c}"{common}/>
    <path id="{prefix}-topleft" d="M {x+r} 0 V {r} H {x} A {r} {r} 0 0 1 {x+r} 0 Z"{common}/>
    <path id="{prefix}-topright" d="M {x+FRAME-r} 0 V {r} H {x+FRAME} A {r} {r} 0 0 0 {x+FRAME-r} 0 Z"{common}/>
    <path id="{prefix}-bottomleft" d="M {x} {FRAME-r} H {x+r} V {FRAME} A {r} {r} 0 0 1 {x} {FRAME-r} Z"{common}/>
    <path id="{prefix}-bottomright" d="M {x+FRAME-r} {FRAME-r} H {x+FRAME} A {r} {r} 0 0 1 {x+FRAME-r} {FRAME} Z"{common}/>
  </g>"""


def document(surface: str, hover: str, accent: str) -> str:
    width = FRAME * len(STATES) + GAP * (len(STATES) - 1)
    chunks = []
    for index, (prefix, css_class, opacity) in enumerate(STATES):
        chunks.append(frame(prefix, index * (FRAME + GAP), css_class, opacity))
    frames = "\n".join(chunks)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{FRAME}" viewBox="0 0 {width} {FRAME}">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-ButtonBackground {{ color: {surface}; }}
      .ColorScheme-ButtonHover {{ color: {hover}; }}
      .ColorScheme-Highlight {{ color: {accent}; }}
    </style>
  </defs>
  <!-- Plasma substitutes the CSS classes above with the active system/accent
       colours.  The literals are deterministic fallback colours for previews. -->
{frames}
</svg>
"""


def main() -> None:
    for theme, palette in THEMES.items():
        data = document(**palette)
        targets = (
            ROOT / f"themes/desktoptheme/{theme}/widgets/viewitem.svg",
            ROOT / f"themes/desktoptheme/{theme}/translucent/widgets/viewitem.svg",
        )
        for target in targets:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(data, encoding="utf-8")
            print(target.relative_to(ROOT))


if __name__ == "__main__":
    main()
