# Evidence location

Generated evidence is stored outside production source at:

`/home/shekong/Projects/outputs/evidence/meo-kde`

Subdirectories:

- `screenshots/` — showcase baselines and actual Plasma captures
- `logs/` — static checks, builds, installation and runtime journals
- `metrics/` — checksums, package manifests, environment and performance data
- `packages/` — immutable package references/checksums
- `vm/` — ISO boot/install/installed-session evidence once VM testing begins

The `validation/reports/` directory contains human-readable analysis; raw and
generated evidence stays in the external evidence root.

