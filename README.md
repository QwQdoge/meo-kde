# Meo KDE

Meo KDE is the authoritative KDE Plasma 6 desktop integration for MeoArch.
It contains the top status bar, bottom Shelf, launcher, Quick Settings,
look-and-feel package, MD3 adaptive colour bridge, bundled fonts and Arch
packaging. The generic component library remains in the separate `meo-ui`
project.

The copy under `meo-arch-os-workspace/meo-desktop` is an ISO integration
snapshot. Update it with:

```bash
scripts/sync-to-workspace.sh /home/shekong/Projects/meo-arch-os-workspace
```

Safe local validation:

```bash
scripts/validate.sh
setup/apply-meo-desktop.sh --dry-run
```

To fetch the latest clean `MeoUI` checkout, rebuild its dynamically imported
Qt QML module, install all Meo themes/window decoration/rounded-corners
settings, and apply the desktop, run:

```bash
setup/apply-meo-desktop.sh --apply --reset-layout
```

The update is fast-forward only: the script refuses to overwrite local MeoUI
changes. Use `--no-update-meoui` when intentionally working offline or with a
local MeoUI edit. The module is installed under the user QML import path, so
MeoKDE components continue to resolve `import MeoUI 1.0` at runtime.

To install, apply, and rebuild the native KDE Plasma panels (including the
wallpaper-derived Material 3 colors, Global Menu, Kickoff Meta launcher,
Icons-Only Task Manager, System Tray, and Digital Clock), run:

```bash
setup/apply-meo-desktop.sh --apply --reset-layout
```

`--reset-layout` backs up the existing Plasma configuration before replacing
the panel layout. It uses only built-in KDE widgets; Global Menu moves
supported application *menu bars* to the top panel, never arbitrary application
content such as a terminal's output area.

The live apply script makes a timestamped backup before changing the current
user. Prefer a disposable Plasma account or VM for interactive acceptance.

## Design contract

- MeoUI owns generic MD3 tokens and controls.
- MeoKDE maps the active Plasma palette/accent into MeoUI dynamic colour roles.
- Plasma/KWin remain the source of truth for windows, tasks, network, audio,
  power and session state.
- Roboto is the UI family, Comfortaa is reserved for Meo branding, and Material
  Symbols Rounded is bundled for MeoUI icons.
- Missing system backends are hidden or delegated to upstream Plasma; the shell
  never presents a local fake toggle.
