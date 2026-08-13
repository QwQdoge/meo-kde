# Meo Application Style architecture

`Meo` is an independent Qt 6 `QStylePlugin`. It installs as
`styles/meostyle.so`, exposes only the `Meo` key, and is implemented with the
public Qt Widgets style API. It neither modifies nor replaces Breeze or Fusion.

## Shared design source

MeoUI owns `runtime/meotokens.h`. The `Meo::DesignTokens` API is the canonical
source for P0 shape, spacing, icon-size, control-height, and state-layer
values. The `MeoTokens` QML singleton exposes those same values to
`MeoTheme.qml`; MeoStyle compiles against the same source API. There is no QML
renderer in the QWidget paint path.

Colour is deliberately dynamic rather than frozen into a second style palette:
MeoUI receives palette roles through `MeoShellTheme`, while MeoStyle maps the
active `QPalette` at paint time. That preserves KDE light/dark mode and accent
changes.

## Rendering boundaries

- MeoStyle paints Qt Widgets only.
- MeoUI renders Qt Quick controls after `import MeoUI 1.0`.
- KDecoration owns title bars and caption buttons.
- KWin effects own window-level rounding and compositor behavior.
- Plasma packages/Plasmoids own the shell.

The initial implementation uses Fusion as a compatibility base for controls
not yet custom-painted. This keeps KDE widget geometry and accessibility
semantics intact while P0 coverage expands.

## Installation

CMake uses `QT6_INSTALL_PLUGINS/styles`, not a hard-coded host path. A package
install does not set `widgetStyle` or write user configuration. Users choose
Meo through System Settings after installation.
