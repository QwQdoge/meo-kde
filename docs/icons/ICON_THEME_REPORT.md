# MeoSymbols phase-one report

The icon theme implements System Settings categories, small toolbar/panel/status
icons, quick-settings semantics, and places. Application identities are
handled separately by Meo Application Icon Studio, which preserves original
local app branding in unique user-local hicolor assets.

## Verified coverage

- Material Symbols Rounded entry points per variant: 321 (includes `symbolic/` exposures).
- Variants: `MeoSymbols` for light surfaces and `MeoSymbolsDark` for dark surfaces.
- Semantic aliases: 10.
- Missing Material mappings: 0.
- KDE System Settings names observed on the target Plasma 6 installation: 68.
- KDE System Settings names resolved by MeoSymbols: 68.
- KDE System Settings Breeze fallbacks: 0.

Both variants use KDE's `current-color-scheme` SVG contract. A fixed light or
dark fallback color also keeps icons visible in Qt paths that do not perform
KDE palette substitution. The mode switch selects the matching icon variant.

## Scope boundary

MeoSymbols is a system-semantic theme only. Application Icon Studio leaves the
global KDE icon theme unchanged and updates only selected applications' local
`.desktop` `Icon=` values to unique `org.meo.iconstudio.app.*` names. This
prevents collisions with Wi‑Fi, microphone, volume, battery, and other shared
KDE icon names while allowing app marks to retain their visual identity.

Build cache is local and disposable. Runtime evidence is written to
`/home/shekong/Projects/outputs/meo-kde/validation/<UTC-run-id>/`.
