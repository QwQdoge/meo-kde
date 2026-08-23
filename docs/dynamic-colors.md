# System dynamic colors

Meo uses one explicit seed source: the current KDE/Plasma accent, the current
local image wallpaper, or a manually selected color. It resolves that one seed
and passes it through the upstream [Material Color
Utilities](https://github.com/material-foundation/material-color-utilities)
HCT/CAM16 `SchemeTonalSpot` algorithm, then maps the resulting complete Material
3 roles to KDE's color-scheme groups. It does not manufacture containers,
surfaces, or content colors by mixing RGB/HSL values in QML.

The same native generator supplies both paths:

- `meo-dynamic-colors` writes a matching `MeoDynamicLight` or
  `MeoDynamicDark` KDE `.colors` file for Qt/KDE applications.
- `Meo.System.MaterialColors` supplies the complete Material role map to
  `MeoShellTheme`, so MeoUI shell controls use the exact same primary,
  container, surface, outline, error, and fixed-color roles.

The dynamic scheme follows Plasma's dark/light state. A wallpaper source reads
only the configured local `org.kde.image` desktop image, samples a bounded
128-pixel representation to select a seed, and then uses the same native HCT
generator as every other source. It never scans an image directory, downloads a
remote wallpaper, or derives final UI colors in QML. Slideshow, remote, and
non-image wallpaper plugins are surfaced as unavailable rather than silently
falling back to a different source.

The selected source is persisted in `~/.config/meo-dynamic-colorsrc`; the
active `kdeglobals` scheme records `MeoDynamicColorSource` alongside the seed so
MeoUI applications can truthfully report whether their shared role table came
from `accent`, `wallpaper`, or `manual`.

## Use

After installing Meo, generate and select the remembered source (KDE accent by
default):

```bash
meo-dynamic-colors --apply
```

Select and remember a source while applying it:

```bash
meo-dynamic-colors --source wallpaper --apply --remember-source
meo-dynamic-colors --source manual --accent '#4285F4' --apply --remember-source
meo-dynamic-colors --source accent --apply --remember-source
```

Generate a dark scheme or test a source without changing the user's current KDE
configuration:

```bash
meo-dynamic-colors --dark --source wallpaper --output-dir /tmp/meo-colors
meo-dynamic-colors --accent '#4285F4' --output-dir /tmp/meo-colors
```

The default Material contrast level is `0.0`. A deliberate accessibility
variant can be generated with `--contrast` from `-1.0` to `1.0`.

The installer copies, but does not enable, a user-level `.path` watcher. After
you have explicitly selected a source, opt in to regeneration when the
wallpaper, KDE accent, or source preference changes:

```bash
systemctl --user enable --now meo-dynamic-colors.path
```

The watcher never restarts Plasma, KWin, or applications. Existing processes
may pick up a KDE palette change on their normal configuration reload; a
running application's live repaint is desktop-session dependent and is not a
substitute for that application's own acceptance test.
