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
