import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    required property var lock

    readonly property string mode: MeoSessionEntry.notificationVisibility
    readonly property int notificationCount: Notifs.notClosed.length
    readonly property var appNames: {
        const seen = new Set();
        const names = [];
        for (const notification of Notifs.notClosed) {
            const candidate = typeof notification.appName === "string"
                ? notification.appName.trim().slice(0, 80)
                : "";
            if (!candidate || seen.has(candidate))
                continue;
            seen.add(candidate);
            names.push(candidate);
            if (names.length >= 6)
                break;
        }
        return names;
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitHeight: summary.implicitHeight + Tokens.padding.extraLarge * 2
    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Loader {
        anchors.fill: parent
        active: root.mode === "full-content"
        asynchronous: true

        sourceComponent: NotifDock {
            lock: root.lock
        }
    }

    ColumnLayout {
        id: summary

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge
        spacing: Tokens.spacing.small
        visible: root.mode !== "full-content"

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "notifications"
            color: Colours.palette.m3primary
            font: Tokens.font.icon.large
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            text: {
                if (root.mode === "hidden")
                    return Tr.tr("Unlock to view notifications");
                if (root.mode === "count")
                    return root.notificationCount > 0
                        ? Tr.trN("%n notification", "%n notifications", root.notificationCount)
                        : Tr.tr("No notifications");
                if (root.mode === "app-name") {
                    if (root.notificationCount === 0)
                        return Tr.tr("No notifications");
                    if (root.appNames.length === 0)
                        return Tr.trN("%n notification", "%n notifications", root.notificationCount);
                    return root.appNames.join(" · ");
                }
                return Tr.tr("Unlock to view notifications");
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.mode === "app-name" && root.notificationCount > root.appNames.length
            horizontalAlignment: Text.AlignHCenter
            text: visible ? Tr.trN("%n notification total", "%n notifications total", root.notificationCount) : ""
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }
}
