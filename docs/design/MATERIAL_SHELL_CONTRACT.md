# Material shell visual contract

Meo Desktop is a **Material 3 / Material 3 Expressive** desktop shell.  MeoUI
is the design-system authority; KDE/Plasma remains the behavior and data
authority wherever a native model, applet, task manager, menu, or platform
service already exists.

## Reference hierarchy

1. **MeoUI + Material 3** are normative for color roles, shape tokens, state
   layers, typography, accessibility, and reduced-motion behavior.
2. **Caelestia** is a visual reference for compact shell composition, tonal
   popouts, layered large-radius surfaces, and expressive spatial motion.
3. **end-4 / illogical-impulse** is a visual reference for Material You
   density, dynamic color, Material Symbols, pill controls, shape morphing,
   quick controls, and responsive side panels.

Reference shells are inspiration, not a second design system.  New Meo
components must not copy their private service/model code or introduce a
Caelestia/end-4-specific token.  The one deliberate source-reuse exception is
the separately documented GPL session-lock implementation in
`docs/LOCKSCREEN.md`.

## Required visual rules

- **One color authority.** Product QML uses MeoTheme semantic roles.  KDE accent
  and light/dark state are converted into a complete Material role table by
  MeoShellTheme; shell surfaces do not invent local RGB palettes.
- **Tonal hierarchy before glass.** Base shell surfaces use
  `surfaceContainerLow/Container/High` according to hierarchy.  Optional
  translucency may reduce surface alpha, but blur/transparency is not the
  primary way to communicate elevation.
- **Semantic shapes.** Shell geometry maps to MeoUI semantic radius roles.
  Large popouts use large/extra-large silhouettes; compact triggers and quick
  controls may use full/pill rounding.
- **One interaction language.** Hover, focus, press, drag, and ripple states
  come from MeoStateLayer.  Compact shell triggers use ShellTriggerSurface
  rather than ad-hoc hover rectangles.
- **Expressive spatial motion, calm effects.** MeoShellTheme enables the M3
  Expressive spatial scheme.  Position/scale/bounds changes may use the shared
  spring/reveal primitives; opacity/color effects remain critically damped.
  Reduced motion must collapse these transitions through MeoTheme.
- **No per-feature animation inventions.** Popups, launchers, page pushes,
  quick settings, top-bar triggers, menus, and cards reuse MeoUI motion
  primitives/tokens.
- **Native behavior stays native.** Plasma Kickoff/KRunner models, Global Menu,
  StatusNotifier items, task managers, and Qt menu actions retain KDE behavior.
  Meo replaces presentation through MeoUI, QStyle, or Plasma Style assets.

## Shell audit matrix

| Surface | Material contract | Reference-shell alignment |
| --- | --- | --- |
| Theme bridge | Dynamic HCT/Material role table; expressive + reduced-motion bridge | Caelestia/end-4 dynamic tonal palettes |
| Top bar | Quiet-at-rest trigger, tonal active state, shared state layer/motion | Compact Caelestia/end-4 panel density |
| Quick Settings | MeoQuickSettingsTile, MeoQuickControlSlider, responsive grid, tonal popup | end-4 quick controls + Caelestia popout hierarchy |
| Time / notifications | MeoStatusCenter, Material typography, tonal notification cards | Caelestia sidebar/card hierarchy |
| Launcher / search | MeoMotionPopup, MeoSearchBar, MeoAppGridItem, MeoContextMenu, loading feedback | Caelestia compact launcher + end-4 expressive search |
| Context / app menus | Shared MeoContextMenu plus native Qt QMenu Meo QStyle | Rounded segmented action surfaces |
| Dock / tasks | Native Plasma task model with Meo task frames and semantic state colors | Compact floating-shell treatment without replacing task behavior |
| Session lock | Meo Material roles/typography over documented pinned GPL lock implementation | Caelestia motion/layout lineage, Meo visual identity |
| Qt Widgets apps | Meo QStyle consumes shared DesignTokens and live QPalette roles | Same Material language outside QML |
| Plasma-owned delegates | Meo Plasma Style view/menu/task SVG states | Avoids visual fallback to Breeze while preserving Plasma behavior |

## Intentional desktop adaptations

Material touch guidance is not copied mechanically onto a pointer-first
desktop.  The top bar is intentionally 32 px high and some compact targets are
smaller than mobile touch targets, matching the information density of
Caelestia/end-4 while retaining keyboard focus and accessibility semantics.
Large interactive surfaces (quick settings, launcher, dialogs) keep the roomier
Material geometry.

Likewise, Meo does not make every surface acrylic.  Caelestia and end-4 use
blur effectively, but Meo keeps tonal containers and elevation readable when
transparency is disabled or unsupported.

## Regression rule

A new shell surface is not considered visually integrated if it introduces a
literal product color, a private motion curve/duration, a duplicate control
implementation where MeoUI already has one, or a KDE behavior fork solely to
change appearance.  CI source-contract tests cover the high-frequency shell
surfaces so future polish cannot silently drift back toward a mixed
Breeze/Material visual language.
