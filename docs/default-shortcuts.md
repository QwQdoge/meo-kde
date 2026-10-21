# Meo Desktop default shortcuts

New Meo sessions seed `kglobalshortcutsrc` from the desktop package without
replacing an existing user's choices. The default layout registers popup
shortcuts through Plasma's widget API. Explicit layout reconciliation also
applies those bindings; it does not rebuild the Shelf's task model.

| Shortcut | Owner and action |
| --- | --- |
| Meta | Plasma's Activate Application Launcher action finds `org.meo.shelf` through its `org.kde.plasma.launchermenu` capability. |
| Meta+E | KGlobalAccel launches Dolphin. |
| Meta+I | KGlobalAccel launches the package-owned Meo Settings desktop entry. |
| Meta+L | The existing session-lock action retains session authentication ownership. |
| Meta+A | Activate the Meo Quick Settings applet. |
| Meta+N | Activate the combined Meo notifications-and-clock applet. |

The default KWin Night Color shortcut is unset to avoid competing for Meta+N.
Night Color remains available in Settings. The launcher widget has no separate
Meta binding because Plasma already owns that action.

The top-panel creation order is system menu, application menu, expanding
spacer, native tray, Quick Settings, then the combined notifications-and-clock
applet at the far right. The bottom Shelf remains full width with centered launcher/tasks.

`meo-settings` installs its Settings desktop entry to `share/kglobalaccel` as
well as `share/applications`. The authoritative release recipe in `meo-repo`
consumes the owning repositories' sources and seeds the session defaults.
Source changes take effect in distributed installations only after new component
packages and the corresponding ISO have passed their release checks.
