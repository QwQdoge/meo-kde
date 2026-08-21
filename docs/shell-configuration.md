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
