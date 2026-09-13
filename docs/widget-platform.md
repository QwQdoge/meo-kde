# Meo Widget platform

## Product contract

Meo Desktop has two widget hosts under one **Add Widgets** entry point:

```text
Meo Desktop
├── Meo Widget Host      → MeoWidget contract → first-party Plasma adapter
└── Plasma Widget Host   → real Plasma Applet / Containment lifecycle
```

The second path is compatibility, not imitation. A KDE Store package remains
the package named by its own `KPlugin.Id`; its QML root is still
`PlasmoidItem`, and `plasmoid`, `Plasmoid`, `configuration`, `formFactor`, and
`location` stay provided by Plasma. Meo does not provide a partial fake
`Plasmoid`/`PlasmaCore` API.

`DesktopWidgets` discovers desktop-capable Plasma packages in the normal KDE
data locations, including the user and system `plasma/plasmoids` paths. It
checks the standard `metadata.json` contract (`KPackageStructure:
Plasma/Applet`, a safe `KPlugin.Id`, an on-disk `contents/ui/main.qml`, and a
desktop form factor when one is declared), then calls the active real
`Plasma::Containment::createApplet()` method. A package identifier typed into
QML is rejected unless it was just discovered in those locations.

This is deliberately desktop-only. The bridge rejects panels, task managers,
Docks, wallpapers, and non-desktop containments. Plasma continues to own
layout persistence, drag/resize, placement, screen affinity, and applet
lifecycle; Meo Widget Explorer does not replace Plasma Edit Mode.

## MeoWidget API

`MeoUI 1.0` owns the platform-neutral public `MeoWidget` QML type. A widget
declares a stable ID, cell size, privacy, refresh policy, supported host
surfaces, and framing policy:

```qml
MeoWidget {
    widgetId: "weather"
    preferredSize: MeoWidget.SizeMedium
    supportedSizes: [MeoWidget.SizeSmall, MeoWidget.SizeWide,
                     MeoWidget.SizeMedium, MeoWidget.SizeLarge]
    privacy: MeoWidget.Location
    refreshPolicy: MeoWidget.Periodic
    supportedSurfaces: [MeoWidget.Desktop, MeoWidget.LockScreen]
    frameMode: MeoWidget.MeoFramed
}
```

The enum sizes mean `1x1`, `2x1`, `2x2`, `4x2`, and `4x4` respectively. The
type uses `MeoTheme` semantic dynamic colours, `cardRadius`, spacing tokens,
the shared typeface scale, and Reduce Motion-aware state/shape transitions.
It has no Plasma or DBus dependency.

MeoKDE provides a small registry that maps a Meo ID to its desktop adapter and,
where explicitly approved, a separate lock-screen adapter. The current
registry is:

| Meo ID | Desktop adapter package | Lock-screen adapter | Data boundary |
| --- | --- | --- | --- |
| `clock` | `org.meo.widget.clock` | `MeoAmbientClock` | cached weather is optional and location-private |
| `media` | `org.meo.widget.media` | `MeoMediaController` | current-user-session MPRIS only |

The adapter being a real Plasma applet is an implementation detail for
desktop placement. The MeoWidget API itself is not constrained to Plasma and
may later be hosted by Overview or other reviewed Meo surfaces.

## Presentation modes

Every catalog entry describes a requested presentation policy:

| Mode | Meaning | Current state |
| --- | --- | --- |
| `Native` | Plasma applet controls its own background and theme. | Active for generic Plasma packages. |
| `Meo Framed` | Meo controls the outer editing surface, handles, snapping, placement surface, and MD3 shadow/shape. Applet content remains unmodified. | Active for MeoWidget content. The generic containment adapter is source-ready, but unbuilt and unpublished. |
| `Adaptive` | Meo draws an outer surface only when content declares no own background. | Active for MeoWidget content. The generic adapter uses Plasma background hints to preserve an applet's native surface, but is unbuilt and unpublished. |

The generic `Meo Framed`/`Adaptive` layer is a version-pinned patch at
`packaging/arch/meo-plasma-desktop/0001-meo-widget-presentation.patch` for
the upstream `plasma-desktop` tag `v6.7.5`. It replaces only the desktop
containment's `appletContainerComponent` with a subclass of
`BasicAppletContainer`; `AppletsLayout`, `AppletInterface` and each package's
own QML are not copied or emulated. The companion `meo-plasma-desktop` recipe
provides/conflicts/replaces the `plasma-desktop` package atomically and
depends on the shared `meoui-qml` module. It is source-ready only: it has not
been built, published, installed or activated on this machine.

The policy defaults to `Adaptive`, and exposes `Native`, `Meo Framed` and
`Adaptive` as a containment configuration value. A Meo Settings control and
real-desktop acceptance are still required before users can change it through
the product UI. Widget Explorer therefore continues to describe third-party
entries as **Plasma Widget · Compatibility mode**, rather than claiming a
running cosmetic rewrite.

## Unified interaction, strict security boundary

Users see both sources in one searchable catalog and can add, move, resize,
delete, configure, and persist them through normal desktop containment
behavior. The Meo-provided Widget Explorer uses a ChromeOS-style wide sheet:
a search/category rail on the left and a unified Meo/Plasma preview field on
the right. A source chip names a **Meo** item or **Plasma compatibility** item,
but it does not split the interaction into separate technical modes. Preview
geometry comes from declared defaults or a neutral fallback, while visual
preview templates show recognisable clock, calendar, weather, media, or system
content. Only the clock template reads non-sensitive local time; every other
template uses clearly representative sample content, so browsing does not
reveal a user's media, calendar, location, or telemetry. It never starts an
arbitrary Plasma package inside the picker merely to render a thumbnail. The
package is created only after the explicit Add action reaches the real
containment. The Explorer is scoped only to adding desktop widgets; it
intentionally does not manage panels, taskbar, Dock, or global layout
controls. Its right-click actions use the shared `MeoContextMenu`, so the
catalog follows the same MD3 dynamic tokens, keyboard traversal, RTL,
submenu, and accessibility rules as other Meo menus.

Lock screen editing is not a generic extension host. It may display only an
explicit reviewed Meo registry entry whose lock-screen adapter is listed
above. Generic Plasma packages are desktop-only: the lock screen never loads
desktop applet code, user-installed plasmoids, or an arbitrary package from a
Plasma data location. KDE's authenticator and the KScreenLocker trust boundary
remain authoritative.

## Compatibility and acceptance matrix

| Capability | Meo Widget | Native Plasma Widget |
| --- | --- | --- |
| Original `Applet` / `Containment` lifecycle | desktop adapter | required |
| `PlasmoidItem`, `plasmoid`, configuration, form factor, location | desktop adapter | required and untouched |
| Standard package discovery | first-party package | user and system Plasma data locations |
| Dynamic MD3 internals | required through MeoUI | never forced into third-party QML |
| Outer Meo frame | required/Adaptive by declaration | Native in current installations; version-pinned adapter source ready, pending package and live acceptance |
| Desktop add / move / resize / configure / multi-screen persistence | Plasma containment | Plasma containment |
| Lock screen | reviewed Meo adapter only | prohibited |

Validation must cover a first-party Meo applet and installed Plasma packages
from both a system data location and a user data location. The runtime matrix
also requires one normal desktop, mixed-DPI multi-screen placement, a package
refresh after installation/removal, and a proof that generic Plasma packages
are excluded from every lock-screen catalog. Building or offscreen QML checks
do not substitute for live Plasma acceptance.
