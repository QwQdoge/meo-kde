# MeoStyle cross-renderer component contract v1

Status: implementation contract for MeoUI QML and MeoStyle Qt Widgets.

This document closes the first MeoStyle v2 source-of-truth ambiguity for the high-impact controls. It does not make Qt Widgets and QML share an implementation. It makes both renderers consume the same named design contract.

## 1. Source of truth

### Metrics

`Meo::DesignTokens` in the MeoUI native runtime is the canonical density-independent metric source.

- MeoUI QML reads the same runtime through the `MeoTokens` singleton.
- `MeoTheme.metricToken(name, fallback)` is a handoff-safe fallback boundary, not a second metric authority.
- MeoStyle includes the pure QtCore `meodesigntokens.h` contract and consumes `Meo::DesignTokens` directly.
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
- The installed plugin uses `MeoStyleContent` to own push-button, menu-item and tool-button content. The base class retains compatibility paths for controls not handled by this renderer.
- Checkbox/radio full-control and label painting now use Meo indicator/content rectangles, including icon placement, multiline mnemonic text and RTL. Their size hints add `space4` on both outer edges, `iconSizeS` for the indicator and `space8` before label content, with a `controlHeight` minimum.
- Combo labels use the Meo edit-field rectangle, leading icon and literal current text. Editable child line edits retain Qt text editing/IME ownership. Combo height is the larger of `controlHeight` and content height plus `space8`; width reserves `space12 + space8 + controlHeight` for content insets and arrow region. These size hints do not inherit base-style visible geometry.
- Focus, disabled and checked/indeterminate indicator painting remains with the Meo primitive renderer; Qt owns keyboard interaction and accessibility. This source mapping does not claim real-application visual acceptance or completion of the remaining roadmap.

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

### Content size ownership

Buttons, tool buttons, check/radio controls, combo boxes, text/search fields and menu items compute their size from the shared tokens and application-provided content rather than taking a base-style size as a minimum. Menu rows reserve one aligned leading column when the menu contains checkable actions; default actions use a bold font for both measurement and painting. Push-button menus reserve a trailing Meo chevron in both LTR and RTL. Qt still owns action triggering and popup behavior.

### Native tab contract

Tab content uses `space12` at each end, `space4` vertically and `space8` between icons, text and application-supplied tab buttons, with a `controlHeight` minimum. `CT_TabBarTab` measures the option itself because QTabBar includes frame padding in the supplied content size. Text/icons and button reservations share one coordinate system, rotated for west/east tabs and mirrored for RTL. The Meo renderer owns mnemonic labels and the close glyph; actual tab buttons, switching, dragging, shortcuts and accessibility stay with Qt. No base-style selected-tab shifts or overlap are added. All four tab edges retain the Meo selection indicator and focus treatment.

### Native item-view contract

Standard styled delegates use Meo-owned text/editor, decoration and check rectangles, `space12` horizontal and `space4` vertical insets, `space8` internal gaps, `iconSizeS` check indicators and a `controlHeight` minimum. Left/right/top/bottom decorations, wrapping, elision and RTL share the same layout for sizing and drawing. Fonts, foreground/background brushes, alternating rows, decoration sizes, alignment and explicit model size hints remain application data. Meo selection/focus painting stays tonal, with readable Text-role content. Qt still owns the models, editing, check-state events and accessibility. Application delegates that bypass QStyle remain a compatibility boundary rather than an invitation to rewrite their models.

### Native spin and scroll contract

Spin boxes share the text-field surface and `controlHeight` minimum, with a `space32` trailing button column split equally between up/down, `space12` leading and `space8` trailing editor insets and `space4` vertical insets. NoButtons removes the column; arrows and plus/minus symbols honor individual step availability. Qt owns numeric/date editing, validation, keyboard and wheel behavior.

Scroll bars use a `space12 + space2` extent, same-sized end buttons and a `space32` minimum thumb clamped to the available groove. Thumb size follows the actual page/range using wide arithmetic, and an empty range fills the groove. Orientation, inversion and RTL use Qt value mapping. Meo uses non-transient geometry so platform-specific transient behavior cannot silently change the painted/hit-tested layout. Spin/scroll/combo/tool hit testing reads the same owned subcontrol rectangles as painting; Qt retains action and drag handling.

### Native headers and tree branches

Header sections use the Window surface with Meo hover/press/selection/focus treatment, a `controlHeight` minimum, `space12` horizontal and `space4` vertical content insets. Leading icons and trailing sort chevrons use `iconSizeS` and `space8` gaps. Sort reservation, size measurement and painting share the same contract; RTL mirrors the layout, and Qt HeaderV2 text elision remains application-controlled. Tree indentation is `space24`; expandable branches use a Meo chevron (down when open, direction-aware when closed), with no inherited dotted connectors or boxed plus glyphs. Qt owns sort actions, column dragging/resizing, and expansion/hit behavior.

### Native group-box contract

Group boxes use `space16` outer content padding, a title row at least `space24` high and `space12` between title and contents. Check indicators use `iconSizeS` with a `space8` title gap. Title alignment and RTL operate on the whole text/check group. Untitled boxes omit the title row and gap; Flat omits the rounded tonal container. The same layout owns content margins, label/check rectangles and hit tests. Qt retains mnemonics, keyboard toggling, child enablement and accessibility, while application title colors remain respected. No base-style external layout-item margin is added.

### Native toolbar and menu-bar contract

Toolbar and menu-bar surfaces use the semantic Window brush without a base-style bevel or separator. Toolbars use `space4` item margins/spacing, `space12` handle/separator extents, `space24` overflow extent and `iconSizeS` default icons. Application-supplied layout margins remain authoritative (including Dolphin's chrome patch); the movable handle mirrors in RTL and uses Meo dots. Separators are a single quiet rule rather than a platform bevel.

Menu-bar items use a `controlHeight` minimum, `space12` horizontal and `space4` vertical insets. Qt's icon-in-place-of-title presentation and mnemonic visibility remain intact; Meo owns text/icon and hover/pressed/selected/focus rendering. Qt retains menu opening, shortcuts, toolbar action ownership, docking, dragging and overflow behavior.

### Native progress contract

Meo owns full/groove/content/label rendering and their rectangles. Determinate values use wide range arithmetic, horizontal RTL/inversion and bottom-to-top vertical fill by default, with inversion supported. Text follows the supplied format/alignment and vertical text direction; text over the filled region uses HighlightedText and the rest uses Text. Progress without visible text uses `space8` thickness; visible text uses at least `space24` and font height plus `space8`.

Busy progress follows MeoUI's 1750ms two-line linear clock: emphasized-accelerate cubic `(0.3,0,0.8,0.15)`, first head/tail delays 0/250ms with 1000ms duration, second delays 650/900ms with 850ms duration. The native animation manager only ticks while a real visible, enabled busy QProgressBar requires repainting. Hidden/disabled/determinate/destroyed/unpolished bars stop ticking. Event filtering never consumes input.

Qt 6.12+ motion preference, the platform's zero widget-animation duration, and `meo.reducedMotion=true` on the application or progress widget suppress motion. Reduced motion uses static phase0.75, matching MeoUI. On older Qt, only the platform style-duration policy and explicit Meo property are available; no system preference is guessed. Direct style painting without a live QProgressBar also uses the static busy representation. This is busy-progress infrastructure; hover/press/focus/check animations remain separate work.

### Slider details and toolbar overflow

Slider ticks are Meo dots using the same value-to-position mapping as the handle, honoring above/below/both, orientation and upsideDown. Automatic/explicit tick intervals are thinned to at most one tick per `space8` of travel for extreme ranges; endpoints stay represented. Tick math uses wide integers. The control has a `controlHeight` minimum cross-axis size. `SC_SliderGroove` exposes the full drag geometry because Qt subtracts one handle length while mapping positions to values; only painting applies the half-handle end inset.

Toolbar overflow uses a Meo double-chevron icon engine in both orientations, with RTL and disabled modes. The retained icon reads its owning widget's current palette/direction when painted, avoiding a stale light/dark bitmap after theme changes. Qt retains the extension button, action ownership and overflow popup behavior.

## Native state motion

MeoUI's pure design token contract supplies critical effects damping/stiffness
(1.0/1600), expressive fast spatial damping/stiffness (0.6/800), and a 500 ms
maximum settling time. The QML values are unchanged. Native state layers and
focus use the effects spring; button pressed shape, check/radio selection and
slider response use the spatial spring. Transitions retarget from their sampled
current value; opacity/selection fractions are clamped to their physical range.

The engine lazily tracks painted widget channels, bounds menu-row state to 256
channels per widget, and stops its timer when no visible transition or busy
progress needs it. Hide, disable, unpolish and destruction stop animation.
Platform animation disable, Qt 6.12+ reduced motion and `meo.reducedMotion`
on the application/widget make state changes immediate. Item-view checks stay
immediate because a screen rectangle is not a stable model identity. Input,
actions, focus ownership and accessibility remain Qt's responsibility.

Tooltip surfaces use ToolTipBase/ToolTipText, `space8` padding and `shapeSmall`
radius, including the native tooltip mask. Qt retains text/timing/placement.
Status bars use Window with no per-item bevel. Dialog button-box ordering is
platform-owned while its child button geometry is Meo-owned.
