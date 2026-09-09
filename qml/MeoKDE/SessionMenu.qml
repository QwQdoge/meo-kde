import QtQuick
import org.kde.plasma.private.sessions 2.0 as Sessions
import MeoUI 1.0

// Platform-owned session actions presented through the shared MeoUI menu.
MeoMenu {
    id: control

    property var closeTarget: null

    function finish(action) {
        action()
        if (closeTarget && typeof closeTarget.close === "function")
            closeTarget.close()
    }

    model: {
        const entries = []
        if (sessionManagement.canSuspend) {
            entries.push({
                "label": qsTr("Sleep now"),
                "icon": "bedtime",
                "action": function() { control.finish(function() { sessionManagement.suspend() }) }
            })
        }
        if (sessionManagement.canReboot) {
            entries.push({
                "label": qsTr("Restart…"),
                "icon": "restart_alt",
                "action": function() {
                    control.finish(function() {
                        sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt)
                    })
                }
            })
        }
        if (sessionManagement.canShutdown) {
            entries.push({
                "label": qsTr("Shut down…"),
                "icon": "power_settings_new",
                "action": function() {
                    control.finish(function() {
                        sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt)
                    })
                }
            })
        }
        if (entries.length > 0 && sessionManagement.canLogout)
            entries.push({ "type": "separator" })
        if (sessionManagement.canLogout) {
            entries.push({
                "label": qsTr("Sign out…"),
                "icon": "logout",
                "action": function() {
                    control.finish(function() {
                        sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt)
                    })
                }
            })
        }
        return entries
    }

    Sessions.SessionManagement { id: sessionManagement }
}
