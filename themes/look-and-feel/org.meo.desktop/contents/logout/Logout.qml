import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.sessions
import MeoUI

// KSMServer supplies the signals and capability properties below. The Meo
// theme only decides presentation and intentional-confirmation behavior.
Item {
    id: root
    width: screenGeometry.width
    height: screenGeometry.height

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    readonly property string requestedTitle: {
        if (sdtype === ShutdownType.ShutdownTypeReboot)
            return softwareUpdatePending ? qsTr("Install updates and restart") : qsTr("Restart your computer")
        if (sdtype === ShutdownType.ShutdownTypeHalt)
            return softwareUpdatePending ? qsTr("Install updates and shut down") : qsTr("Shut down your computer")
        if (sdtype === ShutdownType.ShutdownTypeNone)
            return qsTr("Sign out of this session")
        return qsTr("Power and session")
    }

    function holdLabel(label) { return qsTr("Hold to %1").arg(label.toLowerCase()) }

    Image {
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/MeoArch/installer_background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(MeoTheme.scrim.r, MeoTheme.scrim.g, MeoTheme.scrim.b, 0.38) }

    SessionsModel {
        id: otherSessions
        includeUnusedSessions: false
        includeOwnSession: false
    }

    Keys.onEscapePressed: root.cancelRequested()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48 * MeoTheme.globalScale, 760 * MeoTheme.globalScale)
        spacing: 18 * MeoTheme.globalScale

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "file:///usr/share/pixmaps/meoarch-logo.svg"
            Layout.preferredWidth: 184 * MeoTheme.globalScale
            Layout.preferredHeight: 68 * MeoTheme.globalScale
            fillMode: Image.PreserveAspectFit
        }

        Text {
            Layout.fillWidth: true
            text: root.requestedTitle
            color: MeoTheme.contentOnSurface
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: MeoTheme.typefacePlain
            font.pixelSize: MeoTheme.headlineSmall.size * MeoTheme.globalScale
            font.weight: MeoTheme.headlineSmall.weight
            Accessible.name: text
        }

        Text {
            Layout.fillWidth: true
            visible: otherSessions.count > 0
            text: qsTr("%1 other signed-in user(s) may lose unsaved work.").arg(otherSessions.count)
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: MeoTheme.bodyMedium.size * MeoTheme.globalScale
        }

        Text {
            Layout.fillWidth: true
            visible: rebootToFirmwareSetup || rebootToBootLoaderMenu || rebootToBootLoaderEntry !== ""
            text: rebootToFirmwareSetup ? qsTr("The next restart will open firmware settings.")
                  : rebootToBootLoaderMenu ? qsTr("The next restart will open the boot menu.")
                  : qsTr("The next restart will use %1.").arg(rebootToBootLoaderEntry)
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: MeoTheme.bodyMedium.size * MeoTheme.globalScale
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 620 * MeoTheme.globalScale ? 2 : 1
            columnSpacing: 12 * MeoTheme.globalScale
            rowSpacing: 12 * MeoTheme.globalScale

            MeoHoldToConfirm {
                Layout.fillWidth: true
                visible: spdMethods.SuspendState && root.showAllOptions
                confirmationText: root.holdLabel(qsTr("sleep"))
                holdingText: qsTr("Keep holding to sleep…")
                iconName: "bedtime"
                tone: "neutral"
                onConfirmed: root.suspendRequested(2)
            }
            MeoHoldToConfirm {
                Layout.fillWidth: true
                visible: spdMethods.HibernateState && root.showAllOptions
                confirmationText: root.holdLabel(qsTr("hibernate"))
                holdingText: qsTr("Keep holding to hibernate…")
                iconName: "bedtime"
                tone: "neutral"
                onConfirmed: root.suspendRequested(4)
            }
            MeoHoldToConfirm {
                Layout.fillWidth: true
                visible: maysd && (root.showAllOptions || sdtype === ShutdownType.ShutdownTypeReboot)
                confirmationText: softwareUpdatePending ? root.holdLabel(qsTr("install updates and restart")) : root.holdLabel(qsTr("restart"))
                holdingText: qsTr("Keep holding to restart…")
                iconName: "restart_alt"
                tone: "primary"
                onConfirmed: softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested()
            }
            MeoHoldToConfirm {
                Layout.fillWidth: true
                visible: maysd && (root.showAllOptions || sdtype === ShutdownType.ShutdownTypeHalt)
                confirmationText: softwareUpdatePending ? root.holdLabel(qsTr("install updates and shut down")) : root.holdLabel(qsTr("shut down"))
                holdingText: qsTr("Keep holding to shut down…")
                iconName: "power_settings_new"
                tone: "error"
                onConfirmed: softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested()
            }
            MeoHoldToConfirm {
                Layout.fillWidth: true
                visible: canLogout && (root.showAllOptions || sdtype === ShutdownType.ShutdownTypeNone)
                confirmationText: root.holdLabel(qsTr("sign out"))
                holdingText: qsTr("Keep holding to sign out…")
                iconName: "logout"
                tone: "neutral"
                onConfirmed: root.logoutRequested()
            }
        }

        MeoButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Cancel")
            type: "tonal"
            icon.name: "close"
            Accessible.name: qsTr("Cancel power or session action")
            onClicked: root.cancelRequested()
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Applications with unsaved work may ask you before closing.")
            color: MeoTheme.contentOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: MeoTheme.labelMedium.size * MeoTheme.globalScale
        }
    }
}
