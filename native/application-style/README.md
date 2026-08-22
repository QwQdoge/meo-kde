# Meo Qt Widgets style

`meostyle` is a `QProxyStyle` for native Qt Widgets applications. On KDE it
uses Breeze as its base style, retaining platform behaviour that Meo does not
override, and paints Meo surfaces from the `QPalette` supplied with each style
option. It does not cache a light, dark, or accent palette.

The local offscreen smoke test verifies plugin discovery, Breeze preference
when Breeze is available, real widget/menu rendering, interaction-state
rendering, disabled roles, and repainting across changed light/dark and accent
semantic palettes.
Those checks do not prove that a desktop session selected the plugin or that
already-running applications handled a live KDE colour-scheme notification.

## LibreOffice boundary

LibreOffice renders its interface through VCL. The `kf6`/`qt6` VCL backends may
use Qt platform facilities, but a Qt `QStyle` plugin being installed or selected
does not prove that every LibreOffice menu, combo box, toolbar, sidebar, or
dialog is painted by `meostyle`. This project therefore does not claim blanket
LibreOffice coverage.

LibreOffice acceptance must be performed separately with an isolated user
profile. Confirm the selected VCL backend at runtime, confirm the loaded shared
libraries for that process, and visually exercise Writer and Calc menus, combo
boxes, toolbars, sidebars, and settings dialogs in light, dark, disabled,
focused, hovered, and pressed states. Repeat after a dynamic accent change. If
VCL substitutes its own application style or palette, integration belongs in a
reversible LibreOffice theme/extension layer rather than in assumptions inside
this Qt Widgets plugin.
