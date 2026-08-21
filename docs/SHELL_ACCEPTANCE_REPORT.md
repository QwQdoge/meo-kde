# Meo KDE shell acceptance status

Date: 2026-08-02  
Status: **PARTIAL — VM interaction matrix pending**

The earlier report marked the shell PASS without retaining the screenshots,
runtime logs and interaction evidence beside the source. It also described
Wi-Fi, Bluetooth and power backends that were not implemented by the QML then
present. Those claims are not carried forward.

Verified in the current source tree:

- The layout contains a persistent top status bar and an auto-hiding Plasma
  Icons-Only Task Manager Dock.
- The Meo status package consumes MeoUI roles after `MeoShellTheme` passes the
  live KDE accent through the native HCT/CAM16 Material 3 role generator.
- The status center consumes real Plasma Clock, Calendar and Notification
  Manager models; it does not create local time or notification state.
- Power actions bind to KDE `SessionManagement` capability and request APIs.
- Audio binds to Plasma's preferred sink when that backend is available.
- Local fake Wi-Fi and Bluetooth booleans were removed.
- Roboto, Comfortaa and Material Symbols Rounded are packaged with the shell.

Still requiring VM/manual evidence:

- clean package installation and first Plasma login;
- Kickoff Meta invocation, task activation/minimisation/grouping, previews and
  window menus in the native task manager;
- top bar/system tray composition, status-center and quick-settings popup placement;
- session power confirmation flows;
- 1280x720 through 2560x1440 and 100% through 200% scaling;
- keyboard-only, screen-reader, reduced-motion, multi-monitor and fullscreen
  behaviour;
- comparison screenshots from the installed ISO.
