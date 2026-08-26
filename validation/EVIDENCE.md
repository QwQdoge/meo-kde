# Evidence location

Generated evidence is stored outside production source at:

`/home/shekong/Projects/outputs/meo-kde/validation/<UTC-run-id>/`

Subdirectories:

- `screenshots/` — showcase baselines and actual Plasma captures
- `logs/` — static checks, builds, installation and runtime journals
- `metrics/` — checksums, package manifests, environment and performance data
- `/home/shekong/Projects/outputs/meo-kde/packages/<version>/` — immutable package references/checksums
- `vm/` — ISO boot/install/installed-session evidence once VM testing begins

Human-readable audit conclusions belong in
`/home/shekong/Documents/Obsidian Vault/MeoArch/Projects/meo-kde/`; raw and
generated evidence stays in the external output root.
