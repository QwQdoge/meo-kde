# MeoArch Wayland session

The `meo-desktop` package installs `MeoArch (Wayland)` beside the upstream
`Plasma (Wayland)` entry in `/usr/share/wayland-sessions/`. Display managers
that read the standard Wayland session directory, including Plasma Login
Manager, can offer it as a session choice.

Both entries start the same Plasma 6 Wayland session runtime. The MeoArch
entry provides a product-named choice for the desktop profile supplied by
`meo-desktop`; it does not create a separate compositor or isolate Plasma
configuration. The package does not change the display manager's default
session or the currently running session.

After installing or upgrading `meo-desktop`, sign out normally and choose
`MeoArch (Wayland)` in the login screen's session selector. Keep
`Plasma (Wayland)` available as the upstream fallback.
