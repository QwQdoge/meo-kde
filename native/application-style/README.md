# Meo Qt Widgets style

`meostyle` is a `QProxyStyle` for native Qt Widgets applications. On KDE it
uses Breeze as its base style, retaining platform behaviour that Meo does not
override, and paints Meo surfaces from the `QPalette` supplied with each style
option. It does not cache a light, dark, or accent palette.

The local offscreen smoke test verifies plugin discovery, Breeze preference
when Breeze is available, real widget/menu/default-delegate rendering,
normal/hover/pressed/focused/disabled states, checked and indeterminate
indicators, RTL item-view rendering, and repainting across changed light/dark
and accent semantic palettes.
Those checks do not prove that a desktop session selected the plugin or that
already-running applications handled a live KDE colour-scheme notification.

## Supported controls and search fields

MeoStyle paints the standard Qt Widgets paths for buttons and tool buttons,
checkboxes and radio buttons, line edits, combo boxes, sliders, progress bars,
tabs, menus, scroll bars, and item views that use Qt's default
`QStyledItemDelegate`. It leaves text layout, icons, mnemonics, keyboard
navigation, popup positioning, and hit testing to the platform base style.

First-party `QPushButton` instances may opt into Pixel hierarchy with
`meo.variant=filled`, `tonal`, or `text`. A button marked `filled` uses the
active KDE primary/link color; unannotated third-party buttons remain tonal so
the style does not infer destructive or primary meaning from their labels.

An application-owned custom item delegate can paint any surface it chooses;
MeoStyle intentionally does not replace that delegate. Likewise, a `QLineEdit`
is only a generic text field to QStyle. First-party code may opt into the
semantic property `meo.role=search` and add its own leading search action and
clear button. MeoStyle styles that existing field and its actions, but never
guesses from placeholder text or injects actions into third-party applications.

## Theme-script activation

CMake package installation only puts the plugin in Qt's `styles` directory. The
Meo desktop apply flow is the explicit opt-in path: it backs up `kdeglobals`,
applies `[KDE] widgetStyle=Meo`, and the paired reset script restores the
backup. The new style is discovered by newly started Qt applications; neither
script restarts Plasma or KWin.

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
