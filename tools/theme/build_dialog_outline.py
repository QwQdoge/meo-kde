#!/usr/bin/env python3
"""Add a hairline outline to the Meo Plasma dialog backgrounds.

Idempotent: rewrites each dialog nine-patch from its existing fill colour and
opacity, so the outline follows the active KDE scheme's text colour.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "themes/desktoptheme"
OUTLINE = {"MeoLight": ("#1c1b1f", "0.10"), "MeoDark": ("#e6e0e9", "0.14")}

TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" width="78" height="78" viewBox="0 0 78 78">
  <style id="current-color-scheme" type="text/css">
    .ColorScheme-Background {{ color: {bg}; }}
    .ColorScheme-Text {{ color: {fg}; }}
  </style>
  <g fill="currentColor" class="ColorScheme-Background" fill-opacity="{opacity}">
    <path id="center" d="M26 26h26v26H26z"/>
    <g id="top"><path d="M26 2h26v24H26z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M26 2.5h26"/></g>
    <g id="bottom"><path d="M26 52h26v24H26z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M26 75.5h26"/></g>
    <g id="left"><path d="M2 26h24v26H2z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M2.5 26v26"/></g>
    <g id="right"><path d="M52 26h24v26H52z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M75.5 26v26"/></g>
    <g id="topleft"><path d="M26 2C12.7 2 2 12.7 2 26h24z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M26 2.5A23.5 23.5 0 0 0 2.5 26"/></g>
    <g id="topright"><path d="M52 2c13.3 0 24 10.7 24 24H52z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M52 2.5A23.5 23.5 0 0 1 75.5 26"/></g>
    <g id="bottomleft"><path d="M2 52c0 13.3 10.7 24 24 24V52z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M2.5 52A23.5 23.5 0 0 0 26 75.5"/></g>
    <g id="bottomright"><path d="M52 76c13.3 0 24-10.7 24-24H52z"/><path class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-opacity="{line}" d="M75.5 52A23.5 23.5 0 0 1 52 75.5"/></g>
  </g>
  <rect id="hint-top-margin" x="37" y="22" width="4" height="4" fill="#ff00ff"/><rect id="hint-bottom-margin" x="37" y="52" width="4" height="4" fill="#ff00ff"/><rect id="hint-left-margin" x="22" y="37" width="4" height="4" fill="#ff00ff"/><rect id="hint-right-margin" x="52" y="37" width="4" height="4" fill="#ff00ff"/><rect id="hint-stretch-borders" x="0" y="0" width="1" height="1" fill="#ff00ff"/>
</svg>
"""

for theme, (fg, line) in OUTLINE.items():
    for rel in ("dialogs/background.svg", "translucent/dialogs/background.svg"):
        path = ROOT / theme / rel
        src = path.read_text(encoding="utf-8")
        bg = re.search(r"ColorScheme-Background \{ color: (#[0-9a-fA-F]+);", src).group(1)
        opacity = re.search(r'fill-opacity="([0-9.]+)"', src).group(1)
        path.write_text(TEMPLATE.format(bg=bg, fg=fg, line=line, opacity=opacity), encoding="utf-8")
