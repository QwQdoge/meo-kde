# Meo KDE architecture (discovered and migrated)

## Source map

```text
Plasma palette / wallpaper accent
             |
             v
qml/MeoKDE/MeoShellTheme.qml -----> MeoUI dynamic colour roles
             |                               |
             +-------------------------------+
                             |
        +--------------------+--------------------+
        v                                         v
org.meo.topbar                              org.meo.shelf
  Quick Settings                              Launcher
  KDE sessions                                Kicker search/apps
  Plasma audio                                TasksModel
        |                                         |
        +--------------------+--------------------+
                             v
             org.meo.desktop Look-and-Feel
                             |
             defaults + fonts + wallpaper
                             |
             Arch package / ISO sync snapshot
```

`meo-ui` is a separate generic QML library. `meo-kde` is Plasma-specific. The
ISO workspace holds a synchronized snapshot rather than a cross-repository
symlink so that isolated ArchISO builds remain reproducible.

## Current boundaries

- KDE owns windows, tasks, KRunner/Kicker, network, Bluetooth, audio, power and
  the session lifecycle.
- MeoUI owns reusable MD3 controls and role tokens.
- MeoKDE owns shell composition, adaptive palette mapping, desktop density,
  defaults, font deployment and Plasma packaging.
- OmniStore is not a shell backend and remains outside this repository.

## Removed duplication

The migrated package installs only `org.meo.shelf` and `org.meo.topbar`.
Standalone `org.meo.launcher` duplicated the Shelf launcher, while
`org.meo.quicksettings` contained metadata without an implementation. They are
excluded from the authoritative project.

