# MeoKDE component status

This file classifies implementations that coexist in the repository. Presence in the tree does not imply that a component is current product direction.

## Current product path

These are the default/current Meo Desktop implementation surfaces unless a nearer contract says otherwise:

- `themes/look-and-feel/org.meo.desktop/`: Meo Desktop Plasma layout/default shell composition.
- `tools/session/startmeo-wayland` and `data/wayland-sessions/meo.desktop`: independent Meo Desktop session entry.
- `plasmoids/org.meo.systemmenu`: current system/menu entry.
- `plasmoids/org.meo.shelf`: current launcher/All Apps entry used by the bottom taskbar.
- `org.kde.plasma.icontasks`: current task/window model and frontend used by the default bottom taskbar; Meo styles/integrates it rather than replacing the task authority.
- `plasmoids/org.meo.topbar`: current Meo system-status/Quick Settings surface.
- `plasmoids/org.meo.time-notifications`: current time/notification surface in the default layout.
- `plasmoids/org.meo.widget.*` and `org.meo.widgetexplorer`: first-party Meo desktop widget adapters/browser.
- `native/system/`: current Meo.System runtime bridge and system-facing desktop authority.
- `qml/MeoKDE/`: shared KDE-specific QML used by current shell/application surfaces.
- current themes, KWin/decoration, authentication and lock/session integration referenced by packaging/default session contracts.

## Optional / compatibility

These may remain maintained where they provide a supported alternate composition or compatibility path, but they are not the default layout authority:

- `plasmoids/org.meo.notifications`
- `plasmoids/org.meo.time`
- compatible Plasma third-party widget hosting
- upstream/third-party compatibility shims under `native/third_party/`
- package adapters that preserve native Plasma/KDE ownership while adding Meo presentation.

New features should target the current surface first. Optional compatibility surfaces should receive only fixes needed to keep their documented contract working unless a task explicitly promotes them.

## Legacy / migration-only

- `native/dock/`: standalone Meo Dock experiment/legacy implementation. The current Meo Desktop default uses the bottom Plasma taskbar with `org.meo.shelf` + KDE IconTasks. Do not infer a Dock product direction from this directory and do not add new shell features here unless a task explicitly revives it.
- Older time/task compositions such as `org.meo.timecenter` / `org.meo.toptasks` are not default layout authorities. Keep them only where an existing compatibility/test/migration contract still requires them.
- Historical themes/layout experiments that are not referenced by the current default session/package are provenance, not feature targets.

Legacy code must not be restored into the default layout merely because it contains a feature missing from current `main`.

## Experimental

A component is experimental when its nearest documentation/packaging says so or when it is not referenced by the default session/release path. Experimental code must not silently become a required dependency of the default Meo Desktop.

## Promotion/removal rule

To promote an optional/experimental implementation to Current, update together:

1. this status file;
2. the default layout/session/package path;
3. nearest tests/contracts;
4. migration notes when user configuration/state is affected.

To remove Legacy code, first prove no maintained package, CI contract, source installer, migration path or current consumer still references it. Removal should be a dedicated cleanup change, not incidental feature work.
