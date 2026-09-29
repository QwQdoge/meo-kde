# MeoKDE Agent Rules

## Ownership and runtime boundary

MeoKDE owns Plasma packages, KDE models, native bridges, layouts/defaults, shell integration, and packaging. Platform-neutral MD3 controls/tokens/responsive behavior belong in MeoUI; resolve it through `$MEO_UI_ROOT` when needed instead of copying shared UI here.

Plasma, KWin, and KDE/system services are authoritative. Use real Qt/KDE/DBus APIs or an explicit maintained KCM handoff; never fake network, Bluetooth, brightness, power, audio, task, or session state.

## Work sequence and validation

Inspect `git status`, the owning source/package, relevant contract, and installed/runtime boundary before editing. Run the smallest applicable checks first.

- Shell change: `bash -n` the affected entrypoint.
- Source-contract change: run the relevant Python unittest group under `tests/`; for broad contract changes mirror `.github/workflows/contracts.yml`.
- Native C++/QML integration: configure/build/CTest using the matching native CI workflow.
- Shared MeoUI delivery change: make it in MeoUI and follow MeoUI's real gate—mechanical coverage for public QML exports plus Showcase/checklist evidence for affected non-QML or behavioral delivery.

Compilation/static/offscreen evidence does not prove a live Plasma/KWin session.

## Files and live-system safety

Use `$MEO_DOCS_ROOT/Projects/meo-kde/` for plans/audits/decisions and `$MEO_OUTPUT_ROOT/meo-kde/{build,install,validation,packages,tmp}/` for new generated output. Do not add new output to legacy repository `build/`, `out/`, or `artifacts/`; leave existing material untouched.

Do not restart/reload Plasma or KWin, log out, reboot, unload effects, change live display/theme state, or install system-wide changes without explicit authorization. Preserve unrelated dirty work and prefer the smallest reversible repair.
