# Meo Desktop architecture

The implementation order is KDE configuration, look-and-feel, Plasma style and
colors, panel layout, public plasmoids, KWin configuration, then custom code
only when a measured UX gap remains.

The current shelf uses upstream Kickoff, Icons-only Task Manager, System Tray,
and Digital Clock. NetworkManager, BlueZ, PipeWire, PowerDevil, notifications,
overview, and session power actions remain owned by KDE services. This avoids
forking stateful system backends.

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
