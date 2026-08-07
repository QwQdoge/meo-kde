# Meo KDE development rules

- Keep generic controls and design tokens in `/home/shekong/Projects/meo-ui`.
- Keep Plasma-specific models, packages, layouts and defaults in this project.
- Consume named MeoUI and MeoKDE tokens; avoid raw colour literals in shell QML.
- Do not implement fake network, Bluetooth, brightness, power or audio state.
- Preserve a visible top status bar and a bottom Shelf at all supported sizes.
- Run `scripts/validate.sh` before syncing into the ISO workspace.
- Treat `meo-arch-os-workspace/meo-desktop` as a generated integration snapshot.

