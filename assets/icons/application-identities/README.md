# Meo first-party application identities

This source sheet owns the canonical design source for first-party application
identities. Every color and monochrome SVG uses the `48u` grid defined by
[`docs/icons/ICON_CONTRACT_V1.md`](../../../docs/icons/ICON_CONTRACT_V1.md).

The source sheet is not a global runtime icon theme. Each owning application
package installs its own color SVG as
`hicolor/scalable/apps/<iconName>.svg`, so `Original` follows that application
when it is upgraded. It also installs reviewed `16x16`, `22x22`, and `32x32`
masters into the matching hicolor directories. The Studio renderer consumes
those named optical corrections for Meo Color overlays; it may create
Monochrome or approved AI variants without changing the canonical identity.
An optional aiStructuralMaskSource can preserve reviewed transparent cuts for
an AI variant where the colour master represents those details only through
palette differences; it cannot supply a new silhouette or colour treatment.

Do not use the names in `systemSemanticChildren` as application identities.
They belong to `MeoSymbols`/KDE system semantics and remain outside Studio and
AI pack transformations.
