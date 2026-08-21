# Meo Desktop architecture

The implementation order is MeoUI tokens and reusable controls, the Meo KDE
Look-and-Feel and Plasma style, public KDE models, then platform-specific code
only when a measured UX gap remains. The Look-and-Feel package is the canonical
source for a new Plasma layout and all KDE-expressible visual defaults.

`setup/apply-meo-desktop.sh` installs and selects that package. It does not
carry a second copy of the panel design. Its direct configuration is limited to
activation boundaries that Plasma Look-and-Feel cannot reliably own: loading
the installed KWin decoration/rounding effect, selecting the already-active
Fcitx or IBus presentation, and narrow migration/shortcut repair. The separate
`meo-desktop-layout` command exists only to reconcile an older layout or apply
an explicitly edited `meo-shellrc` profile.

The top-left launcher is upstream Kickoff, which retains Plasma's canonical
Meta action and search providers. It is followed by KDE's upstream active-window
Global Menu, so File, Edit, View and Help belong to their active application,
then the upstream System Tray for application StatusNotifier icons. The MeoUI
quick-settings and time surfaces remain independent on the right.
The bottom Dock is upstream Icons-Only Task Manager in Plasma's own auto-hide
mode, retaining its native pinning, grouping, previews and window menu. The
Meo top bar keeps two distinct MD3 status surfaces: time/calendar/notifications
and quick settings. The former uses the public Plasma Clock, Calendar and
Notification Manager modules; the latter binds NetworkManagerQt, BluezQt,
PulseAudioQt, Solid, PowerDevil/KWin D-Bus and KDE session APIs. NetworkManager,
BlueZ, PipeWire, PowerDevil, notifications, overview and the session lifecycle
remain owned by KDE services. Third-party System Tray items remain upstream
Plasma content when enabled.

`MeoMonthCalendar` and `MeoStatusCenter` are generic MeoUI controls. Plasma
models are injected by MeoKDE, keeping desktop-only APIs out of the shared
design system while retaining shared MD3 surfaces, state layers, shape and
typography tokens.

MeoUI is built as `libmeoui.so.0` plus the `MeoUI` QML plugin. The installer
loads it from the QML import path and does not statically embed the component
library. Archiso stages the versioned library and plugin under `/usr/lib`.

OmniStore owns optional application discovery and package actions after the OS
base is installed. The installer may produce a user-approved provisioning
manifest, but it must not claim OmniStore is installed until a signed,
repository-resolvable package is available in the image build.

During installation, `apply-target-customizations.sh` copies the Plasma package
and XDG defaults into the mounted target and stores the allowlisted OmniStore
intent at `/var/lib/omnistore/provisioning.json`. It deliberately creates no
autostart entry while the OmniStore executable is absent.
