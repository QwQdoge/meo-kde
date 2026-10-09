# MeoKDE agent rules

## Start here

MeoKDE owns Plasma/KWin/KDE-native integration. Inspect `git status`, the affected package/native bridge, and its nearest contract/test before editing. Read only the relevant docs; do not scan all packages or historical material by default.

Read `docs/component-status.md` before changing shell composition, applet roles, standalone Dock code, old time/task surfaces, or deciding whether a historical component is still current.

## Scope control

Product contracts deliberately describe long-term MeoArch coverage. They are not an instruction to implement every missing feature during an unrelated task.

- Follow the current MeoArch milestone/scope contract when one is provided by the workspace/release task.
- Implement only the requested/current-milestone capability, work required to integrate it safely, and security/data-loss correctness fixes discovered directly in that work.
- Record unrelated bugs, missing features, architecture improvements, historical experiments, and technical debt instead of implementing them automatically.
- Do not restore an old branch feature merely because it is absent from `main`; first confirm that it still belongs to the current product direction.
- If a historical design conflicts with the current owning-repository contract, the current contract wins. Keep historical material only for migration/provenance where useful.

Repository cleanup, validation, and review tasks must not silently turn into open-ended feature development.

## Ownership

- Reusable platform-neutral MD3 controls/tokens/motion belong in MeoUI.
- Plasma packages, plasmoids, shell/layout defaults, themes, native KDE/Qt bridges, Meo.System, packaging, and KDE-specific policy belong here.
- Use real KDE/Qt/DBus APIs or a maintained KCM handoff. Do not fake network, Bluetooth, audio, brightness, power, task, display, or session state.
- Do not copy shared MeoUI components into this repository to avoid a dependency boundary.
- Code classified as Legacy in `docs/component-status.md` is not a target for new feature work unless the task explicitly revives/migrates it.

## Runtime system state

System-facing UI must derive variable facts and capabilities from the real runtime rather than hard-coded production values.

- Machine/session/hardware/service/account/package/configuration facts that can vary between systems must come from their authoritative KDE/Qt/DBus/native owner or a documented Meo.System contract whenever practical.
- Prefer maintained native APIs over parsing generic command output. Use stable read-only kernel/system interfaces only where no suitable owner API exists.
- Never substitute guessed or plausible hardware/system values when detection fails. Expose unavailable/unknown, hide the hardware-specific surface, or disable the capability with an explanation.
- Keep mutable state reactive where practical and re-read authoritative state after requested changes rather than assuming success.
- Test/preview fixtures may use fake deterministic values only behind explicit test/preview paths; production startup must not silently use them.
- Static branding, design policy, translated copy, stable identifiers, and the compile-time version of the exact component being run are product constants and may remain static.

This applies in particular to Meo.System, Plasma shell surfaces, Quick Settings, login/lock integration, system monitoring, power, displays, network, audio, Bluetooth, notifications, sessions, and hardware-dependent presentation.

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

Keep maintained code contracts in `docs/`. Project records belong under `$MEO_DOCS_ROOT/Projects/meo-kde/`. Existing workflows may use ephemeral local build trees; retained evidence and deliverables belong under `$MEO_OUTPUT_ROOT/meo-kde/{build,install,validation,packages,tmp}/`. Do not invent machine-specific paths if those roots are unset.

Preserve unrelated dirty work. Never use broad deletion, `git reset`, or `git clean` as routine cleanup.
