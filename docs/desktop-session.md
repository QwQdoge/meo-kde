# Meo Desktop Wayland session

The `meo-desktop` package installs a product-facing `Meo Desktop` session beside the upstream `Plasma (Wayland)` entry in `/usr/share/wayland-sessions/`. Display managers that read the standard Wayland session directory, including Plasma Login Manager, can offer both choices without replacing or renaming the upstream Plasma session.

`Meo Desktop` is the user-visible product name for the MeoArch desktop profile. The repository remains `meo-kde` because it owns KDE/Plasma integration, but the login/session chooser should present the desktop as a Meo product rather than as a KDE theme or a second copy of Plasma.

Both entries currently start the same Plasma 6 Wayland runtime and use KWin as the compositor/window manager. `Meo Desktop` does not claim to provide a separate compositor, window manager, or isolated Plasma configuration. Its distinction is the MeoArch product layer applied on top of the shared KDE/Plasma platform: Meo shell surfaces, MeoUI/MeoStyle presentation, Meo defaults, session integration and other maintained Meo desktop components.

The intended login-screen presentation is conceptually:

```text
Meo Desktop
  The default MeoArch experience

Plasma (Wayland)
  Upstream KDE Plasma desktop
```

The exact subtitle rendering depends on the login manager; the stable session names are `Meo Desktop` and the upstream `Plasma (Wayland)` entry.

The package must keep the upstream Plasma entry available as a compatibility/recovery fallback. Installing or upgrading `meo-desktop` must not delete, rename or overwrite the upstream Plasma session.

The package also must not silently change the display manager's default session or the currently running session. A future MeoArch installer or first-boot flow may explicitly select `Meo Desktop` as the recommended/default session for a MeoArch installation, but that policy belongs to the installer/login-manager integration and must remain reversible.

After installing or upgrading `meo-desktop`, sign out normally and choose `Meo Desktop` in the login screen's session selector. Keep `Plasma (Wayland)` available for upstream comparison and recovery.

## Two install modes

**Added to an existing Arch/KDE system** (`pacman -S meo-desktop`). The package only adds the `Meo Desktop` entry and its private session profile (`~/.config/meo-desktop`, seeded from `/usr/share/meo-desktop/session-defaults`). It leaves the user's Plasma configuration, the display manager and the default session alone. This is the mode described above.

**Installed from the MeoArch Live ISO.** The installer owns the whole system, so it selects `Meo Desktop` as the default session and installs the same signed `meo-*` packages with the version generation recorded in `/usr/share/meo-release/package-catalog.json`. It must not add a second, differently configured desktop on top: the installed system uses the same `meo.desktop` entry and the same private session profile as the add-on mode. The upstream `Plasma (Wayland)` entry stays installed as a recovery fallback.

There is exactly one session entry named `Meo Desktop` (`data/wayland-sessions/meo.desktop`). A second entry that runs plain `startplasma-wayland` under the same name would share the ordinary Plasma configuration and appear twice in the login screen; `tests/shell/test_meoarch_wayland_session.py` guards against it.

## Runtime identity

`startplasma-wayland` unconditionally sets `XDG_CURRENT_DESKTOP=KDE` (`setupPlasmaEnvironment()`), after the display manager has applied `DesktopNames` and after `plasma-workspace/env/*.sh` scripts have run. `DesktopNames=KDE;Meo` therefore only affects the pre-Plasma environment; applications inside the session still see `KDE`. What actually distinguishes the Meo session is `MEO_DESKTOP_SESSION=1`, `PLASMA_DEFAULT_SHELL=org.meo.shell` and the private `XDG_CONFIG_HOME`/`XDG_STATE_HOME`. Making `XDG_CURRENT_DESKTOP` read `Meo:KDE` needs a session-scoped user unit that runs after startplasma's environment import and is conditioned on `MEO_DESKTOP_SESSION=1`; it has to be verified in a real session before it is added.
