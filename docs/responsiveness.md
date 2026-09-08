# Meo Responsiveness Layer

Meo Desktop combines bounded foreground priority, compressed swap, request-
driven power boosts, and immediate visual acknowledgement. It deliberately
does not enable an alternative kernel scheduler, realtime KWin, permanent
performance mode, GPU overclocking, automatic process freezing, or broad
memory locking.

## Default services

- `system76-scheduler` is enabled. The TaskManager-backed Meo Dock forwards
  the active application PID to `com.system76.Scheduler.SetForegroundProcess`.
- `cachyos-ananicy.kdl` is generated from CachyOS Ananicy process names and
  coarse application classes. It is read directly by System76 Scheduler;
  `ananicy-cpp.service` is disabled and is not a package dependency.
- `zram-generator` creates up to half of RAM, capped at 8 GiB, with priority
  100. `/etc/systemd/zram-generator.conf.d/` remains the administrator override.
- `dbus-broker-units` selects dbus-broker for the system and user buses.
- `power-profiles-daemon` is enabled. Meo Dock uses an asynchronous,
  automatically released `HoldProfile("performance", ...)` only while a new
  application is starting; it never changes the persistent active profile.
- GameMode remains request-driven. Its Meo configuration uses the power-
  profile API and disables GPU and realtime changes.

## Optional memory helpers

Preload-NG and prelockd are optional package suggestions and remain disabled;
their Meo integration profiles are shipped with the desktop. The profiles are deliberately bounded:
one idle prefetch worker, no fanotify capability, and at most 160 MiB / 2% RAM
locked for KWin, Plasma, D-Bus and PipeWire. Enabling either is an explicit
advanced setting and needs device-specific memory-pressure acceptance.

## Instant Launch contract

Pointer-down changes Dock scale and starts the state-layer ripple immediately.
Launches finishing within 220 ms never show a loading surface. Slower launches
show a non-focusable, input-transparent surface at the last remembered window
bounds when the compositor accepts placement hints. The real task appearing
starts a 120 ms overlay fade; a 1.2 second deadline prevents stale content.
The accompanying performance hold has an independent 1.8 second safety limit.

Window placement and first-frame replacement remain compositor/runtime
behaviour. Builds and offscreen captures cannot prove them on a real Wayland
session.
