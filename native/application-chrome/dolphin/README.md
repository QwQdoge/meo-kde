# Dolphin application-chrome pilot

This directory carries the small MeoArch presentation patch series for KDE Dolphin. It is intentionally separate from MeoStyle: MeoStyle owns standard Qt control rendering, while these patches may only adjust Dolphin's top-level application chrome and layout.

## Upstream baseline

- Upstream: KDE Dolphin
- Source tag: `v26.08.1`
- Meo preparation script: `setup/prepare-meo-dolphin-source.sh`

The source version is pinned so a rolling upstream branch cannot silently change the patch target. When the Arch package moves to a newer Dolphin release, update the version deliberately, run `--check-only`, inspect the upstream UI structure again, and rebase the patch series if required.

## Current structure map

The v26.08.1 main window keeps the mature file-management implementation intact:

- `DolphinMainWindow` is a `KXmlGuiWindow`.
- `DolphinTabWidget` is the central widget and owns the tab/split-view presentation path.
- `DolphinNavigatorsWidgetAction` is registered as `url_navigators` and provides the existing location/breadcrumb UI used by the toolbar.
- `src/dolphinui.rc` owns the default `mainToolBar` action composition.
- `setupDockWidgets()` owns the dock/panel setup; `PlacesPanel` is hosted in its dock rather than being part of the central file view.
- Meo does not replace KIO, file models, file views, drag/drop, tabs, split view, shortcuts, context actions, service menus, or the location editor.

## Patch 0001 — top app bar composition

`0001-meo-top-app-bar-composition.patch` changes only the default KXmlGui toolbar ordering. It makes the primary hierarchy read as:

`Back / Forward -> Location -> Search -> Split View -> View Settings -> Overflow`

`split_stash` is removed from the default toolbar because it remains available through Dolphin's View menu. No action implementation is duplicated or removed from Dolphin.

This is the first pilot patch, not a claim that the whole Dolphin roadmap is complete. Toolbar spacing/density should be supplied generically by MeoStyle where possible. Places/sidebar presentation is the next application-specific candidate and must remain a small patch against stable upstream APIs.

## Validation

Lightweight source/patch validation:

```bash
./setup/prepare-meo-dolphin-source.sh --check-only
```

Prepare the patched source tree without building Dolphin:

```bash
./setup/prepare-meo-dolphin-source.sh
```

A full Dolphin build and real desktop acceptance are deliberately separate checks. Do not mark split view, tabs, drag/drop, keyboard shortcuts, or visual acceptance complete until they have been exercised on the packaged build.
