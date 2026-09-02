# MeoSymbols design guide

- Base style: Material Symbols Rounded.
- System icons: neutral monochrome SVGs using KDE's `current-color-scheme` contract.
- `MeoSymbols` provides a dark-on-light fallback; `MeoSymbolsDark` provides a light-on-dark fallback.
- The Meo light/dark switch selects the matching color, Plasma and icon variants together.
- App identities: Meo Application Icon Studio starts from each installed
  application's original local icon and renders a unique hicolor asset with a
  wallpaper-derived Material container. It preserves recognizable brand marks
  instead of replacing them with generic line glyphs. See
  `docs/icons/APP_ICON_STUDIO.md`.
- System-status icons (network, microphone, volume, battery, and related KDE
  semantics) are never renamed or overridden by Application Icon Studio.
- Fallback: `MeoSymbols → Breeze → hicolor` and `MeoSymbolsDark → Breeze Dark → Breeze → hicolor`.
- Animation and state belong to QML/C++; static SVGs contain no logic.
