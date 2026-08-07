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

