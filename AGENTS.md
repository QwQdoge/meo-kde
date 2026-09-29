# MeoKDE agent rules

## Start here

MeoKDE owns Plasma/KWin/KDE-native integration. Inspect `git status`, the affected package/native bridge, and its nearest contract/test before editing. Read only the relevant docs; do not scan all packages or historical material by default.

## Ownership

- Reusable platform-neutral MD3 controls/tokens/motion belong in MeoUI.
- Plasma packages, plasmoids, shell/layout defaults, themes, native KDE/Qt bridges, Meo.System, packaging, and KDE-specific policy belong here.
- Use real KDE/Qt/DBus APIs or a maintained KCM handoff. Do not fake network, Bluetooth, audio, brightness, power, task, display, or session state.
- Do not copy shared MeoUI components into this repository to avoid a dependency boundary.

## Validation matrix

Run only the checks matching the changed surface.

- Shell/script change: `bash -n` the affected entry points.
- Source-contract/theme/widget/input/auth change: run the matching unittest suite under `tests/`; use the full set from `.github/workflows/contracts.yml` only when the change crosses several areas.
- `native/system/` or related Meo.System change: mirror `.github/workflows/native-system-build.yml` — configure with `BUILD_TESTING=ON`, build, staged-install if relevant, then `QT_QPA_PLATFORM=offscreen ctest --test-dir build/native-system --output-on-failure --timeout 60`.
- Other native components: follow their nearest CMake target/workflow rather than compiling unrelated native trees.
- Shared visual primitive change: make it in MeoUI and satisfy MeoUI's own validation/Showcase requirements there.

Static/build/offscreen success does not prove a real Plasma/KWin session, hardware integration, login/session behavior, or live configuration changes.

## Live-system boundary

Do not restart/reload Plasma or KWin, log out, reboot, unload effects, switch display managers, or change the live display/theme/session state without explicit authorization. Prefer source, offscreen, staged, or VM validation first.

## Files and generated output

Keep maintained code contracts in `docs/`. Project records belong under `$MEO_DOCS_ROOT/Projects/meo-kde/`; generated output under `$MEO_OUTPUT_ROOT/meo-kde/{build,install,validation,packages,tmp}/`. Do not invent machine-specific paths if those roots are unset.

Preserve unrelated dirty work. Never use broad deletion, `git reset`, or `git clean` as routine cleanup.
