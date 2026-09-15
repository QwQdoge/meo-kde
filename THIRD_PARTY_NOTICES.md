# Third-party notices

MeoKDE's original project code is licensed under GPL-3.0-or-later. Files with
their own SPDX headers, vendored code, fonts, and icon sources retain the
licenses listed below.

## KDE and Plasma-derived files

Several lock-screen and decoration files carry explicit
`GPL-2.0-or-later` or `GPL-3.0-or-later` SPDX headers. Those file-level
declarations take precedence over the repository default. The complete
GPL-2.0-or-later text is in `assets/licenses/GPL-2.0-or-later.txt`.

The separate `packaging/arch/meo-plasma-desktop` package applies a downstream
Plasma patch whose new source files are licensed `LGPL-2.0-or-later`. Its full
license text is in
`packaging/arch/meo-plasma-desktop/LGPL-2.0-or-later.txt` and is installed by
that package.

## Material Color Utilities

`native/third_party/material-color-utilities` is a scoped C++ subset used by
the dynamic-color implementation.

- Source: https://github.com/material-foundation/material-color-utilities
- License: Apache License 2.0
- Full text: `native/third_party/material-color-utilities/LICENSE`

## DankMaterialShell

The retained-content disclosure lifecycle in
`qml/MeoKDE/NotificationBodyDisclosure.qml` was adapted from the MIT-licensed
DankMaterialShell notification implementation and reimplemented for Plasma.

- Source: https://github.com/AvengeMedia/DankMaterialShell
- License: MIT (`assets/licenses/DankMaterialShell-MIT.txt`)
- Copyright 2025 Avenge Media LLC

## Fonts and symbols

- Roboto Regular, Medium, and Bold: SIL Open Font License 1.1; see
  `assets/fonts/OFL-Roboto.txt`. Source:
  https://github.com/googlefonts/roboto-classic
- Comfortaa Bold: SIL Open Font License 1.1, with Reserved Font Name
  "Comfortaa"; see `assets/fonts/OFL-Comfortaa.txt`. Source:
  https://github.com/googlefonts/comfortaa
- Material Symbols Rounded: Apache License 2.0; see
  `assets/licenses/Material-Symbols-Apache-2.0.txt`. Source:
  https://github.com/google/material-design-icons

## Papirus icon-theme source

`assets/icons/vendor/papirus-icon-theme` is a source input for the separately
packaged Meo icon theme and retains Papirus's GPL-3.0 license, copyright
notices, and AUTHORS file. It is not installed by the `meo-desktop` package.

- Source: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
- License: GPL-3.0-only (`assets/icons/vendor/papirus-icon-theme/LICENSE`)

## KDE Plasma 6 widget collection

`third_party/kde-plasma6-widgets` is a pinned Git submodule fork of MCC45TR's
KDE Plasma 6 Widget Collection. The submodule retains its own history and
GPL-3.0-only license and is not installed by the default `meo-desktop` package.

- Original upstream: https://github.com/MCC45TR/kde-plasma6-widgets
- Meo fork: https://github.com/QwQdoge/kde-plasma6-widgets
- Pinned commit: `ce3731be424f62f11ce96df5d989a2fbdc5d56d2`
- License: GPL-3.0-only
