# MeoArch session lock

## Authority

Meo Desktop locks the session through Plasma's **KScreenLocker**. The Meo
presentation is the `org.meo.desktop` Look-and-Feel lock-screen package
(`themes/look-and-feel/org.meo.desktop/contents/lockscreen/`), exposed to the
session through the `org.meo.shell` shell adapter
(`themes/shells/org.meo.shell/contents/lockscreen/LockScreen.qml`).

KScreenLocker owns the secure per-screen windows, the Wayland session-lock
handshake, input routing and PAM authentication. Meo supplies presentation only.
Do not replace PAM with a QML password comparison, and do not add a second lock
owner or resident lock process.

`native/lockscreen/` provides the `Meo.KScreenLocker` QML module
(`ScreenCoordinator`), which decides which existing lock window presents the
authentication surface on multi-monitor setups. It never stores or compares
credentials.

The previous Quickshell/Hyprland `meo-lockscreen` implementation was removed.
`PLASMA_DEFAULT_SHELL=org.meo.shell` (set by `tools/session/startmeo-wayland`)
makes Plasma load this package and fall back to the stock Plasma lock screen if
the Meo package fails to load.

## Visual contract

The lock surface follows the Googlebook reference and MeoUI:

- the wallpaper stays visible and prominent;
- hours and minutes are stacked vertically in a light, large display face, with
  a small date line beneath;
- the default ambient view has no dashboard or cards; a lock glyph and an unlock
  hint sit at the bottom;
- the authentication area appears only on intentional input (key press, click);
- colors, typography and motion come from MeoUI/`MeoTheme` semantic roles, never
  local literals;
- reduced motion collapses the transitions through `MeoTheme.reduceMotion`.

## Authentication protocol (Plasma 6.8 backend)

- Authentication starts only on a deliberate action on the ambient surface: a key
  press, a click/tap, or an upward swipe (72dp). The first call is
  `authenticator.startAuthenticating()`.
- While the authentication surface is visible a 1 s heartbeat repeats
  `startAuthenticating()` (the stock 6.8 lock screen does the same). The backend
  ignores the call while its PAM worker is not ready or is busy; without the
  heartbeat a typed password or a fingerprint touch can arrive with no PAM
  conversation to answer.
- `respond(password)` only answers a pending PAM prompt; the fingerprint reader runs
  as the implicit non-interactive authenticator beside the password prompt.
- On success the UI calls `stopAuthenticating()` and quits (unlocks). An account
  without a password succeeds without any prompt, so one click or key press goes
  straight to the desktop; there is no second confirmation screen.

## Authentication boundary

Authentication success comes from the backend authenticator. Presentation may
animate after success; an animation never causes success, and the desktop is
not exposed before KScreenLocker releases the lock.

The Meo Login Manager greeter is a separate boundary. It shares the visual
language and the session-entry schema but never shares transient credential
state with the lock screen.

## Validation

- `python -m unittest discover -s tests/authentication -p 'test_*.py'` covers
  the presentation/source contracts and headless QML instantiation.
- Real lock/unlock, wrong-password handling, multi-monitor, suspend/resume and
  DPMS behaviour require a real Plasma/KWin session or VM. Source checks and
  offscreen QML do not prove them.
