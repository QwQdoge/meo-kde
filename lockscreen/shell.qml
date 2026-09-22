// SPDX-License-Identifier: GPL-3.0-or-later
// MeoArch lock-only entrypoint for the pinned Caelestia Shell source tree.
// The Caelestia implementation remains GPL-3.0 and keeps its upstream notices.

//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/lock"
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    // A production lock process must stay resident. Disable source watching so
    // an editor/package update cannot hot-reload the security surface mid-lock.
    settings.watchFiles: false

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Keep the upstream service graph that the lock cards consume, but do not
    // instantiate Caelestia's bar, drawers, launcher, background, or picker.
    GSFLoader {}
    ServiceLoader {}

    Lock {
        id: lock
    }

    // Preserve upstream idle/suspend locking and battery state used by the
    // lock screen while keeping this configuration lock-only.
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
