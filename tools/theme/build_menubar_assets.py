#!/usr/bin/env python3
"""Generate Meo Plasma menubar item frames.

KDE's native org.kde.plasma.appmenu owns application menu discovery,
activation, pointer grabs, and QMenu presentation.  It asks the active Plasma
theme only for widgets/menubaritem.svg.  This generator supplies that visual
contract without forking or shadowing the KDE applet.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TARGETS = (
    ROOT / "themes/desktoptheme/MeoLight/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoDark/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoLight/translucent/widgets/menubaritem.svg",
    ROOT / "themes/desktoptheme/MeoDark/translucent/widgets/menubaritem.svg",
)

FRAME = 34
BORDER = 6
CENTER = FRAME - BORDER * 2


def frame(prefix: str, offset: int, opacity: float) -> str:
    x = offset
    cls = ' class="ColorScheme-Highlight"' if opacity > 0 else ""
    fill = "currentColor" if opacity > 0 else "transparent"
    common = f' fill="{fill}" fill-opacity="{opacity:.2f}"{cls}'
    return f"""
  <g id="{prefix}">
    <rect id="{prefix}-center" x="{x+BORDER}" y="{BORDER}" width="{CENTER}" height="{CENTER}"{common}/>
    <rect id="{prefix}-top" x="{x+BORDER}" y="2" width="{CENTER}" height="4"{common}/>
    <rect id="{prefix}-bottom" x="{x+BORDER}" y="{FRAME-BORDER}" width="{CENTER}" height="4"{common}/>
    <rect id="{prefix}-left" x="{x+2}" y="{BORDER}" width="4" height="{CENTER}"{common}/>
    <rect id="{prefix}-right" x="{x+FRAME-BORDER}" y="{BORDER}" width="4" height="{CENTER}"{common}/>
    <path id="{prefix}-topleft" d="M {x+BORDER} 2 V {BORDER} H {x+2} C {x+2} 3.79 {x+3.79} 2 {x+BORDER} 2 Z"{common}/>
    <path id="{prefix}-topright" d="M {x+FRAME-BORDER} 2 V {BORDER} H {x+FRAME-2} C {x+FRAME-2} 3.79 {x+FRAME-3.79} 2 {x+FRAME-BORDER} 2 Z"{common}/>
    <path id="{prefix}-bottomleft" d="M {x+BORDER} {FRAME-2} V {FRAME-BORDER} H {x+2} C {x+2} {FRAME-3.79} {x+3.79} {FRAME-2} {x+BORDER} {FRAME-2} Z"{common}/>
    <path id="{prefix}-bottomright" d="M {x+FRAME-BORDER} {FRAME-2} V {FRAME-BORDER} H {x+FRAME-2} C {x+FRAME-2} {FRAME-3.79} {x+FRAME-3.79} {FRAME-2} {x+FRAME-BORDER} {FRAME-2} Z"{common}/>
    <rect id="{prefix}-hint-top-margin" x="{x+16}" y="0" width="2" height="{BORDER}" opacity="0.01"/>
    <rect id="{prefix}-hint-bottom-margin" x="{x+16}" y="{FRAME-BORDER}" width="2" height="{BORDER}" opacity="0.01"/>
    <rect id="{prefix}-hint-left-margin" x="{x}" y="16" width="{BORDER}" height="2" opacity="0.01"/>
    <rect id="{prefix}-hint-right-margin" x="{x+FRAME-BORDER}" y="16" width="{BORDER}" height="2" opacity="0.01"/>
  </g>"""


def document() -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{FRAME*3+4}" height="{FRAME}" viewBox="0 0 {FRAME*3+4} {FRAME}">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Highlight {{ color: #6750a4; }}
    </style>
  </defs>
  <!-- Normal stays transparent so the application menu reads as panel text.
       Hover and pressed use KDE's semantic Highlight role; KDE also supplies
       HighlightedText for those states, preserving contrast in every scheme. -->
{frame("normal", 0, 0.0)}
{frame("hover", FRAME+2, 0.82)}
{frame("pressed", (FRAME+2)*2, 0.96)}
  <rect id="hint-stretch-borders" x="{FRAME}" y="0" width="1" height="1" opacity="0.01"/>
</svg>
"""


def main() -> None:
    data = document()
    for target in TARGETS:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data, encoding="utf-8")
        print(target.relative_to(ROOT))


if __name__ == "__main__":
    main()
