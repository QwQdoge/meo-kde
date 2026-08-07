# MeoSymbols design guide

- Base style: Material Symbols Rounded.
- System icons: neutral monochrome SVGs using KDE's `current-color-scheme` contract.
- `MeoSymbols` provides a dark-on-light fallback; `MeoSymbolsDark` provides a light-on-dark fallback.
- The Meo light/dark switch selects the matching color, Plasma and icon variants together.
- App identities: retain third-party branding; only Meo-specific assets use a `meo-*` name.
- Fallback: `MeoSymbols → Breeze → hicolor` and `MeoSymbolsDark → Breeze Dark → Breeze → hicolor`.
- Animation and state belong to QML/C++; static SVGs contain no logic.
