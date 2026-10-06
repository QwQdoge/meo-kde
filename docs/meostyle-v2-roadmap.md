# MeoStyle v2 roadmap

## Goal

Make standard Qt Widgets and KDE applications visually belong to Meo Desktop without requiring those applications to import MeoUI, without rewriting mature KDE applications, and without maintaining full application forks.

The target is visual and interaction consistency, not implementation identity:

```text
Meo Design Contract
        |
        +--> MeoUI renderer      (first-party QML applications)
        |
        +--> MeoStyle renderer   (Qt Widgets / standard KDE applications)
        |
        +--> Plasma integration  (shell-specific surfaces)
```

A covered Qt control should no longer look like Breeze with different colors. MeoStyle should own the visible geometry and painting for that control. Breeze may remain underneath for behavior, platform integration, accessibility, keyboard handling, application quirks, and uncovered fallbacks.

## Success definition

For covered controls in Dolphin, Kate, Ark, Okular, Konsole settings, KCalc and similar standard KDE/Qt applications:

- a static screenshot should not immediately read as Breeze;
- control height, padding, icon placement, radius and state treatment should match the Meo visual contract;
- light/dark and dynamic accent changes must continue to work;
- keyboard navigation, mnemonics, RTL, accessibility and standard Qt behavior must remain functional;
- no application-specific fork should be required for standard controls.

MeoStyle does **not** need to turn Qt Widgets into QML MeoUI components. It is a separate renderer of the same design system.

---

## Current state

MeoStyle is already a `QProxyStyle` and prefers Breeze as its platform base. It already paints a number of Meo-like surfaces and states.

The main remaining problem is that visible geometry and content layout are still frequently inherited from the base style. Examples include button label layout, menu icon/check/text/submenu geometry, item-view content layout, many pixel metrics, and complex-control subcontrols.

This produces the current result:

```text
Breeze geometry + Meo surface/color overrides
```

The v2 target is:

```text
Breeze behavior/fallback + Meo-owned visible geometry + Meo-owned painting
```

## Architecture rule

### MeoUI is not a runtime dependency of MeoStyle

MeoUI is still changing quickly. MeoStyle must not depend on unstable QML component internals.

Both implementations should consume the same stable visual contract:

```text
                 Meo Design Contract
                        |
              +---------+---------+
              |                   |
           MeoUI              MeoStyle
            QML                  C++
```

The current design documentation treats `MeoTheme.qml` as the executable source of truth while native MeoStyle code already consumes native design-token APIs. Before large-scale v2 painting work, reconcile this into one stable token contract so QML and C++ do not drift.

### Breeze boundary

Use Breeze for:

- keyboard/mnemonic behavior;
- platform-native semantics;
- accessibility behavior;
- popup positioning and hit testing where Meo does not intentionally replace it;
- application-specific compatibility;
- controls not yet implemented by MeoStyle.

Do not use Breeze to define visible geometry for controls marked complete in this roadmap.

### Do not use QSS as the primary implementation

Qt Style Sheets may be useful for isolated debugging, but they are not the MeoStyle architecture. Complex controls, KDE integration, dynamic palettes, geometry and expressive state handling remain owned by the QStyle plugin.

### Do not fork applications for standard controls

Do not create `meo-dolphin`, `meo-kate`, `meo-ark`, etc. solely to restyle standard Qt controls.

Application/package patches are a last-mile exception only when an application custom-paints UI or uses a custom delegate that bypasses QStyle.

---

# Work plan

## Phase 0 — Freeze the visual contract before repainting everything

- [ ] Inventory the token values currently used by MeoUI and native `meotokens`.
- [ ] Decide the stable cross-renderer token contract and ownership.
- [ ] Remove duplicate/hard-coded component geometry where a named token should exist.
- [ ] Define component-independent semantic tokens for:
  - [ ] color roles;
  - [ ] surface/container roles;
  - [ ] typography roles;
  - [ ] spacing;
  - [ ] icon sizes;
  - [ ] control heights;
  - [ ] corner shapes/radii;
  - [ ] focus treatment;
  - [ ] hover/pressed/focus/disabled state opacity;
  - [ ] motion durations/easing for the later animation phase.
- [ ] Define a small set of component contracts that MeoUI and MeoStyle both implement.
- [ ] Update `docs/design-system.md` after the contract is settled so it no longer implies two competing sources of truth.

### Initial component contracts

Record exact values/roles for at least:

- [ ] Filled button
- [ ] Tonal button
- [ ] Text button
- [ ] Icon button
- [ ] Text field
- [ ] Search field
- [ ] Combo box
- [ ] Checkbox
- [ ] Radio button
- [ ] Menu surface
- [ ] Menu item
- [ ] Tab
- [ ] List/tree selection
- [ ] Scroll bar

Do not begin animation work before these static contracts are stable enough to compare visually.

---

## Phase 1 — Make MeoStyle own geometry

The largest v2 change is not more colors; it is geometry ownership.

- [ ] Expand `pixelMetric()` coverage for all v2 controls.
- [ ] Add/expand `sizeFromContents()` so component sizes follow Meo contracts instead of Breeze defaults.
- [ ] Implement `subElementRect()` where text/icon/content padding must be Meo-owned.
- [ ] Implement `subControlRect()` for combo boxes, spin boxes, sliders, scroll bars and other complex controls.
- [ ] Add `styleHint()` overrides only where required by the Meo interaction contract.
- [ ] Keep hit testing and platform behavior delegated where custom geometry does not require replacement.
- [ ] Add reusable native helpers for icon/text layout, state layers, focus rings, check marks, chevrons and rounded surfaces.
- [ ] Add regression tests that fail when completed controls fall back to visible Breeze geometry.

### Gallery

- [ ] Expand the existing native application-style gallery into a visual/behavior test surface containing every supported control and state.
- [ ] Include normal, hover, pressed, focused, checked, indeterminate and disabled states.
- [ ] Include both light and dark palettes.
- [ ] Include at least one dynamic accent repaint test.
- [ ] Include RTL examples.

---

## Phase 2 — High-impact controls first

These controls determine whether a KDE application still immediately looks like KDE/Breeze.

### Buttons

- [ ] `QPushButton`: own background, content rect, icon/text spacing and label painting.
- [ ] Filled variant.
- [ ] Tonal variant.
- [ ] Text/flat variant.
- [ ] Default-button mapping.
- [ ] Disabled state.
- [ ] Focus state.
- [ ] Pressed shape/state.
- [ ] Minimum height and horizontal padding from the Meo contract.
- [ ] Stop relying on Breeze for visible label geometry once compatibility tests pass.

### Tool buttons

- [ ] `QToolButton` icon-only treatment.
- [ ] Text + icon treatment.
- [ ] Auto-raise behavior without Breeze visual residue.
- [ ] Checked/selected tonal container.
- [ ] Menu-arrow geometry.

### Text fields

- [ ] `QLineEdit` geometry and padding.
- [ ] Focus treatment.
- [ ] Disabled treatment.
- [ ] Search-field role.
- [ ] Leading/trailing action geometry when actions are supplied by the application.
- [ ] Password/clear-button compatibility.

### Combo boxes

- [ ] Own frame/surface.
- [ ] Own content rect.
- [ ] Own arrow area.
- [ ] Draw Meo chevron.
- [ ] Verify editable and non-editable combos.
- [ ] Verify popup compatibility.

### Checkboxes and radios

- [ ] Indicator geometry.
- [ ] Label spacing.
- [ ] Checked/unchecked/indeterminate states.
- [ ] Hover/pressed/focus state treatment.
- [ ] RTL layout.

### Menus — priority item

Menus should stop being "Breeze content inside a Meo rounded rectangle".

- [ ] `QMenu` outer surface and padding.
- [ ] Fully own `CE_MenuItem` visible layout.
- [ ] Leading icon/check column.
- [ ] Text column.
- [ ] Shortcut column.
- [ ] Submenu arrow column.
- [ ] Meo chevron.
- [ ] Item height.
- [ ] Item radius/inset.
- [ ] Hover/pressed/focus state layer.
- [ ] Section/separator spacing.
- [ ] Checked menu item.
- [ ] Disabled menu item.
- [ ] RTL menu layout.
- [ ] `QMenuBar` geometry and state.

### Phase 2 acceptance

- [ ] Open Dolphin and inspect toolbar buttons, text fields and menus.
- [ ] Open Kate and inspect menus, toolbars and dialogs.
- [ ] Open Ark and inspect menus/dialog controls.
- [ ] A screenshot of these controls no longer looks like Breeze with rounded backgrounds.

---

## Phase 3 — Complete the application chrome

- [ ] `QTabBar` / `QTabWidget` geometry and labels.
- [ ] `QToolBar` spacing, separators and control density.
- [ ] `QScrollBar` groove, handle geometry, hover/pressed states and minimum handle size.
- [ ] `QSlider` groove, active track and handle.
- [ ] `QProgressBar` determinate state.
- [ ] `QProgressBar` indeterminate/busy state.
- [ ] `QSpinBox` / `QDoubleSpinBox` subcontrols.
- [ ] `QHeaderView` visual treatment.
- [ ] `QGroupBox` label/content spacing.
- [ ] Tooltips.
- [ ] Dialog button-box spacing/ordering compatibility.
- [ ] Status bars and separators only where visible Breeze styling remains.

---

## Phase 4 — Item views and Dolphin-heavy UI

Do not casually replace application-owned delegates. Preserve model/delegate behavior and take ownership only where QStyle has a reliable contract.

- [ ] Define Meo row/list-item height metrics.
- [ ] Define list/tree selection inset and radius.
- [ ] Define icon/text padding.
- [ ] Define focus treatment without restoring a square Breeze focus rectangle.
- [ ] Style `QListView` standard delegate paths.
- [ ] Style `QTreeView` standard delegate paths.
- [ ] Style `QTableView` standard delegate paths.
- [ ] Style branch/expand indicators where safe.
- [ ] Verify multi-selection.
- [ ] Verify drag/drop indicators.
- [ ] Verify inline rename/editing.
- [ ] Verify long/ellipsized names.
- [ ] Verify Dolphin icon, compact and details views.

If a specific application custom-paints a view and bypasses QStyle, record it under the exception policy instead of adding fragile global heuristics.

---

## Phase 5 — Expressive motion

Static geometry and state correctness come first.

After v2 static rendering is stable:

- [ ] Add a small `MeoStyleAnimationEngine` or equivalent internal state manager.
- [ ] Use `polish(QWidget *)`, `unpolish(QWidget *)` and event filtering only where required.
- [ ] Track hover transition progress.
- [ ] Track press transition progress.
- [ ] Track focus transition progress.
- [ ] Track checked-state transitions where practical.
- [ ] Support reduced-motion behavior.
- [ ] Avoid timers/animation state for controls that are not visible or do not need it.
- [ ] Verify that animation does not break application event handling.

Candidate expressive effects:

- [ ] button state-layer fade;
- [ ] button pressed shape transition;
- [ ] tool-button selection transition;
- [ ] checkbox/radio transition;
- [ ] slider handle response;
- [ ] menu hover state transition.

Do not attempt to reproduce every QML animation in Qt Widgets. Match the Meo interaction language while respecting the widget toolkit.

---

## Phase 6 — Qt Quick / Kirigami evaluation

Do this only after MeoStyle v2 is visually strong for Qt Widgets.

- [ ] Test how KDE `org.kde.desktop` Qt Quick Controls look when MeoStyle v2 is active.
- [ ] Record which standard Qt Quick controls correctly inherit the Meo appearance.
- [ ] Record Kirigami-specific components that remain visually inconsistent.
- [ ] Decide whether a dedicated Meo QQC2/Kirigami integration layer is actually needed.
- [ ] Do not globally replace `QT_QUICK_CONTROLS_STYLE` until KDE application compatibility is proven.

---

# Exception policy

Create an application-specific patch/package only when all of the following are true:

1. the visible UI is custom-painted or uses a custom delegate that bypasses QStyle;
2. the inconsistency is significant enough to hurt the Meo Desktop experience;
3. a generic QStyle fix would risk breaking unrelated applications;
4. the patch is small, reviewable and maintainable against upstream.

Track every exception with:

- application;
- affected widget/view;
- reason QStyle cannot control it;
- patch size/scope;
- upstream version tested;
- removal condition.

Do not patch application business logic merely for appearance.

---

# Packaging and activation

The preferred model remains one shared native style package/plugin, not a separate forked package for every KDE application.

- [ ] Install the Qt style plugin into the normal Qt 6 style plugin path.
- [ ] Keep `widgetStyle=Meo` as the Meo Desktop activation path.
- [ ] Preserve reversible apply/reset behavior.
- [ ] Verify newly launched Qt applications discover the plugin.
- [ ] Document whether live-running applications update palette/accent/style correctly or require restart.
- [ ] Keep LibreOffice/VCL and other non-standard toolkit boundaries documented separately.

---

# Acceptance matrix

Every major milestone should be checked in real applications, not only the gallery.

## Applications

- [ ] Dolphin
- [ ] Kate / KWrite
- [ ] Ark
- [ ] Okular
- [ ] Konsole settings/config dialogs
- [ ] KCalc
- [ ] At least one KDE application using many item views
- [ ] At least one third-party plain Qt Widgets application if available

## States

- [ ] light
- [ ] dark
- [ ] dynamic accent changed after launch where supported
- [ ] enabled
- [ ] disabled
- [ ] hover
- [ ] pressed
- [ ] keyboard focus
- [ ] checked/selected
- [ ] indeterminate where applicable
- [ ] RTL

## Display scale

Use the Meo design-system acceptance targets where practical:

- [ ] 100%
- [ ] 125%
- [ ] 150%
- [ ] 200%

At minimum, verify 100% and 200% before calling a control family complete.

---

# First implementation queue

Use this order unless a blocking compatibility bug requires otherwise:

1. [ ] Reconcile MeoUI/native token source-of-truth.
2. [ ] Write exact Button/TextField/Menu component contracts.
3. [ ] Expand MeoStyle geometry ownership infrastructure.
4. [ ] Finish `QPushButton` including content geometry and label painting.
5. [ ] Finish `QToolButton`.
6. [ ] Finish `QLineEdit` and search-field geometry.
7. [ ] Fully rewrite visible `QMenuItem` layout/painting in MeoStyle.
8. [ ] Finish `QComboBox` complex-control geometry.
9. [ ] Finish checkbox/radio label + indicator geometry.
10. [ ] Run Dolphin/Kate/Ark visual acceptance and record remaining Breeze leakage.

After these ten items, re-evaluate priorities before expanding into lower-impact controls.

---

# How to use this document

This file is an implementation roadmap, not a claim that every checkbox should be completed in one change.

For each implementation task:

1. read the relevant component contract/token definitions;
2. inspect the current MeoStyle implementation and nearest tests;
3. make one coherent control-family change;
4. add/update offscreen tests and gallery coverage;
5. run the matching native application-style test/build path;
6. when possible, validate in at least one real KDE application without restarting the live desktop session automatically;
7. check the item here only after the implementation and relevant validation are complete;
8. add a short note below if the task revealed a compatibility exception or changed the architecture.

Do not mark tasks complete merely because a rounded rectangle or color override exists. A v2 control is complete only when MeoStyle owns the visible geometry required by its Meo contract and no obvious Breeze visual layer remains in the supported standard path.

## Notes / discovered exceptions

Add dated notes here when implementation discovers something that should affect later work.

- None yet.
