// SPDX-License-Identifier: GPL-3.0-or-later
// MeoArch lock-only entrypoint for the pinned upstream lock implementation.
// Third-party source attribution is retained in THIRD_PARTY_NOTICES.md.

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

    // Keep only the service graph consumed by the Meo lock surface. Do not
    // instantiate the imported desktop bar, drawers, launcher, or picker.
    GSFLoader {}
    ServiceLoader {}

    Lock {
        id: lock
    }

    // Preserve idle/suspend locking and battery state used by the lock screen
    // while keeping this configuration lock-only.
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
