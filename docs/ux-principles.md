# UX principles and acceptance

The primary launch workflow is Meta, type, Enter. The alternative is opening
the launcher and selecting an application. The shelf must visibly distinguish
pinned, running, active, and minimized applications through Plasma's task
manager states.

Quick Settings exposes everyday Wi-Fi, Bluetooth, volume, battery and power
state through the Meo top bar while retaining KDE's system services as the
source of truth. Advanced network, Bluetooth, audio and display controls stay
in System Settings. Destructive actions stay in KDE's session UI and require
explicit labels and confirmation.

Every custom MeoUI surface must define loading, empty, offline, failure,
permission-denied, unavailable-service, and no-result states. Tab,
Shift+Tab, arrows, Enter, Escape, Meta, and Alt+Tab are acceptance inputs.

Development never writes to an active user's configuration without a backup.
Use disposable XDG directories, a test user, or a VM, and begin with
`setup/apply-meo-desktop.sh --dry-run`.
