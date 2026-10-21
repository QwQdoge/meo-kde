import QtQuick
import Meo.System 1.0 as MeoSystem

// Asks the compositor to blur what is behind a rounded Meo popup, but only when
// the user opted in (SurfaceBlur in meo-shellrc). Place it inside the
// PlasmaCore.Dialog that hosts the popup surface.
MeoSystem.WindowBlur {
    id: root

    required property var dialog

    window: dialog
    enabled: MeoSystem.ShellAppearance.blur
    radius: ShellMetrics.radiusPopup
    rect: dialog && dialog.mainItem
          ? Qt.rect(dialog.mainItem.x, dialog.mainItem.y, dialog.mainItem.width, dialog.mainItem.height)
          : Qt.rect(0, 0, 0, 0)
}
