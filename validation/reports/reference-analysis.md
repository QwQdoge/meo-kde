# Supplied reference analysis

## Dark settings reference

Visually appears to use a narrow persistent rail, grouped settings cards,
restrained translucent dark surfaces, subtle outlines and a compact desktop
density. Meo KDE adapts the layered surface hierarchy, persistent status area,
clear selection roles and restrained opacity. It rejects the product branding,
vertical navigation copy and direct Caelestia layout.

## Pink MD3 desktop reference

Visually appears to use wallpaper-led colour, large expressive clock type,
rounded information modules and compact bottom widgets. Meo KDE adapts the
wallpaper/system-accent colour relationship, expressive brand typography and
rounded grouped surfaces. It rejects the oversized decorative widgets as a
default shell requirement and keeps task switching/navigation conventional.

## Adaptation matrix

| Reference behaviour | Relevance | MeoUI/MeoKDE equivalent | Decision | Reason |
|---|---|---|---|---|
| wallpaper-led palette | high | Plasma accent to MeoUI dynamic roles | adapt | native KDE setting remains source of truth |
| layered translucent cards | high | surface-container role ladder | adapt | hierarchy without costly global blur |
| persistent top status region | high | `org.meo.topbar` | keep | desktop status and quick access |
| compact grouped navigation | high | launcher search/pinned sections | adapt | desktop information density |
| very large clock | medium | expressive Quick Settings header | adapt | avoid consuming workspace |
| oversized mobile radii everywhere | low | MeoUI desktop shapes | reject | reduces density and usable area |
| local fake control state | none | KDE real backends | reject | state must match the system |
| direct visual clone/branding | none | distinct Meo identity | reject | references are principles, not authority |

No Windows MD3 source project was present in the supplied attachment or scanned
project roots. Therefore component-level Windows implementation claims are
**NOT TESTED**, not inferred from screenshots.

