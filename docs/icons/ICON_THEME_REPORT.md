# MeoSymbols phase-one report

This phase implements the system icon theme only: System Settings categories,
small toolbar/panel/status icons, quick-settings semantics and basic places.
Third-party app logos are intentionally excluded.

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

MeoSymbols does not replace branded third-party application launchers. Shelf
and launcher application identities continue to use the `.desktop` icon they
already expose; only semantic system controls are owned by this theme.

Build and runtime evidence is written to `build/` and the shared
`outputs/evidence/meo-kde/` directory.
