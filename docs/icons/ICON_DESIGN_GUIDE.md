# MeoSymbols design guide

- Base style: Material Symbols Rounded.
- System icons: neutral monochrome SVGs using KDE's `current-color-scheme` contract.
- `MeoSymbols` provides a dark-on-light fallback; `MeoSymbolsDark` provides a light-on-dark fallback.
- The Meo light/dark switch selects the matching color, Plasma and icon variants together.
- App identities: Meo Application Icon Studio starts from the currently
  installed artwork and preserves its recognizable mark instead of replacing
  it with a generic line glyph. A name-safe identity uses the user-level
  `MeoUser → MeoSymbols → Breeze → hicolor` overlay; shared, absolute, and
  runtime-private names use a tightly managed fallback or remain Original.
  See `docs/icons/APP_ICON_STUDIO.md` and `docs/icons/ICON_CONTRACT_V1.md`.
- Original is a real icon-lookup restoration, never an AI/redrawn imitation;
  it has no Meo container or selectable shape.
- Hand-authored application geometry follows the `48u` Meo Icon Contract v1.
  Small 32/22/16 px optical masters are permitted only with named, reviewed
  corrections; source geometry must not contain unexplained decimal magic
  constants.
- System-status icons (network, microphone, volume, battery, and related KDE
  semantics) are never renamed or overridden by Application Icon Studio.
- Fallback: `MeoSymbols → Breeze → hicolor` and `MeoSymbolsDark → Breeze Dark → Breeze → hicolor`.
- Animation and state belong to QML/C++; static SVGs contain no logic.
