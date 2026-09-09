import QtQuick
import QtCore
import org.kde.kirigami as Kirigami
import MeoUI 1.0

Window {
    id: root

    property string applicationId: ""
    property string applicationName: ""
    property var applicationIcon
    signal hidden()

    visible: false
    color: "transparent"
    opacity: 0
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
           | Qt.WindowTransparentForInput
    modality: Qt.NonModal
    title: qsTr("Opening %1").arg(applicationName)

    function place(geometry) {
        const available = screen
                          ? Qt.rect(screen.virtualX, screen.virtualY,
                                    screen.desktopAvailableWidth,
                                    screen.desktopAvailableHeight)
                                 : Qt.rect(0, 0, 1280, 800)
        const remembered = geometry && geometry.width >= 240
                           && geometry.height >= 160
        width = Math.min(available.width,
                         remembered ? geometry.width : 720 * MeoTheme.globalScale)
        height = Math.min(available.height,
                          remembered ? geometry.height : 460 * MeoTheme.globalScale)
        x = remembered
                ? Math.max(available.x, Math.min(geometry.x,
                           available.x + available.width - width))
                : available.x + (available.width - width) / 2
        y = remembered
                ? Math.max(available.y, Math.min(geometry.y,
                           available.y + available.height - height))
                : available.y + (available.height - height) / 2
    }

    function showFor(appId, appName, appIcon, geometry) {
        applicationId = appId
        applicationName = appName || qsTr("Application")
        applicationIcon = appIcon
        place(geometry)
        launchContent.active = true
        opacity = 0
        visible = true
        fadeOut.stop()
        fadeIn.restart()
        visibleDeadline.restart()
    }

    function dismiss() {
        visibleDeadline.stop()
        if (!visible) {
            hidden()
            return
        }
        launchContent.active = false
        fadeIn.stop()
        fadeOut.restart()
    }

    MeoLaunchSurface {
        id: launchContent
        anchors.fill: parent
        appName: root.applicationName
        supportingText: qsTr("Opening on MeoArch")
        fallbackIcon: "apps"
        backgroundSource: StandardPaths.locate(
                              StandardPaths.GenericDataLocation,
                              "wallpapers/MeoArch/installer_background.png")

        iconContent: Kirigami.Icon {
            anchors.centerIn: parent
            width: 52 * MeoTheme.globalScale
            height: width
            source: root.applicationIcon
        }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationEffectDefault
        easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandardDecelerate
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "opacity"
        to: 0
        duration: MeoTheme.motionDurationEffectDefault
        easing.type: Easing.BezierSpline; easing.bezierCurve: MeoTheme.motionEasingStandardAccelerate
        onFinished: {
            root.visible = false
            root.hidden()
        }
    }

    Timer {
        id: visibleDeadline
        interval: 1200
        onTriggered: root.dismiss()
    }
}
