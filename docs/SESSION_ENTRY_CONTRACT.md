# Meo lock screen and login entry contract

## Scope and ownership

This document is the version-one presentation contract for the Meo session
entry surfaces.  `kscreenlocker` remains the logged-in lock screen's security
core: Meo supplies a Look-and-Feel `contents/lockscreen/LockScreen.qml` in P1,
not a replacement locker or authentication daemon.  The separate Meo Login
Manager fork preserves the upstream Plasma Login Manager PAM, daemon, D-Bus,
service and session-start interfaces.

MeoUI owns generic cards, clock/media/weather presentation, semantic dynamic
colors, motion and accessibility.  MeoKDE owns the KScreenLocker/Plasma,
KScreen, MPRIS and weather-cache adaptors.  Meo Settings owns the user-facing
editor, safe preview, reset and authorized system-login commit flow.  No
surface stores a password or emulates authentication state.

## Version-one configuration

`schemas/meo-session-entry-v1.schema.json` is the formal schema.  A document
has `schemaVersion: 1` and exactly one `scope`:

- `lockscreen` is per-user data, consumed only inside that user's already
  authenticated session.  It may reference a current-user wallpaper asset.
- `login` is system data, written only through the authorized Meo Settings
  transaction.  It cannot enable media, notifications, album artwork or a
  precise location, and may reference only a system default or managed asset.

The schema holds presentation preferences only: large/compact clock, date,
background treatment, `wallpaperMode`, media/weather/audio enablement, city
preference for the separate weather refresher, notification and content
privacy, output-specific wallpaper refs, active-authentication-screen policy
and Reduce Motion override. `wallpaperMode: follow-desktop` resolves only the
wallpaper that KScreenLocker already supplies for that secure output. Wallpaper references are symbolic asset IDs;
consumers resolve them through their trusted owner and do not accept arbitrary
QML, URLs or raw filesystem paths from the settings document.  Output keys are
opaque KScreen identities, never coordinates or raw EDID payloads.

Unknown properties, wrong schema versions, unresolved assets, invalid output
keys and invalid values fail closed to the safe defaults.  A parse failure does
not prevent a security surface from appearing or a user from authenticating.

## Defaults and privacy

The rich lock-screen profile defaults to `full-content` notifications, album
artwork, city-level cached weather, current-session media, and output
volume/mute. Privacy controls can independently reduce this to application
name, count, or hidden. Media remains asynchronous and time-bounded; all
external cards remain removable without affecting authentication. Login surfaces
never query a prior user's session, MPRIS player, notification store or private
weather settings.  Login weather, if enabled later, is city-granularity,
system-cache data only.

## State, displays and fallback

Each current screen receives a true full-screen security surface.  One logical
authentication state is shared through the existing KDE-owned locker/login
backend; a presentation coordinator may select an active screen but must not
make a second credential model.  `auto`, `fixed-primary` and
`follow-interaction` are the supported policies.  A selection change uses a
250 ms fade-through, while screen add/remove, DPMS recovery, sleep resume,
mixed scaling, rotation and negative geometry retain a covered surface on
every usable output.

The P2 lock-screen bridge is the `Meo.KScreenLocker` QML module's
`ScreenCoordinator`. It is instantiated inside KScreenLocker's already shared
QML engine and accepts only the per-output secure `QWindow` supplied by that
process. It observes Qt screen/topology changes, chooses among those existing
windows, and asks the selected one to activate. It persists no display
identity, never creates a security window, and exposes neither a credential
nor a PAM, D-Bus, or network API. Meo Settings may bind the validated layout
policy to this bridge only after its transaction/preview flow is implemented.

If the active screen vanishes, focus immediately moves to a remaining eligible
screen.  If the Meo lock screen cannot load, KScreenLocker falls back to the
configured KDE theme.  If a Meo data provider fails, its card hides; it never
blocks authentication.  The Login Manager follows the equivalent upstream
greeter fallback documented in its fork contract.

## P3 external-data projection

The lock screen creates the media card only when the user enables its module.
`Meo.System.Media` reads the current user's MPRIS services through asynchronous
D-Bus calls with a 750 ms deadline. It exposes only title, artist, playback
state, next/previous capability and the three safe controls. Remote artwork is
rejected; local artwork is accepted only when present and no larger than 5 MiB.
Album artwork remains opt-in independently of the media card.

`Meo.System.Weather` performs no network I/O. It reads the bounded (64 KiB)
`$XDG_STATE_HOME/meo/weather/lockscreen.json` cache written by a separately
authorized MeoKDE provider. The supported version-one cache contains only an
ISO timestamp, city-granularity location, temperature/unit, condition and an
icon name. Invalid, future-dated or older-than-six-hour data hides the widget;
the city name itself is opt-in.

`meo-weather-refresh` is a per-user, systemd-timer driven Open-Meteo client.
Meo Settings stores a bounded city name and can explicitly request a refresh;
the refresher has a 10-second deadline and atomically replaces the cache only
after a complete, validated response. It has no greeter integration. A network
error, invalid provider response, or stale cache simply hides weather on the
locker.

The audio module is a read-only/output-control projection of the existing
PipeWire/PulseAudio authority. It exposes only volume (clamped to 100%) and
mute; it has no output-device, microphone, or input-device selector.

The notification module is a read-only `NotificationManager` projection. It
never exposes actions, reply controls, URLs, images, jobs or history. `hidden`
does not instantiate the notification model, and only
the explicit `app-name` or `full-content` preference evaluates text fields.
All text passes through a bounded plain-text projection before it reaches
MeoUI. Media, weather and notification widgets are shown only on the active
secure output; non-active displays disclose none of that content.

## Interaction, controls and session actions

The lock screen has two presentation states on every secure surface:

1. **Ambient lock screen** is the covered-at-rest state. It may show the
   clock and enabled, privacy-filtered Meo widgets on the active secure output.
   It does not start a biometric exchange, open a camera, or retain a password
   field.
2. **Authentication screen** opens only after an intentional upward swipe on a
   touch display, or an equivalent explicit keyboard accessibility
   action. The swipe has a 72 dp travel threshold, is cancelled below that
   threshold, and uses the 250 ms emphasized-decelerate transition. It then
   requests the existing KDE authenticator; it does not implement a second
   authentication path.

The authentication screen contains one ordinary upstream-bound MeoUI text
field for a password, with the existing `PasswordSync` and authenticator as
its only credential owners. The virtual keyboard, keyboard-layout selector,
Caps Lock state, accessibility affordances and a capability-gated session
action menu remain available. Widgets and their content are absent from this
screen, so an unlocking user sees only the input task and necessary controls.

Fingerprint, smartcard and a future face method are status affordances, not
separate Meo credentials. A face label may appear only when the upstream KDE
authenticator exposes a trusted corresponding method. It begins only after the
authentication screen has been explicitly requested; Meo never opens a camera,
probes a face service, or performs passive recognition on the ambient screen.
If the upstream API has no face method, no face control is rendered.

All sleep, hibernate, switch-user, restart and shutdown actions call the
upstream session-management authority and are visible only when it reports the
capability and policy as available. A lock screen preserves its existing
sleep/hibernate/switch-user behavior; Login Manager P4 also exposes shutdown,
restart, suspend, hibernate, user switching and session selection through its
upstream greeter models. Meo must never invoke commands directly, infer an
available action, or substitute a decorative button for an unavailable action.
The Login Manager is function-first and deliberately shows no media, weather,
notification, album-art or arbitrary-widget surface.

## Secure widget layout editor

Meo Settings provides a **Lock-screen layout editor**, not an actual unlocked
KScreenLocker window. It renders a clearly labelled simulated security surface
inside the already unlocked Settings session, with the same validated output
geometry and placement model. Entering edit mode cannot authenticate, cover a
display, query lock-screen private data, or change a live KScreen layout.

The editor may reuse Plasma's widget-management interaction vocabulary:
selection handles, drag placement, per-output target selection, snapping and a
toggleable alignment/grid guide. It does **not** load Plasma applets into the
security surface. Lock-screen widgets are a small `MeoSecureWidgetRegistry` of
signed, reviewed Meo components with bounded data contracts (clock, media,
weather and notification summary in version one). Arbitrary third-party QML,
desktop applets, network widgets and desktop-widget instances are rejected.

Desktop editing remains Plasma's normal containment/widget manager. A Meo
first-party widget may offer a copy of its *safe placement preset* between the
desktop editor and the lock-screen editor, but it is instantiated separately
on each surface; a desktop widget is never dragged wholesale into the locker.
Desktop and lock-screen guides are off by default, edit-mode-only, use logical
output coordinates and snap to an 8 dp grid. They do not create a permanent
desktop overlay or write raw KScreen coordinates.

## Motion and accessibility baseline

All visual roles come from `MeoTheme` semantic dynamic roles, never a
page-local color palette.  The minimum touch target is 48 dp.  Keyboard,
virtual keyboard, screen reader, high contrast, RTL and CJK input remain
upstream functional requirements.

| Interaction | Motion | Reduce Motion |
| --- | --- | --- |
| Hover/focus | 100 ms Standard | opacity only, at most 100 ms |
| Authentication panel enter | 250 ms Emphasized Decelerate | opacity only, at most 100 ms |
| Authentication panel exit | 150 ms Emphasized Accelerate | opacity only, at most 100 ms |
| Authentication failure | 300 ms damped spring, max 8 dp horizontal | opacity only, at most 100 ms |
| Authentication success | 300 ms fade and small scale, after upstream success | opacity only, at most 100 ms |
| Screen migration | 250 ms fade-through | opacity only, at most 100 ms |

## Settings transaction contract

P1/P4 implementation follows `Inspect -> Plan -> Preview -> Authorize ->
Snapshot -> Apply -> Validate -> Commit -> Rollback`.  Preview uses a mock
surface in the existing Settings session and cannot claim to test the real lock
screen or greeter.  A failed apply restores the prior validated document;
"restore defaults" removes only the relevant Meo document after confirmation,
never upstream PAM/KScreenLocker/Login Manager configuration.
