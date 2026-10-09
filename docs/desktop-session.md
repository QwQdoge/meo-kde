# Independent Meo Desktop session

The source installer registers Meo Desktop alongside Plasma (Wayland). It
installs its namespaced resources under `/usr/share/meo-desktop/runtime`,
retains a per-user runtime at `~/.local/share/meo-desktop/runtime`, and adds
the login entry and launcher under `/usr`. It does not apply a theme, rebuild panels,
change shortcuts, import environment into a running session, replace KDE's
PolicyKit agent, or change the display manager/default login selection.

At login, `start-meo-desktop` selects its own `~/.config/meo-desktop` and
`~/.local/share/meo-desktop/data` directories and exposes its private QML,
plugins, themes and helpers. Normal KDE uses its existing directories. Meo
preferences and per-application data are separate; documents and installed
application launchers remain accessible. The system package uses
`/usr/share/meo-desktop/runtime` instead of the per-user runtime.

Meo starts the distribution's `startplasma-wayland`, Plasma Shell and KWin.
Arch's normal KDE upgrades update these binaries without a Meo compositor fork.
This is a separate desktop profile, not security isolation. Logging into both
as the same user simultaneously is unsupported because upstream Plasma uses
shared user systemd services. Select either desktop at the login screen.

`start-meo-desktop --preview` runs KWin and Plasma in a nested window with a
separate D-Bus session; it does not start the login startup or change the host
systemd environment. Close the window to end the preview. A preview demonstrates
the rendered desktop; it does not establish a successful login/ISO installation.

A fresh MeoArch OS installation preselects Meo Desktop in Plasma Login Manager.
The KDE packages are runtime dependencies; the installed desktop identity is
Meo Desktop. The upstream Plasma entry stays available for recovery.

The Arch source recipe and release recipe both call
`tools/session/package-meo-desktop` from the owning, pinned source tree. The
package advertises `meo-desktop-session=1`; ISO build and installer preflight
require this capability in the first selected signed repository before disk
preparation. An older repository stops installation rather than falling back
to global KDE defaults. This contract still requires a new signed package train
and an ISO-to-installed-boot acceptance run.

Dynamic colors and weather use transient user units created only by the Meo
session autostart. Their paths use the session's XDG homes and their lifetime
is bound to `graphical-session.target`. Fonts are also private through the
session's Fontconfig configuration. The normal Plasma session has no Meo
watchers enabled in its default target.
