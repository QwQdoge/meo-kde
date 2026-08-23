# Meo shell configuration

The packaged default layout is owned by the `org.meo.desktop` Look-and-Feel
package. `~/.config/meo-shellrc` is an optional reconciliation profile for an
older layout or for repeatable user customization; it is not a second default
theme. `setup/apply-meo-desktop.sh --apply` creates it on first install without
overwriting an existing profile.

After changing the profile, apply it without restarting Plasma:

```bash
/home/shekong/Projects/meo-kde/tools/shell/apply-meo-panel-layout.sh
```

This command is deliberately separate from ordinary theme application. It
changes only the Meo-managed panels, keeps unrelated panels
untouched, keeps exactly one Meo quick-settings applet and one Meo
time/notification applet, and keeps one native System Tray unless it is
explicitly disabled below. Existing tray visibility choices are preserved;
only controls already owned by Meo are removed from its requested compact items.

## Panels

```ini
[Panels]
# dual: top bar + separate auto-hidden bottom dock
# single: top bar only
Mode=dual
ShowSystemTray=true
# Active-window KDE global menu next to the launcher (File, Edit, View, Help).
ShowGlobalMenu=true
# Optional second task manager beside the menu; off because application tray
# icons already appear beside the Meo controls and the Dock owns window tasks.
ShowTopAppTasks=false
TopPanelHeight=40
DockHeight=56
```

- `Mode` is `dual` or `single`.
- `ShowSystemTray` is `true` or `false`. The default is `true` so native
  StatusNotifier application icons, input-method state, clipboard and other
  KDE tray integrations remain available. Meo-owned network, Bluetooth,
  audio, power, media and notification applets are filtered to avoid duplicates.
- `ShowGlobalMenu` is `true` or `false`. It shows the active application's
  native KDE global menu beside the top-left launcher (for example **File**,
  **Edit**, **View**, and **Help**). This is separate from the bottom Dock.
- `ShowTopAppTasks` is `true` or `false`. Its default is `false`; enabling it
  adds a second KDE Icons-Only Task Manager beside the Global Menu. The bottom
  Dock remains the primary task manager for pinned launchers, window actions
  and autohide behavior.
- `TopPanelHeight` accepts `32`–`96` pixels.
- `DockHeight` accepts `40`–`112` pixels. The compact default is `56` pixels.
  In `dual` mode the dock remains the native Plasma
  Icons-Only Task Manager, stays on one row, and is auto-hidden.

## Status bar

```ini
[StatusBar]
TextScalePercent=100
ShowNetwork=true
ShowBluetooth=true
ShowVolume=true
# 0 hidden, 1 icon, 2 icon and percentage, 3 detailed state
BatteryDisplay=2
ShowDate=true
ShowNotifications=true
Use24HourClock=true
```

- `TextScalePercent` accepts `75`–`150` and scales Meo status text only.
- The `Show*` entries use `true` or `false`.
- `BatteryDisplay=3` displays the full readable battery state; `2` shows an
  icon plus percentage; `1` shows only the icon; `0` hides it.
- `Use24HourClock=false` enables a local 12-hour clock.

The quick-settings and time/notification applets have separate **Configure**
dialogs. The profile remains preferable when making repeatable or packaged
deployments.

## Control Center

The Quick Settings gear opens **Meo Settings** through the desktop ID
`org.meo.settings.desktop`; it does not use KDE System Settings as the normal
Meo entry point. If the desktop entry cannot be opened, the applet falls back
to `systemsettings:` rather than assuming a `meo-settings` binary is present.

For a packaged Meo desktop, the package that installs `org.meo.topbar` must
also require the package that installs `meo-settings` and
`/usr/share/applications/org.meo.settings.desktop`. The Settings **Control
Center** page edits the unique active `org.meo.topbar` applet through Plasma
Shell. It persists the applet's `Appearance/quickTileOrder`,
`quickTileSizes`, `quickTileVisibility`, and `quickTileDensity` values, then
reloads that exact applet. It never guesses an applet ID or rewrites Plasma's
configuration file directly.

`quickTileVisibility` defaults to every supported tile, so upgrading preserves
the current surface. `quickTileDensity` accepts `compact`, `comfortable`, or
`spacious`; it affects only the Meo Quick Settings tile presentation.

## Bluetooth from Quick Settings

The Quick Settings Bluetooth tile is the fast path for turning the adapter on
or off, discovery, connecting or disconnecting an already paired device, and
forgetting a paired device. Those actions stay bound to the live BlueZ-backed
Meo system model; opening the full settings page does not substitute a fake
Bluetooth state.

Pairing is intentionally not initiated by tapping an unpaired device in the
compact popup. PIN, passkey, numeric-comparison, and authorization prompts
need the full Bluetooth flow. The row and the Bluetooth page’s settings button
open `org.meo.settings.bluetooth.desktop` first, which launches **Meo
Settings** directly on its Bluetooth route. If that dedicated launcher is not
available, the top bar tries the normal `org.meo.settings.desktop` launcher;
only if neither Meo Settings launcher can open does it fall back to
`systemsettings:kcm_bluetooth`.

The installed Meo desktop must provide both Settings desktop entries alongside
the top bar, either in the same package or through a declared dependency. This
fallback order is intentional: KDE System Settings is a recovery path for an
incomplete installation, not the normal Bluetooth management surface.
