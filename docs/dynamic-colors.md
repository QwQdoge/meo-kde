# System dynamic colors

Meo uses the active KDE/Plasma accent as its single color seed. It passes that
seed through the upstream [Material Color Utilities](https://github.com/material-foundation/material-color-utilities)
HCT/CAM16 `SchemeTonalSpot` algorithm, then maps the resulting Material 3 roles
to KDE's color-scheme groups. It does not manufacture containers, surfaces, or
content colors by mixing RGB/HSL values in QML.

The same native generator supplies both paths:

- `meo-dynamic-colors` writes a matching `MeoDynamicLight` or
  `MeoDynamicDark` KDE `.colors` file for Qt/KDE applications.
- `Meo.System.MaterialColors` supplies the complete Material role map to
  `MeoShellTheme`, so MeoUI shell controls use the exact same primary,
  container, surface, outline, error, and fixed-color roles.

The dynamic scheme follows Plasma's dark/light state. KDE remains responsible
for determining or syncing its accent from a wallpaper; Meo consumes that
already-selected KDE color instead of implementing a competing wallpaper
extractor.

## Use

After installing Meo, generate and select the current mode's scheme:

```bash
meo-dynamic-colors --apply
```

Generate a dark scheme or test a seed without changing the user's current KDE
configuration:

```bash
meo-dynamic-colors --dark --apply
meo-dynamic-colors --accent '#4285F4' --output-dir /tmp/meo-colors
```

The default Material contrast level is `0.0`. A deliberate accessibility
variant can be generated with `--contrast` from `-1.0` to `1.0`.

The installer copies, but does not enable, a user-level `.path` watcher. Opt in
to regeneration when Plasma's wallpaper or global accent configuration changes:

```bash
systemctl --user enable --now meo-dynamic-colors.path
```

The watcher never restarts Plasma, KWin, or applications. Existing processes
may pick up a KDE palette change on their normal configuration reload; a
running application's live repaint is desktop-session dependent and is not a
substitute for that application's own acceptance test.
