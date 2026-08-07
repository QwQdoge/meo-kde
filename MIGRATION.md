# Migration status

The KDE/Plasma implementation was moved from
`meo-arch-os-workspace/meo-desktop` on 2026-08-02. This repository is now the
authoritative development location. The ISO workspace keeps a generated copy
because ArchISO builds must remain reproducible without filesystem links to a
sibling checkout.

The migration deliberately excluded the generic MeoUI runtime. MeoUI remains
independent and is consumed as the `MeoUI 1.0` QML module.

