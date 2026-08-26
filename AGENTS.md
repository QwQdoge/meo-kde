# MeoKDE Agent Rules

## Ownership and safety

- Keep reusable MD3 controls, tokens, responsive behavior, and generic accessibility work in `/home/shekong/Projects/meo-ui`. Keep Plasma packages, KDE models, native bridges, layouts, defaults, and packaging here.
- Use real KDE/Qt/DBus APIs or an explicit maintained KCM handoff. Never implement fake network, Bluetooth, brightness, power, audio, task, or session state.
- Inspect Git status, source/package ownership, installed/runtime scope, and relevant contracts before edits. Preserve unrelated dirty work and never treat ISO staging as source authority.
- Do not restart/reload Plasma or KWin, log out, reboot, unload effects, or change live display/theme state without explicit user approval. Prefer the smallest reversible repair.

## Repository hygiene

- New root content is limited to entry docs, source directories, and necessary build/release configuration. Do not create loose `plan.md`, versioned architecture drafts, audits, journals, screenshots, or generated logs.
- Keep only code-bound public contracts in `docs/`. Put plans, audits, decisions, agent journals, and historical reports in `/home/shekong/Documents/Obsidian Vault/MeoArch/Projects/meo-kde/`, using the numbered `00-inbox/`, `01-overview/`, `02-decisions/`, `03-work/`, `04-validation/`, and `99-archive/` folders described by that project's reader-facing `README.md`.
- Store generated material only in `/home/shekong/Projects/outputs/meo-kde/{build,install,validation,packages,tmp}/`: compiler results, staged installs, evidence, releasable packages, and disposable work respectively. A validation run is `validation/<UTC-run-id>/` and contains a `README.md` and evidence. Do not add new outputs to repository `build/`, `out/`, or `artifacts/`; do not delete/move existing legacy content without a separately approved migration.

## Validation and reporting

- Validate the narrowest affected layer and then the necessary integration layer before synchronization or release work. Record command, environment, and result only after execution.
- Separate source/static/offscreen evidence from live Plasma/KWin acceptance. Do not claim a live result based only on compilation, logs, hashes, or screenshots.
- When a shared UI change belongs in MeoUI, follow MeoUI's mandatory Showcase refresh: 100% coverage of public tokens, QML items, module/runtime APIs, and visible behavior; build and run it, with evidence in `/home/shekong/Projects/outputs/meo-ui/validation/<UTC-run-id>/`.
