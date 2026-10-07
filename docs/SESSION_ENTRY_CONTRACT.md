# Meo session-entry presentation contract

## Scope and authority

This document defines the version-one **presentation and configuration contract** shared by the logged-in Meo Session Lock and the separate Meo Login surface. It does not make those two security boundaries interchangeable.

The authoritative normal lock path is the Meo-owned resident `meo-lockscreen` process documented in `LOCKSCREEN.md`. It acquires the compositor's Wayland session lock and delegates authentication to the maintained PAM-backed authentication integration. KScreenLocker-based Meo presentation work is historical/compatibility material and is not a second normal lock owner.

The login surface is owned by the Meo Login Manager fork and preserves its reviewed upstream authentication, daemon, service, D-Bus, and session-start boundaries. Login and unlock may share MeoUI presentation primitives and the schema below, but they never share transient credential state or assume that a login session and an unlock operation are the same lifecycle.

Ownership is therefore:

- **MeoUI** — generic cards, typography, semantic dynamic colors, motion, accessibility primitives, and preview components;
- **MeoKDE / Meo Session Lock** — the installed session-lock process, Wayland lock surfaces, lock-safe media/weather/status projections, display coordination, and typed presentation adapters;
- **Meo Login Manager** — the system login/greeter lifecycle and authentication/session-start authority;
- **Meo Settings** — the user-facing editor, safe preview, per-user lock configuration writer, reset flow, and authorized request flow for system-login presentation configuration.

No presentation surface stores a password, compares credentials in QML, or emulates authentication success.

## Version-one document

`schemas/meo-session-entry-v1.schema.json` is the formal schema. A document has `schemaVersion: 1` and exactly one `scope`:

- `lockscreen` is per-user presentation data for an already authenticated user's session. It may reference a current-user wallpaper asset.
- `login` is system presentation data written only through an authorized transaction. It cannot consume a previous user's media, notifications, private weather state, or current-user wallpaper asset.

The schema contains presentation preferences only:

- clock/date presentation;
- background treatment;
- wallpaper mode and symbolic wallpaper asset reference;
- lock-safe module enablement;
- notification/media/weather privacy;
- output-specific wallpaper presentation;
- active authentication-screen policy;
- Reduce Motion override.

It must not contain passwords, password hashes, PAM module names, biometric enablement, service control, arbitrary QML, arbitrary URLs, raw filesystem paths, shell commands, or raw display coordinates.

Wallpaper references are **symbolic asset identifiers** resolved by the trusted owning component. In version one:

- `system-default` requires an empty `assetId`;
- `current-user` is allowed only for `lockscreen` and requires a non-empty safe symbolic ID;
- `managed-asset` requires a non-empty safe symbolic ID;
- path traversal, URLs, empty path segments, and direct filesystem paths are invalid.

Output identities are opaque stable display identities. They are not coordinates and must not expose raw EDID payloads as configuration keys.

Unknown properties, wrong schema versions, unresolved assets, invalid output identities, duplicate output entries, oversized documents, and invalid values fail closed. A parse/configuration failure falls back to safe presentation defaults; it never prevents the secure lock/login surface from appearing or prevents the real authentication authority from operating.

## Privacy defaults

Version-one defaults are intentionally conservative:

- lock-screen notifications expose **count only** by default;
- application names and full notification content require explicit opt-in;
- album artwork is opt-in;
- precise weather location is opt-in;
- media/weather/status modules remain removable and asynchronous and must never gate authentication;
- the login scope exposes no notifications, media, album artwork, user-session audio state, or user-private weather state.

Version one does **not** enable login weather. A future schema revision may add a city-level, system-owned public weather cache after that data source and its privacy model are explicitly specified. It must not reuse a prior user's private weather cache.

## Lock-surface and display rules

Every usable output must remain covered while the Wayland session lock is held. The lock process may designate one output as the active interaction/authentication surface, but an active-screen policy must never turn another output into an uncovered desktop.

The supported presentation policies are:

- `auto` — choose an appropriate active output from current topology and interaction;
- `fixed-primary` — prefer the current primary output while it remains eligible;
- `follow-interaction` — move the active authentication/presentation focus to the output receiving an allowed interaction.

Hotplug, output removal, DPMS recovery, suspend/resume, mixed scaling, rotation, and negative desktop geometry must preserve secure coverage. If the active output disappears, focus moves to another covered eligible output without creating a second credential model.

The schema controls presentation only. It must not write the live KScreen topology, create security windows from Settings, or alter compositor output geometry.

## Lock-safe external data

External cards are optional projections. Their failure or timeout hides the card; it never blocks authentication.

### Media

The lock screen creates media presentation only when the user enables it. The maintained media bridge reads the current user's MPRIS services asynchronously and exposes only bounded presentation metadata and explicitly allowed playback controls.

Remote artwork is rejected. Local artwork is accepted only through the reviewed bounded asset path/size policy. Album artwork visibility is controlled separately from media-control availability.

### Weather

The lock surface performs no network request during authentication. Weather, when enabled for the logged-in user's lock screen, is read from a bounded per-user cache produced by the separate refresher. Invalid, stale, future-dated, oversized, or unavailable cache data hides the weather surface.

The login surface has no weather provider in schema v1.

### Audio

The lock projection may expose output volume and mute only. It does not expose microphone/input controls, arbitrary device routing, or privileged audio configuration.

### Notifications

The lock notification projection is read-only and bounded. It must not expose arbitrary application actions, replies, URLs, jobs, or privileged operations. Data fields are evaluated only at the privacy level the user selected.

Sensitive widgets appear only on the active secure presentation output. Other covered outputs remain non-sensitive unless a future contract explicitly defines otherwise.

## Interaction and authentication

The lock screen has two logical presentation states:

1. **Ambient** — secure covered-at-rest presentation. It may show the clock and enabled privacy-filtered widgets.
2. **Authentication** — entered after an explicit user interaction. It shows only authentication and required accessibility/session controls; lock-screen content cards do not become a second interactive desktop.

The password field is only a view over the maintained authentication integration. Authentication success comes from the backend; animation never causes authentication success.

Fingerprint, smart-card, or future biometric methods are capability/status affordances over maintained authentication interfaces. They are not separate Meo credential databases. Password fallback remains available according to the underlying authentication policy.

The lock surface must never:

- persist plaintext credentials;
- send credentials to Meo Account, AI, analytics, or general application state;
- silently weaken upstream retry/rate-limit behavior;
- start passive camera/face recognition merely because the ambient lock surface is visible.

## Session and power actions

Sleep, hibernate, switch-user, logout, restart, and shutdown actions call their owning session/system authorities and are shown only when those authorities report the action as available.

User switching hands off to the supported login/session manager. The lock screen does not implement a second login manager.

## Secure layout editor

Meo Settings provides a **session-entry preview/layout editor**, not an unlocked real locker or greeter instance.

The editor:

- renders a clearly labelled simulated surface inside the already unlocked Settings session;
- edits only schema-approved presentation values;
- may provide drag handles, snapping, grid/alignment guides, and per-output preview targeting;
- may instantiate only reviewed Meo secure-widget definitions with bounded data contracts;
- never authenticates, acquires a real session lock, changes live display topology, loads arbitrary third-party QML, or imports a desktop Plasma widget instance into the secure surface.

A preview proves layout/configuration behavior only. It is not security acceptance evidence.

## Motion and accessibility baseline

All visual roles come from Meo semantic roles rather than page-local palettes. The minimum touch target is 48 dp. Keyboard access, virtual-keyboard compatibility where supported, screen-reader semantics, high contrast, RTL, and CJK text entry remain product requirements.

Reduce Motion must remove decorative spatial/spring motion without changing security ordering. In particular, the desktop is not exposed before successful authentication and lock release simply because motion is disabled.

## Settings transaction contract

Both scopes validate the same presentation schema but use different writers.

### Per-user lock-screen scope

The lock-screen writer:

1. validates the complete document;
2. snapshots the previous validated document when one exists;
3. atomically writes the new user-scoped document with private permissions;
4. reads the persisted document back and validates it again;
5. restores the previous snapshot on verification failure when doing so cannot overwrite a concurrent newer write;
6. refuses blind rollback if the file changed concurrently.

`Restore defaults` removes/replaces only the scoped Meo presentation document. It does not delete user media, PAM configuration, the locker package, or unrelated KDE state.

### System login scope

The login writer is a separate privileged transaction boundary. Meo Settings sends only a closed schema-validated request. The authorized service owns authorization, snapshot, safe asset resolution, atomic apply, validation, commit/rollback, and structured failure reporting.

The login writer must not edit PAM policy, service enablement, arbitrary display-manager files, or authentication configuration as a side effect of changing presentation settings.

## Compatibility boundary

KScreenLocker and upstream KDE tools may remain available as compatibility/recovery components where the installed desktop still needs them, but they are not a parallel normal Meo session-lock architecture. Do not configure two independent normal lock owners or allow them to race for the same session.

Historical KScreenLocker-specific Meo modules and documents should be treated as migration/provenance material unless another current contract gives them an explicit compatibility responsibility.

## Acceptance boundary

Source review, schema validation, unit tests, and package builds are necessary but are not proof that the real security path works.

Before Meo Session Lock is considered release-ready as the default locker, installed-session evidence must cover at least:

- manual lock;
- idle-triggered lock;
- lock before suspend and resume into a locked state;
- correct and incorrect password behavior;
- biometric success/failure/password fallback when supported;
- primary lock process failure and secure fallback behavior;
- repeated lock/unlock cycles;
- no visible desktop frame before completed unlock;
- multiple monitors and monitor hotplug/removal while locked;
- DPMS off/on;
- notification/media privacy modes;
- session/power actions using their owning authorities.

Failure to securely acquire or maintain the session lock is a release blocker when Meo Session Lock is the default installed locker.
