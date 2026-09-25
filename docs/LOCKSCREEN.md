# MeoArch session lock

## Product identity

The product is **Meo Session Lock**. Installed/runtime names are Meo-owned:

- package: `meo-lockscreen`
- service: `meo-lockscreen.service`
- launcher: `meo-lockscreen-launch`
- lock command: `meo-lock`
- Quickshell configuration: `meo-lockscreen`
- state/cache/config namespaces: `meo-lockscreen`
- private runtime/QML prefix: `/usr/lib/meo-lockscreen`

No upstream project name is part of the visible lock-screen branding, user-facing command names, service description, state paths, or package description. Upstream names that remain inside QML/C++ module ABIs are implementation details and are kept only where renaming them would create unnecessary fork surface.

## Meo visual contract

The lock surface must follow MeoUI rather than an upstream theme. The package installs a managed `shell.json` plus Meo Material role tables and the launcher places them in an isolated runtime configuration before starting the resident lock process.

Typography follows the MeoUI contract:

- `Comfortaa` — brand/display/large title and lock clock
- `Roboto` — body, buttons, inputs, labels and ordinary UI
- `Roboto Mono` — monospace/status text
- `Material Symbols Rounded` — symbolic icon face

The package installs the Meo-owned Comfortaa/Roboto font assets already carried by MeoKDE and depends on the system Roboto Mono package. It does not use the upstream Rubik/Google Sans/Cascadia defaults for the lock surface.

Colors use the same Material 3 roles as MeoUI. The checked-in light and dark role tables are derived from the canonical Meo fallback seed and include `primary`, containers, surface hierarchy, outline, error and Meo success roles. The launcher follows the current KDE light/dark scheme by default; `MEO_LOCKSCREEN_COLOR_SCHEME=light|dark` is available for deterministic testing. Dynamic-color parity can replace these fallback tables later, but products must not invent a separate lock-screen palette.

The lock layout and motion may reuse compatible open-source implementation work, but visible typography, semantic colors, paths, names and product copy belong to the Meo design system.

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
meo-lockscreen-launch
        |
        +--> install managed Meo typography config into isolated runtime config
        +--> select Meo light/dark Material role table
        +--> expose private Meo QML/plugin path
        |
        v
qs -n -c meo-lockscreen        (resident, unlocked)
        |
        +--> security/data services required by the lock cards
        +--> Wayland WlSessionLock
        +--> early ScreencopyView warm-up

user / idle trigger
        |
        v
/usr/bin/meo-lock
        |
        v
qs -c meo-lockscreen ipc call lock lock
        |
        v
WlSessionLock -> lock surface -> PAM -> Meo unlock motion -> release lock
```

The process stays resident rather than starting when the key binding is pressed. The imported implementation performs an early screencopy while the session is still unlocked; this avoids first-use ICC/screencopy initialization after the compositor has already entered the secure lock state. Keeping the renderer and QML graph warm also removes process startup from the visible transition.

`QS_DISABLE_FILE_WATCHER=1`, `QS_NO_RELOAD_POPUP=1`, and `settings.watchFiles: false` are used in production so source/package changes cannot hot-reload the security surface while it is securing the session.

## Animation behavior

The intended Meo motion keeps the compact-lock -> expanded-panel -> compact-unlock sequence from the imported implementation because it already has the correct security ordering. On lock, the compact central lock rotates/scales into the rounded content panel. On successful authentication, content scales/fades away, the compact unlock state returns, the background fades, and only then is the Wayland session lock released.

The important rule is **authentication success causes the animation; the animation never causes authentication success**. The desktop must not be exposed before the success transition reaches its teardown point.

This removes avoidable application-level flashing. It cannot guarantee that every driver/compositor path will never produce a black frame during mode changes, suspend/resume, VT switching, or compositor failure.

## Authentication boundary

Do not replace PAM with a QML password comparison. The lock surface uses Quickshell's PAM integration and the Wayland session-lock protocol. Password/fingerprint authentication remains backend-authoritative.

The display manager/login greeter is a separate boundary. Meo Login Manager should use the same Meo typography, Material roles and motion language while continuing to use Plasma Login Manager's existing authenticator and session-start path.

## Build and package

From an Arch/MeoArch checkout:

```bash
./tools/lockscreen/build-package.sh
```

The script copies the packaging recipe into the standard Meo output tree, runs `makepkg --cleanbuild --syncdeps`, copies packages to:

```text
~/Projects/outputs/meo-kde/packages/
```

and records evidence under:

```text
~/Projects/outputs/meo-kde/validation/<UTC-run-id>-lockscreen-package/
```

The package recipe lives at `packaging/arch/meo-lockscreen/PKGBUILD` and installs the private runtime under Meo-owned paths so a separately installed upstream desktop shell can coexist without file ownership conflicts.

## Install and smoke test

After building and installing the package, enter a Hyprland session and run:

```bash
systemctl --user status meo-lockscreen.service
qs -c meo-lockscreen ipc show
meo-lock
```

Expected behavior:

1. The resident Meo process is already running before `meo-lock` is invoked.
2. The lock command sends IPC to that process rather than starting a second renderer.
3. Visible colors are the Meo Material role table, not the imported source defaults.
4. Clock/display text uses Comfortaa; controls and password UI use Roboto; icons use Material Symbols Rounded.
5. A bad password never unlocks.
6. A successful PAM authentication completes the Meo unlock transition before the desktop is exposed.
7. Suspend/resume and multi-monitor behavior are tested in a VM and then on target hardware before release.

If a non-UWSM Hyprland session does not start `graphical-session.target` with the compositor environment imported, start `meo-lockscreen.service` from that session's existing startup hook. Do not start another lock renderer.

## Third-party provenance

The first implementation imports a pinned GPL-3.0 lock-shell implementation from `caelestia-dots/shell`, commit `20e625d6bf1a9d0bb7625a4bb814797d187b075d`, for the underlying lock layout/services/PAM integration and motion implementation. That provenance is intentionally kept in source comments, `THIRD_PARTY_NOTICES.md`, package license files and the reproducible source pin. It is not used as Meo product branding.

This is source reuse under its license, not an attempt to remove attribution. Any redistributed package must retain the upstream GPL text and third-party notice.

## Release gate

A package build is only source/build evidence. Before promoting Meo Session Lock into an ISO image, record runtime validation for:

- lock/unlock with correct and incorrect passwords;
- fingerprint when configured;
- suspend -> resume -> unlock;
- DPMS off/on -> unlock;
- one and multiple monitors;
- repeated lock/unlock cycles;
- compositor restart/failure recovery;
- light and dark Meo role tables;
- Comfortaa/Roboto/Roboto Mono font resolution;
- no visible desktop frame between the secure lock surface and the completed unlock animation.

Do not describe static QML checks or a successful package build as proof that the real Wayland session-lock path has passed.
