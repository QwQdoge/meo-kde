# Meo Application Chrome roadmap

## Chosen implementation route

Use **MeoStyle for standard Qt control rendering** and use **small, maintainable distro patches only for the chrome/layout of a curated set of core KDE applications**.

Start with **Dolphin as the pilot**.

This is intentionally not a global runtime layout-rewriting layer, not a full application fork, and not an attempt to force every KDE application into an Android tablet layout.

The goal is to preserve mature KDE backends and behavior while changing the parts that most strongly define the visual hierarchy of an application.

```text
Upstream KDE application
        |
        +--> existing backend/model/actions/KIO/etc.
        |
        +--> MeoStyle
        |      standard Qt control appearance
        |
        +--> small Meo chrome patch
               top bar / toolbar composition
               navigation/sidebar presentation
               spacing / margins / pane structure
               action placement / overflow
```

---

## Why this route

QStyle can make standard controls look like Meo, but QStyle cannot reliably turn a traditional desktop application layout into a tablet-style Material 3 application layout.

Examples that QStyle can solve:

- buttons;
- tool buttons;
- text fields;
- combo boxes;
- menus;
- sliders;
- tabs;
- scroll bars;
- checkboxes/radio buttons;
- standard list/tree selection.

Examples that QStyle cannot safely restructure globally:

- where a toolbar sits;
- whether actions are grouped into a top app bar;
- sidebar width and hierarchy;
- navigation rail/drawer structure;
- pane spacing and margins;
- which actions are primary versus overflow;
- whether a status bar should remain visible;
- page-level card/container composition.

Attempting to solve those globally with event filters, widget reparenting, runtime object-name heuristics, or broad monkey-patching would be fragile and difficult to maintain.

A small source/package patch is more predictable for the few core applications that matter most to the Meo Desktop experience.

---

## Design target

The target is **desktop-adapted Material 3 / Pixel tablet visual hierarchy**, not literal Android dimensions.

Keep:

- M3 hierarchy;
- rounded container language;
- expressive state treatment;
- clear primary/secondary actions;
- adaptive two-pane ideas where useful;
- strong spacing rhythm;
- Meo typography, icons, colors and shapes.

Adapt for desktop:

- slightly denser control heights;
- smaller page margins;
- mouse-friendly rather than touch-only spacing;
- keyboard shortcuts and menu access remain first-class;
- preserve desktop multi-window workflows;
- preserve power-user features rather than hiding them behind mobile assumptions.

Example density translation:

```text
Tablet-style source      Meo Desktop target
56 dp field               44-48 px
48 dp button              40-44 px
24 dp page margin         16-20 px
80 dp nav rail            64-72 px
24 dp card radius         about 20 px
```

Exact values belong in the shared Meo design contract rather than this roadmap.

---

# Scope policy

## Tier 1 — native Meo applications

Use MeoUI directly.

Examples:

- Meo Settings;
- Installer;
- OmniStore;
- Meo Account;
- Meo AI;
- Launcher;
- Quick Settings;
- System Monitor / Performance Manager;
- Login and lock screen;
- notifications and other Meo shell surfaces.

These can follow the Meo tablet/M3 layout language most closely.

## Tier 2 — core KDE applications

Use:

```text
MeoStyle + small chrome/layout patch
```

Initial candidates:

1. Dolphin — pilot and highest priority;
2. Ark — only if layout inconsistencies remain after MeoStyle;
3. Okular — only if high-impact chrome remains inconsistent;
4. Kate/KWrite — preserve developer/editor density; patch only obvious shell/chrome mismatches;
5. Konsole — likely MeoStyle plus minimal chrome changes only.

Do not patch every KDE application merely for uniformity.

## Tier 3 — normal Qt/KDE applications

Use MeoStyle only.

If standard controls look correct, leave the application structure upstream.

## Tier 4 — custom-painted third-party applications

Best-effort only.

Do not carry large patches unless the application is strategically important to MeoArch.

---

# Patch rules

Every Meo application-chrome patch must satisfy all of these:

- [ ] layout/presentation only;
- [ ] no application business-logic rewrite;
- [ ] no replacement of mature backend/model code;
- [ ] no duplicated KIO/network/storage/session functionality;
- [ ] small enough to review against upstream releases;
- [ ] separable from MeoStyle changes;
- [ ] reversible in packaging;
- [ ] maintain keyboard navigation and shortcuts;
- [ ] maintain accessibility;
- [ ] maintain upstream feature availability unless removal is explicitly part of Meo product policy.

Prefer moving or regrouping existing actions over reimplementing actions.

Prefer existing KDE/Qt APIs over private widget-tree hacks.

Avoid object-name heuristics unless upstream exposes no stable API and the exception is documented.

---

# Phase 0 — contract before patching

Do not start the Dolphin layout patch until the high-impact Meo visual contract is stable enough to compare against.

Required inputs:

- [ ] button contract;
- [ ] tool-button contract;
- [ ] text-field/search contract;
- [ ] menu contract;
- [ ] surface/container roles;
- [ ] standard page margins;
- [ ] sidebar/navigation widths;
- [ ] top-app-bar height and spacing;
- [ ] icon sizes;
- [ ] typography roles;
- [ ] desktop density rules.

The MeoStyle roadmap owns standard Qt control rendering. This document owns page/chrome composition.

---

# Phase 1 — Dolphin pilot

Dolphin is the first application because it is highly visible, heavily used, and already provides mature file-management behavior that Meo should not recreate.

## Preserve upstream Dolphin capability

Do not replace:

- KIO;
- file models;
- SMB/SFTP/MTP integration;
- trash;
- thumbnailing;
- drag/drop;
- file associations;
- permissions;
- tabs;
- split view;
- search/filter behavior;
- keyboard shortcuts;
- context actions;
- service-menu support.

## First-pass chrome goals

- [ ] identify the current top-level widget/layout structure;
- [ ] identify toolbar, location/breadcrumb, tab bar, Places panel and status bar ownership;
- [ ] record which pieces are public/stable enough to patch cleanly;
- [ ] define a Meo desktop top-app-bar composition using existing Dolphin actions;
- [ ] keep navigation/back/forward/up behavior intact;
- [ ] keep location/breadcrumb editing behavior intact;
- [ ] move low-priority actions into existing overflow/menu paths rather than duplicating actions;
- [ ] tune toolbar/top-bar spacing to the Meo desktop contract;
- [ ] tune Places/sidebar width, row spacing and surrounding margins;
- [ ] tune content-pane outer margins only if they do not break compact/icon/details views;
- [ ] keep split view usable;
- [ ] keep tab behavior usable;
- [ ] avoid permanent large card containers around file content if they reduce usable file-view space;
- [ ] decide whether the traditional status bar remains, becomes optional, or is visually minimized;
- [ ] verify all standard controls are still rendered by MeoStyle rather than duplicated custom drawing.

## Dolphin visual target

The target is closer to:

```text
+-------------------------------------------------------------+
|  <  >   location / breadcrumb                search     ... |
+-------------+-----------------------------------------------+
|             |                                               |
|  Places     |                 File content                  |
|             |                                               |
|  Home       |                                               |
|  Documents  |                                               |
|  Downloads  |                                               |
|             |                                               |
+-------------+-----------------------------------------------+
```

with Meo/M3 hierarchy, spacing, surfaces and controls.

It does **not** need to imitate an Android file picker literally.

## Dolphin acceptance

- [ ] no obvious Breeze control styling in covered standard controls;
- [ ] top-level hierarchy reads as Meo rather than default Dolphin/Breeze;
- [ ] file-view density remains practical for mouse/keyboard use;
- [ ] split view works;
- [ ] tabs work;
- [ ] all primary navigation actions work;
- [ ] location edit/breadcrumb works;
- [ ] search/filter works;
- [ ] menus/context menus work;
- [ ] drag/drop works;
- [ ] keyboard shortcuts remain functional;
- [ ] compact/icon/details views remain usable;
- [ ] light/dark and accent changes remain visually coherent;
- [ ] patch is still small and understandable against upstream Dolphin.

Do not progress to a second application until the Dolphin patch demonstrates that this maintenance model is viable.

---

# Phase 2 — package/maintenance model

The preferred maintenance model is a small patch series applied by the MeoArch package recipe rather than a long-lived full fork.

Example conceptual structure:

```text
packaging/dolphin/
  PKGBUILD or package recipe
  patches/
    0001-meo-chrome-layout.patch
    0002-meo-desktop-density.patch
```

Exact placement should follow the repository's existing packaging conventions.

For each patched application, record:

- upstream package/version;
- patch files;
- files touched;
- why each patch is necessary;
- upstream APIs relied upon;
- known conflicts;
- last rebase/test date;
- condition for dropping the patch.

A patch should be dropped when MeoStyle or upstream APIs can provide the same result without application-specific changes.

---

# Phase 3 — decide whether more applications need patches

After Dolphin is complete, test other KDE applications with MeoStyle v2 before adding more patches.

## Ark

Patch only if the main window hierarchy remains obviously inconsistent after MeoStyle.

Likely scope:

- toolbar composition;
- spacing;
- action grouping.

## Okular

Preserve document-view density and side panels.

Patch only high-impact chrome; do not make reading space smaller merely to imitate tablet cards.

## Kate / KWrite

Treat as productivity/developer applications.

Do not force large tablet spacing. Prefer MeoStyle plus minimal top-level visual cleanup.

## Konsole

Prefer no source patch unless the application chrome remains strongly inconsistent after MeoStyle.

---

# Explicitly rejected approaches

## Rejected: globally rewriting widget layouts at runtime

Do not implement a process-wide layer that scans widget trees and reparents toolbars/sidebar/content based on class names or object names.

Reasons:

- fragile across KDE versions;
- hard to test;
- application-specific layouts differ;
- can break action ownership, focus and accessibility;
- debugging failures becomes difficult.

## Rejected: full Meo forks of Dolphin/Kate/Ark/etc.

Do not maintain complete application forks solely for visual changes.

## Rejected: forcing mobile layout dimensions literally

Do not copy tablet/touch spacing without desktop density adaptation.

## Rejected: solving page layout inside QStyle

QStyle owns control rendering/geometry, not arbitrary application composition.

---

# Relationship to MeoStyle v2

`docs/meostyle-v2-roadmap.md` and this document are complementary.

```text
MeoStyle v2
  "Does this QPushButton/QMenu/QLineEdit look and behave like Meo?"

Meo Application Chrome
  "Does this application's page hierarchy and chrome feel like Meo?"
```

A Dolphin patch must not manually redraw a standard button just because it can. If MeoStyle can own that control generically, fix MeoStyle instead.

Likewise, MeoStyle must not attempt to move Dolphin's toolbar/sidebar just because the layout is not M3-like. That belongs here.

---

# First implementation queue

1. [ ] Finish the shared desktop density + high-impact component contract.
2. [ ] Inspect Dolphin's current main-window/layout implementation at the upstream version packaged by MeoArch.
3. [ ] Produce a short structure map: toolbar, location bar, tab bar, Places panel, content view, status bar.
4. [ ] Identify the smallest stable source points required for a Meo chrome patch.
5. [ ] Implement only top-app-bar/toolbar composition and spacing first.
6. [ ] Validate navigation, location editing, search, menus and shortcuts.
7. [ ] Implement sidebar/Places presentation adjustments.
8. [ ] Validate icon/compact/details/split/tab views.
9. [ ] Package the patch as a small reproducible patch series.
10. [ ] Compare maintenance cost and visual gain before approving patches for any second KDE application.

---

# Completion definition

This roadmap succeeds if MeoArch can ship Dolphin with:

- upstream file-management capability intact;
- MeoStyle controlling standard Qt components;
- a small and maintainable Meo chrome/layout patch;
- a page hierarchy that visually belongs to the Meo desktop;
- no full Dolphin fork;
- no fragile global runtime widget-tree rewrite.

If the Dolphin pilot cannot meet those conditions with a reasonably small patch, stop and reassess before extending the strategy to other applications.
