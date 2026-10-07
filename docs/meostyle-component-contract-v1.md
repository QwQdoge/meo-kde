# MeoStyle cross-renderer component contract v1

Status: implementation contract for MeoUI QML and MeoStyle Qt Widgets.

This document closes the first MeoStyle v2 source-of-truth ambiguity for the high-impact controls. It does not make Qt Widgets and QML share an implementation. It makes both renderers consume the same named design contract.

## 1. Source of truth

### Metrics

`Meo::DesignTokens` in the MeoUI native runtime is the canonical density-independent metric source.

- MeoUI QML reads the same runtime through the `MeoTokens` singleton.
- `MeoTheme.metricToken(name, fallback)` is a handoff-safe fallback boundary, not a second metric authority.
- MeoStyle links the token runtime and consumes `Meo::DesignTokens` directly.
- Application-specific patches must not duplicate these values unless the upstream API makes token consumption impossible; such exceptions must be documented.

Canonical v1 values currently used by the contracts below:

| Token | Value |
| --- | ---: |
| `controlHeight` | 40 dp |
| `controlRadius` | 12 dp |
| `controlPressedRadius` | 8 dp |
| `focusRingWidth` | 2 dp |
| `iconSizeS` | 18 dp |
| `iconSizeM` | 24 dp |
| `space2` | 2 dp |
| `space4` | 4 dp |
| `space8` | 8 dp |
| `space12` | 12 dp |
| `space16` | 16 dp |
| `space24` | 24 dp |
| `space32` | 32 dp |
| `shapeExtraSmall` | 4 dp |
| `shapeSmall` | 8 dp |
| `shapeMedium` | 12 dp |
| `shapeLarge` | 16 dp |
| `shapeLargeIncreased` | 20 dp |
| hover state opacity | 0.08 |
| focus state opacity | 0.10 |
| pressed state opacity | 0.10 |

### Colour

Colour remains semantic and live rather than being frozen into a second native palette.

- QML uses the active Meo semantic colour scheme.
- MeoStyle maps those semantics through the active `QPalette` supplied by the KDE platform theme.
- Accent, light/dark and accessibility-driven palette changes must therefore remain live.
- A control contract names roles and relationships; it must not copy a static purple palette into native code.

### Directionality and accessibility

Geometry defined as leading/trailing must mirror in RTL. Native code should use `QStyle::visualRect()` or equivalent direction-aware geometry instead of manually swapping only selected widgets.

MeoStyle continues to delegate keyboard handling, mnemonics, accessibility semantics, application behavior and uncovered hit-testing to Qt/Breeze unless a Meo geometry override requires a matching native override.

---

## 2. Button contract

Applies to the standard Meo `QPushButton` path and the corresponding compact QML button size.

### Geometry

- Minimum container height: `controlHeight` = 40 dp.
- Visible container is pill-shaped at rest; radius is half of the rendered height.
- Pressed shape contracts toward `controlPressedRadius` while never exceeding the available half-height.
- Content rect horizontal inset: `space16` = 16 dp on both sides.
- Content rect vertical inset: `space4` = 4 dp.
- Icon/text placement must fit inside this Meo-owned content rect; the base style may not redefine visible padding for a completed button path.
- Focus ring follows the same outer container geometry and uses the shared focus treatment.

### Variants

- Filled: primary/accent container, contrasting on-primary content.
- Tonal: tonal container with normal semantic content.
- Text/flat: transparent at rest; state layer appears for hover/press/focus.
- Default button maps to Filled unless an explicit Meo variant overrides it.

### States

Enabled controls use the shared hover/focus/pressed state opacities. Disabled controls use disabled semantic palette roles and must not display an active state layer.

### Native completion condition

`QPushButton` is not complete until `CE_PushButtonLabel` owns icon/text spacing and label placement. Owning only the background and outer content rect is an intermediate state.

---

## 3. Text-field contract

Applies to standard single-line fields and the explicit `meo.role=search` role.

### Geometry

- Minimum height: `controlHeight` = 40 dp.
- Standard field radius: `controlRadius` = 12 dp.
- Standard horizontal content inset: `space12` = 12 dp.
- Search-field horizontal content inset: `space16` = 16 dp.
- Vertical content inset: `space4` = 4 dp.
- Search-field visible container is pill-shaped using half of the rendered height.

### Behavior boundary

Qt continues to own text editing, selection, IME, cursor behavior, password behavior, undo/redo and accessibility semantics.

Leading/trailing `QLineEdit` actions, including clear/password actions, must remain functional. Their final visible geometry is not considered complete until verified against the Meo content rect instead of accidentally overlapping it.

---

## 4. Menu contract

Meo menus must not be "Breeze content inside a rounded Meo surface". The visible row layout is a cross-renderer contract.

### Surface

Standard QML menus and context menus share the same row model but have distinct surface treatment.

For the current MeoStyle context-menu-like native treatment:

- outer horizontal/vertical native menu margin: `space4` = 4 dp;
- surface radius: `shapeLargeIncreased` = 20 dp;
- ordinary item minimum height: 48 dp (`controlHeight + space8`);
- plain separator breathing room: 8 dp;
- item state surface inset: `space2` = 2 dp;
- item state radius: `shapeLarge` = 16 dp for the native context-menu treatment.

QML `MeoMenu` remains the detailed reference for its two public surface styles:

- standard menu padding: 8 dp;
- horizontal surface inset: 4 dp;
- ordinary item height: 48 dp;
- supporting-text item height: 64 dp;
- standard item radius: 4 dp, selected radius 12 dp;
- context item radius: 16 dp;
- context surface radius: 20 dp;
- standard surface radius: 16 dp.

### Row columns

A normal row is direction-aware and contains, in logical order:

1. leading check/icon region;
2. primary text region, optionally with supporting text;
3. shortcut/trailing-text region;
4. submenu/trailing-icon region.

QML currently uses these row metrics as the visual reference:

- row left/right content inset inside the item surface: 12 dp;
- inter-column spacing: 12 dp;
- leading icon allocation: 24 dp;
- rendered leading icon: 20 dp;
- trailing row internal spacing: 8 dp;
- rendered submenu/trailing icon: 20 dp.

MeoStyle should translate these into native `QStyleOptionMenuItem` geometry while preserving Qt mnemonic, shortcut, checkable, submenu, enabled/disabled and RTL behavior.

### Sections and separators

- Empty native separators are visual breathing room, not an extra Breeze rule.
- Labelled separators/sections keep their text and semantic hierarchy.
- The native painter must not erase application-supplied section labels.

### Native completion condition

The menu family is complete only when `CE_MenuItem` paints the visible check/icon/text/shortcut/submenu columns itself. Delegating those visible columns back to Breeze is explicitly an intermediate state.

---

## 5. Current implementation mapping

At the time this contract was written:

- MeoStyle owns outer button, line-edit, menu and several complex-control surfaces.
- MeoStyle v2 geometry hooks own push-button content, line-edit content, checkbox/radio label+indicator geometry, combo-box edit/arrow regions, split-tool-button regions and slider groove/handle geometry.
- Geometry regression tests cover the token relationship and RTL mirroring for the new v2 hooks.
- `CE_PushButtonLabel`, `CE_MenuItem` content columns and parts of tool-button label layout still delegate visible content to the base style and therefore remain unfinished.

This mapping is descriptive, not a permanent exception. The roadmap remains authoritative for what still needs implementation and acceptance.

## 6. Change rule

Changing a number in only MeoStyle or only a QML component is not a design-system change.

For a deliberate contract change:

1. update/add the named native token when the metric is component-independent;
2. update the QML consumer/fallback if required;
3. update the MeoStyle consumer;
4. update geometry/visual tests;
5. update this contract when the component relationship changes;
6. run the relevant QML and native validation paths.
