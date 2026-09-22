# MeoArch lock screen

## Scope

`meo-lockscreen` is the Hyprland/Wayland lock surface used by the MeoArch prototype. The first implementation deliberately reuses Caelestia Shell's lock module instead of visually approximating it.

Pinned upstream:

- Project: `caelestia-dots/shell`
- Commit: `20e625d6bf1a9d0bb7625a4bb814797d187b075d`
- License: GPL-3.0

The package installs the complete pinned Caelestia shell QML/service/plugin source needed by the lock screen into Meo-specific paths, then replaces only the top-level `shell.qml` with `lockscreen/shell.qml`. The lock module itself, including its cards, password UI, PAM flow and lock/unlock motion, remains upstream code.

This is intentional source reuse, not an uncredited visual copy. Keep `THIRD_PARTY_NOTICES.md` and the upstream license in every distributed package.

## Runtime chain

```text
Hyprland / UWSM graphical session
        |
        v
systemd --user graphical-session.target
        |
        v
meo-lockscreen.service
        |
        v
qs -n -c meo-lockscreen        (resident, unlocked)
        |
        +--> Caelestia ServiceLoader / state services
        +--> Caelestia Lock + WlSessionLock
        +--> one early ScreencopyView warm-up

user / idle trigger
        |
        v
/usr/bin/meo-lock
        |
        v
qs -c meo-lockscreen ipc call lock lock
        |
        v
WlSessionLock -> LockSurface -> PAM -> unlock animation -> release lock
```

The service is kept resident rather than launched when the lock key is pressed. Caelestia's `Lock.qml` performs an early screencopy while the session is still unlocked; its upstream comment explains that the ICC/screencopy backend can otherwise be initialized too late, after the compositor has already entered the secure lock state. Keeping the process alive also removes renderer/process startup from the visible lock transition.

`QS_DISABLE_FILE_WATCHER=1`, `QS_NO_RELOAD_POPUP=1`, and `settings.watchFiles: false` are used in production so a source/package change cannot hot-reload the lock UI while it is securing the session.

## Animation behavior

The animation is Caelestia's own implementation. On lock, the central shape begins as a compact lock icon, rotates/scales into the large rounded lock panel, fades the lock icon away, and brings in the full three-column content. On successful authentication the sequence reverses: content scales/fades away, the compact lock icon returns, the background fades out, and only then is `WlSessionLock.locked` set to `false`.

That ordering is important: the compositor is not asked to reveal the desktop before the visual unlock transition has completed.

This removes avoidable application-level flashing. It cannot promise that every GPU/driver/compositor will never produce a black frame during display mode changes, suspend/resume, VT switching, or a compositor crash.

## Authentication boundary

Do not replace Caelestia's PAM flow with a QML password comparison. The lock surface uses Quickshell's PAM service and the Wayland session-lock protocol. Password, fingerprint and other authentication behavior stays in the upstream lock implementation and PAM configuration.

The display manager/login greeter is a separate security boundary. The later Meo login-manager work must reproduce this visual language using Plasma Login Manager's existing greeter/authentication API; it must not import this Quickshell lock runtime into the pre-login greeter.

## Build and package

From an Arch/MeoArch checkout:

```bash
./tools/lockscreen/build-package.sh
```

The script copies the packaging recipe to the standard Meo output tree, runs `makepkg --cleanbuild --syncdeps`, copies produced packages to:

```text
~/Projects/outputs/meo-kde/packages/
```

and records build evidence under:

```text
~/Projects/outputs/meo-kde/validation/<UTC-run-id>-lockscreen-package/
```

The package recipe lives at `packaging/arch/meo-lockscreen/PKGBUILD`. It fetches the exact pinned Caelestia commit and builds its private plugin/runtime into `/usr/lib/meo-lockscreen`, so a normal `caelestia-shell` installation can coexist without file ownership conflicts.

## Install and smoke test

Build first, then install the produced package with pacman. The package enables the user unit through `graphical-session.target.wants`; its environment conditions restrict it to a Wayland Hyprland session.

After entering a Hyprland session:

```bash
systemctl --user status meo-lockscreen.service
qs -c meo-lockscreen ipc show
meo-lock
```

Expected behavior:

1. The service is already running before `meo-lock` is invoked.
2. `meo-lock` sends IPC to that existing process rather than starting a second renderer.
3. The lock surface visually matches the pinned Caelestia lock screen.
4. A bad password does not unlock.
5. A successful PAM authentication runs the Caelestia unlock animation before the desktop is exposed.
6. Suspend/resume and multi-monitor behavior must be tested in a VM and then on target hardware before this becomes a release default.

If a non-UWSM Hyprland session does not start `graphical-session.target` with the compositor environment imported, start `meo-lockscreen.service` from that session's existing `exec-once` hook. Do not add a second Quickshell instance.

## Release gate

A package build is only source/build evidence. Before promoting the lock screen into an ISO image, record a runtime validation for:

- lock/unlock with correct and incorrect passwords;
- fingerprint when configured;
- suspend -> resume -> unlock;
- DPMS off/on -> unlock;
- one and multiple monitors;
- repeated lock/unlock cycles;
- compositor restart/failure recovery;
- no visible desktop frame between the secure lock surface and the completed unlock animation.

Do not describe static QML checks or a successful package build as proof that the real Wayland session-lock path has passed.
