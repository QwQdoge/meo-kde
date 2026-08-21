# Quick Settings capability matrix

This matrix is maintained alongside implementation. “CLI reference” is an
acceptance oracle only; no production Meo.System path invokes it.

| Feature | Read / write backend | CLI reference | Hardware / service | Status | Limitation |
|---|---|---|---|---|---|
| Wi-Fi | KF6NetworkManagerQt | `nmcli radio wifi`, `nmcli dev wifi` | Wi-Fi present | IMPLEMENTED; hardware read verified | Forget, hotspot, VPN and WWAN pending controller split |
| Bluetooth | KF6BluezQt | `bluetoothctl` | BlueZ service, no usable adapter | IMPLEMENTED; hardware unavailable | Meo pairing agent pending |
| Output audio | PulseAudioQt | `wpctl`, `pactl` | Two output devices detected | IMPLEMENTED; read and model verified | Volume/mute work; changing the default output remains user-acceptance pending |
| Input audio | PulseAudioQt | `wpctl`, `pactl` | Two input devices detected | IMPLEMENTED; read and model verified | Volume/mute work; changing the default input remains user-acceptance pending |
| Battery | Solid / PowerDevil | `upower` | Primary battery present | IMPLEMENTED; read verified | Remaining time and aggregate state pending |
| Brightness | `org.kde.ScreenBrightness` D-Bus | `brightnessctl` | Two PowerDevil display objects | IMPLEMENTED; compiled; read smoke verified | Write path is compiled but deliberately hardware-unverified |
| Night Light | `org.kde.KWin.NightLight` D-Bus | KWin D-Bus inspection | KWin service present | IMPLEMENTED; compiled; read smoke verified | Write path is deliberately hardware-unverified |
| Power profiles | `org.freedesktop.UPower.PowerProfiles` D-Bus | `powerprofilesctl` | Service present; three profiles | IMPLEMENTED; compiled; runtime read verified | Switching is deliberately hardware-unverified |
| Keep Awake | `KSystemInhibitor` | screen-saver D-Bus inspection | KDE screen saver present | IMPLEMENTED; compiled | Lifecycle is owned by the controller and released on destruction |
| Lock | `org.freedesktop.ScreenSaver.Lock` D-Bus | `loginctl lock-session` | KDE screen saver present | IMPLEMENTED; compiled | Invocation is deliberately hardware-unverified |
| DND | Plasma NotificationManager `Server.inhibited` | notification inspection | Notifications service present | IMPLEMENTED; API and offscreen UI verified | Live enable/disable acceptance remains user-controlled |
| Notification center | Plasma NotificationManager model | Plasma notification applet | Notifications service present | IMPLEMENTED; model/API and offscreen UI verified | Default/first action, per-item close, clear closable items, settings and job percentage are covered; live notification interaction remains pending |
| MPRIS media | MPRIS2 D-Bus | `playerctl` | Registered player available | IMPLEMENTED; runtime read verified | Uses the active MPRIS player; player-specific queues remain upstream |
| Hotspot | NetworkManager D-Bus | `nmcli dev wifi hotspot` | Wi-Fi present | PENDING | AP-mode capability and existing-profile handling pending |
| VPN | NetworkManagerQt | `nmcli connection` | No profile detected yet | PENDING | Existing profiles only; no profile editor |
| WWAN | NetworkManagerQt / ModemManager | `nmcli radio wwan` | No modem detected | PENDING | Hidden without hardware |
| Airplane mode | NetworkManagerQt + BluezQt | `nmcli`, `bluetoothctl` | Wi-Fi present; BT unavailable | PENDING | Must preserve prior radio state |
| Keyboard backlight | PowerDevil brightness API if exposed | `brightnessctl` | Not yet detected | PENDING | No hardware-specific sysfs fallback |
| Touchpad | KWin API | input inspection | KWin service present | BLOCKED | Stable public toggle API not established |
| Appearance | existing full-system provider | theme tools | Meo theme bridge present | BLOCKED | No authoritative end-to-end provider has been found |
