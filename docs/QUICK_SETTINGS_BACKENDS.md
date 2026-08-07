# Quick Settings backend contract

| Surface | Source of truth | Current action | Fallback |
|---|---|---|---|
| Volume/mute | `org.kde.plasma.private.volume` preferred sink | set sink volume/mute | row hidden without a sink |
| Suspend | KDE `SessionManagement.canSuspend` | `suspend()` | menu item hidden |
| Restart | KDE `SessionManagement.canReboot` | `requestReboot(ForcePrompt)` | menu item hidden |
| Shutdown | KDE `SessionManagement.canShutdown` | `requestShutdown(ForcePrompt)` | menu item hidden |
| Sign out | KDE `SessionManagement.canLogout` | `requestLogout(ForcePrompt)` | menu item hidden |
| Network | Plasma System Tray / NetworkManager | delegated to upstream widget | no fake state |
| Bluetooth | Plasma System Tray / BlueZ | delegated to upstream widget | no fake state |
| Brightness | Plasma battery/brightness widget / PowerDevil | delegated until a tested public integration is added | no fake state |

The shell does not infer hardware availability and never toggles a local boolean
as if it were system state.

