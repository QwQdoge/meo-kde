# MeoKDE widget platform

## Ownership

`third_party/kde-plasma6-widgets` is the GPL-3.0 upstream fork of
MCC45TR/kde-plasma6-widgets. It remains a Git submodule so its licence,
copyright notices, source history, and upstream relationship stay intact.
Run `git submodule update --init --recursive` after cloning MeoKDE.

Only the eight entries in `widgets/upstream/first-phase.json` are in phase one:
Weather, Calendar, Digital Clock, Music Player, Battery, Notes, System Monitor,
and Photos. Launcher and Control Center are MeoKDE-owned features and must not
be sourced from this fork.

## Visual and platform boundary

The existing `MeoUI 1.0` QML module is the one shared visual authority. It is
installed at `/usr/lib/qt6/qml/MeoUI` and widgets import it with:

```qml
import MeoUI 1.0
```

Do not create a second `Meo.UI` module or copy controls into plasmoids.
`MeoTheme`, `MeoCard`, `MeoIconButton`, `MeoText`, controls, state layers, and
motion remain owned by the sibling MeoUI repository. Its full semantic palette
and dynamic shape/spacing tokens are the public contract.

MeoKDE owns Plasma package metadata, the widget lifecycle, real KDE/DBus data
models, system capability checks, and the wallpaper-to-Material palette bridge.
Widgets consume resolved MeoUI roles; they do not run a second palette generator
or depend at runtime on a third-party wallpaper-color script.

## Adaptation gate

An upstream widget must be adapted in an MeoKDE-owned overlay before packaging:

1. Keep its data, lifecycle, and widget-specific interaction logic.
2. Import `MeoUI 1.0` and map all visual surface/text/state roles to `MeoTheme`.
3. Replace hard-coded colors and raw corner radii with `MeoCard`, `MeoShape`,
   MeoTheme shape tokens, and shared controls where applicable.
4. Route system data through one maintained MeoKDE model/API where a shared KDE
   capability is involved; never create fake local system toggles.
5. Add an offscreen visual case and preserve a live Plasma acceptance step.

The unadapted submodule is intentionally not copied into the Arch package.
GPL-3.0 notices and corresponding source must accompany every distributed
modified widget.
