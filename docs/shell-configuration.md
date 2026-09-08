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
The helper also verifies the requested top-panel height after Plasma applies
it. If the active desktop theme clamps that value because its panel frame is
too large, it stops with an error instead of reporting a false success; deploy
the matching Meo desktop theme before trying again.

## Panels

```ini
[Panels]
# dual: top bar + separate auto-hidden bottom dock
# single: top bar only
Mode=dual
# KDE's native Icons-Only Task Manager is the sole Dock implementation.
DockImplementation=native
ShowSystemTray=true
# Active-window KDE global menu next to the launcher (File, Edit, View, Help).
ShowGlobalMenu=true
# Optional second task manager beside the menu; off because application tray
# icons already appear beside the Meo controls and the bottom Dock owns tasks.
ShowTopAppTasks=false
# Compact top bar; Plasma's panel frame supplies the remaining visual margin.
TopPanelHeight=32
# 80 dp Dock: 48 dp task targets with a 16 dp vertical glass margin.
DockHeight=80
```

- `Mode` is `dual` or `single`.
- `DockImplementation` is `native`. Version-3 profiles that still say
  `standalone` are migrated to the same native path. Plasma owns task identity,
  hover feedback, grouping, previews, drag-and-drop and window activation;
  Meo supplies the dynamic-color panel and task-frame appearance.
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
- `DockHeight` accepts `40`–`112` pixels. The 80 dp default leaves a calm
  Material margin around Plasma's native task targets. The panel theme owns
  the rounded dynamic-color capsule; no independent Dock window is started.
- Existing `~/.config/meo-shellrc` profiles are intentionally preserved. To
  opt an existing desktop into the 80 dp default, set `DockHeight=80` in that
  file and explicitly run the panel-layout helper above; normal theme updates
  never rebuild a user's live panels.

The top panel uses the generated dynamic `surfaceContainerLow` role while the
Meo window title bar uses `surfaceContainer`. This produces a subtle tonal
layer boundary instead of an opaque or wallpaper-sampled bar; both roles come
from the same wallpaper HCT scheme and remain consistent across native and
third-party applications. Quick-settings and time controls are transparent at
rest, gain a quiet `surfaceContainerHighest` hover surface, and use
`primaryContainer` only while their popup is open. Bluetooth appears in the
compact status group only while a device is connected, and the notification
glyph appears only when it has unread, job, or Do Not Disturb state to convey.
The controls return through the interruptible M3 Expressive spring when
released. The panel remains a 32 dp translucent surface on the empty desktop.
A per-output attachment
transition that makes the panel opaque at a window join is not yet a runtime
signal; it must be added through a KWin state bridge and must ignore fullscreen,
dialogs, popups, non-active windows, and windows on other outputs.

## Window motion

MeoArch uses KWin's upstream Scale effect for open/close motion and its upstream
Squash effect for minimize/restore. The default open path is a restrained
`0.94` to `1.0` scale plus opacity over 180 ms; close uses `1.0` to `0.98`.
Glide and Magic Lamp remain disabled so multiple exclusive effects cannot fight
for the same window. Interactive rebound belongs to Plasma's Dock and Meo panel controls,
not to whole windows, and every path still follows KDE's global animation
duration/reduced-motion preference.

The visual layering and quiet-at-rest interaction were compared against DankMaterialShell commit
`b9365610c89016279d3b06f0be18c9a1bd6927ad` (MIT): Meo reuses the general
Material pattern of dynamic surface-container levels, active tonal capsules,
and edge-aware elevation, but retains Plasma/KWin models and independently
implemented MeoUI controls. KWin 6.7.4's GPL upstream effects remain the actual
window-animation implementation; no DMS or third-party KWin code is vendored.

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
`org.meo.settings.desktop`; it does not switch to another settings shell when
a Meo desktop entry is missing. A packaged Meo desktop must therefore install
Meo Settings as part of the same supported experience.

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
open `org.meo.settings.bluetooth.desktop`, which launches **Meo Settings**
directly on its Bluetooth route. The generic Meo Settings entry remains only
as a compatibility handoff for an incomplete desktop-entry update; it does
not switch to another settings shell.

The installed Meo desktop must provide both Settings desktop entries alongside
the top bar, either in the same package or through a declared dependency.
Specialized platform tools remain available only from the explicitly labelled
Advanced compatibility pages inside Meo Settings.
