# Applying Meo Desktop safely

The source installer is intentionally a Plasma 6 installer, not a generic
theme copier. It uses KDE's own Kickoff and active-window Global Menu, adds
separate Meo quick-settings and time/notification applets, and keeps the
Icons-Only Task Manager in the bottom Dock. KDE's standard System Tray stays
beside the Meo controls for application StatusNotifier icons; only duplicate
network, Bluetooth, audio, power, media and notification applets are omitted.

Run from this repository after validation:

```bash
MEOUI_PROJECT_ROOT=/home/shekong/Projects/meo-ui \
  setup/apply-meo-desktop.sh --apply --reset-layout --no-update-meoui
```

`--reset-layout` is the explicit one-step path that replaces an existing panel
arrangement with the layout shipped by the Look-and-Feel package. Plain
`--apply` selects the visual theme without rebuilding the user's panels. For an
older Meo layout or an explicitly edited `meo-shellrc`, run
`meo-desktop-layout` separately.

After installing the Arch package, the same application phase is available as:

```bash
meo-desktop-apply                 # preserve the current panels
meo-desktop-apply --reset-layout  # explicitly use the packaged layout
meo-desktop-apply --kwin-only     # resync decoration/effect values only
```

The source installer calls this exact helper after it has built and installed
the assets, so packaged and source installs do not maintain competing theme
application logic. `defaults/kwin/kwinrc` is the sole KWin profile authority;
the helper writes every section from that file explicitly because Plasma's
Look-and-Feel application only projects a subset of custom KWin groups into
`kdedefaults`. The `--kwin-only` repair path makes a backup and updates those
persistent values without applying the rest of the theme or restarting KWin.

Before writing any user file the script verifies the Plasma version, Kickoff,
Global Menu, System Tray, Icons-Only Task Manager, public Clock/Calendar/Notification
Manager QML modules and local build prerequisites. It builds MeoUI and MeoKDE
first, then creates a timestamped backup at
`~/.local/state/meo-desktop/backups/`. No root access, AUR installation,
network manipulation or compositor restart is performed.

After the KDE theme has been selected, `--apply` checks for an already running
Fcitx 5 or IBus session and selects the matching Meo candidate-panel
presentation. This ordering lets the IBus bridge resolve the newly active KDE
semantic color roles. It does
not start an input-method daemon, change engines, or alter the Plasma virtual
keyboard selection.

The layout has a top-left Meta launcher, the active window's native Global Menu
(for example File, Edit, View and Help), KDE's native application tray icons,
separate Meo quick-settings and time/notification controls, and a centered
56 px floating bottom Dock. The Dock uses Plasma's `autohide` mode:
it retracts when an application needs the edge and reappears on pointer reveal.
Configure pinned applications, grouping and preview behavior through the
standard task-manager widget configuration UI.

To inspect the actions without changing the desktop, run:

```bash
setup/apply-meo-desktop.sh --dry-run --no-update-meoui
```

For the editable single/dual panel profile and status-bar settings, see
[`shell-configuration.md`](shell-configuration.md).

To recover the latest backup:

```bash
setup/reset-meo-desktop.sh
```

KWin discovers the new native decoration on the next normal Plasma login; the
installer deliberately does not restart a live compositor.
