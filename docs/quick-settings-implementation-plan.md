# Quick Settings implementation plan

Status: reviewed on 2026-08-14. This document is the implementation boundary
for the Meo top-bar Quick Settings work.

## Reviewed input

The candidate bundle is kept outside the repository at
`/home/shekong/Downloads/meo-quicksettings-implementation.zip`.

- SHA-256: `651582904cefdf1189b4957b8323292df824b8127a58fa3865567ebea62e7531`
- The archive was integrity-checked with `unzip -tqq`.
- It is a reviewed input, not a second source tree. Its files are merged
  selectively into the authoritative repository paths below.

## Architecture decision

`SystemStateHub` remains the `Meo.System` QML facade for this first delivery.
It owns no simulated state: NetworkManagerQt, BluezQt, PulseAudioQt, Solid,
and KDE SessionManagement remain the respective sources of truth. Splitting
the facade into controllers is deferred until its public QML API is stable;
doing so now would increase lifetime and signal-regression risk without
improving user-facing behavior.

Each asynchronous subsystem has its own busy state. A Wi-Fi operation must not
disable Bluetooth controls, and vice versa. Errors are surfaced in the active
Quick Settings page and must never include connection secrets.

## File map

```text
native/system/
  systemstatehub.*                    Real state, async operations, QML facade
plasmoids/org.meo.topbar/contents/ui/
  main.qml                            Top-bar composition
  QuickSettingsCenter.qml             Popup, power menu and page navigation
  QuickSettingsHome.qml               Compact home surface
  WifiPage.qml                        Wi-Fi detail surface
  WifiPasswordDialog.qml              Password entry only; no secret storage
  BluetoothPage.qml                   Bluetooth detail surface
  AudioPage.qml                       Output/input volume and default-device selection
  PowerPage.qml                       Power profiles, keep-awake and lock actions
  components/
    QuickSettingTile.qml              Shell-specific compound toggle/details tile
    SystemStatusCluster.qml           Unified top-bar trigger
```

Generic typography, icon, button, switch, slider, list, loading, state-layer,
and text-field behavior belongs to `MeoUI 1.0`, not to this package.

## Scope and non-goals

This delivery implements real Wi-Fi scanning, visible network state, saved
profile activation, ordinary open/PSK/SAE/OWE connection flows, Bluetooth
discovery and device operations, volume/mute, battery state, brightness, night
light, power profiles, keep-awake, screen locking, MPRIS playback and KDE
session power actions, microphone controls, audio output/input selection and
Plasma NotificationManager Do Not Disturb. The native surfaces explicitly do
not claim support for EAP, WEP, certificate workflows, a custom BlueZ pairing
agent, hotspot, VPN profile editing or WWAN. Those remain in upstream
Plasma/System Settings until a stable public interface is available.

The native Plasma System Tray remains present. The explicit panel-profile
script places it before the two Meo applets, preserves StatusNotifier
applications, and hides only built-in controls duplicated by the two Meo
centers. Ordinary theme updates do not rebuild a live panel.

## Acceptance evidence

Repository evidence must include a clean native build, system-state smoke,
QML lint/runtime smoke, `scripts/validate.sh`, and `git diff --check`.
Hardware acceptance is separate: scanning is safe to test read-only, but
disconnecting the active network, pairing, forgetting devices, and disconnecting
input or audio devices require an explicit user-controlled test.
