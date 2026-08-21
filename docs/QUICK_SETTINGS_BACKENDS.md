# Quick Settings backend contract

| Surface | Source of truth | Current action | Fallback |
|---|---|---|---|
| Volume/mute and routing | PulseAudioQt sinks and sources | set output/input volume, mute and default device | an explanatory empty state links to Sound Settings when unavailable |
| Suspend | KDE `SessionManagement.canSuspend` | `suspend()` | menu item hidden |
| Restart | KDE `SessionManagement.canReboot` | `requestReboot(ForcePrompt)` | menu item hidden |
| Shutdown | KDE `SessionManagement.canShutdown` | `requestShutdown(ForcePrompt)` | menu item hidden |
| Sign out | KDE `SessionManagement.canLogout` | `requestLogout(ForcePrompt)` | menu item hidden |
| Network | NetworkManagerQt / NetworkManager D-Bus | scan, list networks, activate saved profiles, connect ordinary open/PSK/SAE/OWE networks, disconnect | EAP, WEP, certificates and other advanced flows remain in System Settings |
| Bluetooth | BluezQt / BlueZ | power, discovery, list, pair/connect/disconnect and forget | PIN/passkey confirmation remains with the registered system BlueZ agent |
| Brightness | `org.kde.ScreenBrightness` / PowerDevil | set the real brightness of each reported display | section hidden when PowerDevil reports no display |
| Notifications | Plasma NotificationManager | DND, unread/history state, source and relative time, urgency treatment, all advertised actions, per-app configuration, dismiss/clear, and background-job progress/pause/resume/cancel | no local notification store, fake unread count, or synthetic job state |

The shell does not infer hardware availability and never toggles a local boolean
as if it were system state. Network and Bluetooth operations are asynchronous;
each reports real completion/error state and has an independent busy state.
