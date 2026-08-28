# Meo KDE authentication and notification surfaces

## Ownership

`meo-kde` owns the PolicyKit listener, KDE/Plasma models, D-Bus compatibility,
session activation, packaging and desktop defaults. Every visual or interactive
element in the new authentication surface is composed from `MeoUI`; the KDE
package does not maintain a second button, text-field or dialog design system.

The agent does not replace PolicyKit or PAM. It implements the graphical
listener and passes a response to the `PolkitQt1::Agent::Session` that initiated
the request. KWallet and other credential stores remain responsible for their
own encrypted storage.

## Security contract

- One authorization request is displayed at a time. Concurrent requests fail
  explicitly so the user cannot confuse one requester with another.
- A request expires after five minutes and permits at most three failed
  authentication attempts.
- The agent uses a generic protected-system icon and shows the action ID; it
  does not trust an application-supplied icon as proof of identity.
- The response field is cleared before submission and again on retry, identity
  change, cancellation and completion. The C++ response buffer and PolicyKit
  cookie are overwritten before release, and Linux process dumps are disabled.
- Responses are never logged, stored in settings or sent over the session bus.
- The existing KDE parent-window and Wayland activation-token D-Bus methods are
  retained for callers that already integrate with the Plasma agent.

## Desktop integration

`meo-desktop` provides and replaces the Arch `polkit-kde-agent` dependency. It
installs the Plasma-compatible `plasma-polkit-agent.service` and autostart entry,
so only one graphical listener registers for a session. Do not enable a second
PolicyKit authentication agent alongside it.

The Wi-Fi password prompt uses the same secret-handling rules at the QML
boundary and only forwards the password to the existing `Meo.System` network
backend.

## Notifications

The Meo notification center continues to consume Plasma's
`org.kde.notificationmanager` model, preserving actions, replies, jobs, progress,
Do Not Disturb and application configuration. Application-provided markup is
projected to bounded plain text before display, critical notifications are
announced explicitly, remote/path-like icon sources are rejected, and long
bodies can be expanded without turning remote content into an interactive
rich-text surface.

## Acceptance on Arch/Plasma

1. Build and install the package in a clean Arch VM; confirm that pacman removes
   the stock `polkit-kde-agent` and keeps `plasma-desktop` dependencies satisfied.
2. Log in to Plasma and verify `systemctl --user status plasma-polkit-agent` and
   a single PolicyKit listener process.
3. Trigger actions through PackageKit, UDisks, NetworkManager and System
   Settings; cover success, cancellation, three failures, timeout and a request
   with multiple administrator identities.
4. Verify keyboard focus, Enter/Escape, screen-reader names, light/dark themes,
   100%–200% scale, parent-window placement and Wayland activation.
5. Send normal, critical, job, reply and multi-action notifications; verify Do
   Not Disturb, safe body projection, expansion, clear and application settings.
