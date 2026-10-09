# Meo.System native input controls

`InputDevices` is an engine-owned Meo.System singleton for common KWin input
settings. It lists the actual input-device manager's `eventN` objects and their
reported capabilities. It never supplies fixture devices in production.

- `devices`: device id, name, touchpad status, actual property values and a
  closed capability map.
- `setValue(id, property, value)`: capability-checked boolean properties,
  pointer acceleration in `[-1, 1]`, or scroll factor in `[0.1, 10]`. Writes use
  KWin's DBus property owner and refresh after completion.
- `keyRepeat` / `configureKeyRepeat(mode, delay, rate)`: KWin-observed
  `kcminputrc/Keyboard` repeat mode, delay (100–5000 ms), and rate
  (0.2–200 per second). Accent mode requires the Plasma input module or an
  existing accent configuration. Immutable entries and unavailable Wayland
  input owners reject writes.
- Device enable/disable uses the reported `supportsDisableEvents` capability.
- `layoutChoices`: installed XKB layout/variant inventory.
- `configuredLayouts`: current `kxkbrc` layout and variant pairs.
- `keyboardLayouts` / `activeKeyboardLayout`: the runtime keyboard layout owner.
- `configureKeyboardLayouts(ids)`: one to four unique installed layouts; writes
  only the layout list, variants and activation flag with KConfig notification.
  Unrelated keyboard model/options remain intact.
- `activateKeyboardLayout(index)`: switches only an actual runtime layout.

Async replies are bounded and stale refresh generations cannot replace a newer
input-device or keyboard result. Opening a page reads state and does not modify
input configuration. No API accepts arbitrary DBus destinations or shell text.

`InputMethods` continues to use the typed Fcitx5 controller API. Its
`currentGroupLayout` reports the group's actual default keyboard layout.
`configureMethods(ids)` preserves that default and existing per-engine layout
overrides when adding, removing or reordering installed methods. It requires a
loaded group and at least one keyboard entry. The existing explicit
`applyCurrentGroup(ids, layouts, defaultLayout)` API remains available for
clients that intentionally edit layout overrides.

`Platform.nightLightEnabled` writes KWin's `NightColor/Active` configuration;
the DBus `enabled` property is read-only. `nightLightSettings` and
`configureNightLight(mode, dayTemperature, nightTemperature)` are available only
when the installed schema defines `Constant` and `DarkLight`. They preserve the
schema's named enum values and reject unsupported temperature/mode requests.
Older Night Light enum values are not interpreted as the new schema.

Build and offscreen loading verify the client interface only. Actual KWin,
Fcitx and hardware behavior needs real-session acceptance.

`Platform.screenLockPolicy` exposes the real screen-lock service and its
`kscreenlockerrc/Daemon` policy. `configureScreenLock` changes automatic locking,
idle minutes, resume/start locking and authentication grace seconds only. It
notifies the owner via its public `configure` method and restores the previous
configuration if saving or owner confirmation fails. It never writes PAM,
`RequirePassword`, or `Lock` authentication policy. Runtime recovery still
depends on the screen-lock service responding.
