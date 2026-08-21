# Meo KDE

Meo KDE is the authoritative KDE Plasma 6 desktop integration for MeoArch.
It contains the top status bar, Plasma-native bottom Dock, launcher, Quick Settings,
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

To rebuild the dynamically imported Qt QML module, install the Meo status
center, native window decoration and desktop defaults, and apply the desktop,
run:

```bash
setup/apply-meo-desktop.sh --apply --reset-layout
```

The update is fast-forward only: the script refuses to overwrite local MeoUI
changes. Use `--no-update-meoui` when intentionally working offline or with a
local MeoUI edit. The module is installed under the user QML import path, so
MeoKDE components continue to resolve `import MeoUI 1.0` at runtime.

To install, apply, and rebuild the native KDE Plasma layout (including the
Kickoff Meta launcher in the top-left, MD3 time/calendar/notification center,
real quick settings, and the auto-hiding Icons-Only Task Manager Dock), run:

```bash
setup/apply-meo-desktop.sh --apply --reset-layout
```

`--reset-layout` backs up the existing Plasma configuration before replacing
the panel layout. The taskbar itself remains the built-in KDE Icons-Only Task
Manager, so Plasma retains its own task grouping, pinning, preview, window-menu
and per-widget configuration. The Meo-specific status surface imports MeoUI
and uses KDE's public Clock, Notification Manager and system-service APIs.

The resulting profile is editable at `~/.config/meo-shellrc`; see
[`docs/shell-configuration.md`](docs/shell-configuration.md) for the single or
dual panel choice, status text scale, network/Bluetooth/audio visibility,
battery detail and clock options.

The live apply script first verifies Plasma 6, its required first-party runtime
modules, and the maintained KDE-Rounded-Corners KWin effect, then builds all
native artifacts before touching user state and makes a timestamped backup.
On Arch, install a package providing `kwin-effect-rounded-corners` first (the
`-git` package provides it). The script never invokes an AUR helper, uses
`sudo`, or restarts KWin/Plasma; missing dependencies fail before any user
configuration is changed.

## Design contract

- MeoUI owns generic MD3 tokens and controls.
- MeoKDE maps the active Plasma palette/accent into MeoUI dynamic colour roles.
- Plasma/KWin remain the source of truth for windows, tasks, network, audio,
  power and session state.
- Compatible Fcitx 5 and IBus engines retain their real backends while their
  candidate windows can follow the active Meo/MD3 palette; see
  [`docs/input-method.md`](docs/input-method.md).
- Roboto is the UI family, Comfortaa is reserved for Meo branding, and Material
  Symbols Rounded is bundled for MeoUI icons.
- Missing system backends are hidden or delegated to upstream Plasma; the shell
  never presents a local fake toggle.
