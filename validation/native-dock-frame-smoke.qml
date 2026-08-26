import QtQuick
import QtQuick.Window
import org.kde.ksvg as KSvg

Window {
    id: root

    function argumentValue(prefix) {
        for (const argument of Qt.application.arguments) {
            if (argument.indexOf(prefix) === 0)
                return argument.substring(prefix.length)
        }
        return ""
    }

    readonly property string themeRoot: argumentValue("--theme-root=")
    readonly property string tasksPath: themeRoot + "/widgets/tasks.svg"
    readonly property string panelPath: themeRoot + "/widgets/panel-background.svg"
    readonly property string translucentPanelPath: themeRoot + "/translucent/widgets/panel-background.svg"
    readonly property string snapshotPath: argumentValue("--snapshot=")
    readonly property bool preview: snapshotPath !== ""

    width: preview ? 720 : 1
    height: preview ? 144 : 1
    visible: true
    color: preview ? "#26439b" : "transparent"

    Rectangle {
        z: -2
        anchors.fill: parent
        visible: root.preview
        color: "#26439b"
    }

    function assertPrefix(frame, expected) {
        if (frame.usedPrefix !== expected) {
            throw new Error("Expected " + expected + " frame, got " + frame.usedPrefix)
        }
    }

    KSvg.FrameSvgItem {
        id: normalFrame
        x: 116
        y: 48
        width: 48
        height: 48
        visible: root.preview
        imagePath: root.tasksPath
        prefix: ["south-normal", "normal"]

        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: Qt.resolvedUrl("../plasmoids/org.meo.shelf/contents/images/meoarch-logo.svg")
        }
    }

    KSvg.FrameSvgItem {
        id: normalHoverFrame
        x: 180
        y: 48
        width: 48
        height: 48
        visible: root.preview
        imagePath: root.tasksPath
        prefix: ["south-normal-hover", "normal-hover", "south-hover", "hover", "south-normal", "normal"]

        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: Qt.resolvedUrl("../plasmoids/org.meo.shelf/contents/images/meoarch-logo.svg")
        }
    }

    KSvg.FrameSvgItem {
        id: focusFrame
        x: 244
        y: 48
        width: 48
        height: 48
        visible: root.preview
        imagePath: root.tasksPath
        prefix: ["south-focus", "focus"]

        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: Qt.resolvedUrl("../plasmoids/org.meo.shelf/contents/images/meoarch-logo.svg")
        }
    }

    KSvg.FrameSvgItem {
        id: focusHoverFrame
        x: 308
        y: 48
        width: 48
        height: 48
        visible: root.preview
        imagePath: root.tasksPath
        prefix: ["south-focus-hover", "focus-hover", "south-hover", "hover", "south-focus", "focus"]

        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: Qt.resolvedUrl("../plasmoids/org.meo.shelf/contents/images/meoarch-logo.svg")
        }
    }

    KSvg.FrameSvgItem {
        id: progressFrame
        width: 48
        height: 48
        visible: false
        imagePath: root.tasksPath
        prefix: ["south-progress", "progress", "south-hover", "hover"]
    }

    KSvg.FrameSvgItem {
        id: panelFrame
        z: -1
        x: 84
        y: 40
        width: 552
        height: 64
        visible: root.preview
        imagePath: root.panelPath
    }

    KSvg.FrameSvgItem {
        id: translucentPanelFrame
        width: 64
        height: 64
        visible: false
        imagePath: root.translucentPanelPath
        prefix: ["north", ""]
    }

    KSvg.FrameSvgItem {
        id: northPanelFrame
        width: 32
        height: 32
        visible: false
        imagePath: root.panelPath
        prefix: ["north", ""]
    }

    KSvg.FrameSvgItem {
        id: southPanelFrame
        width: 64
        height: 64
        visible: false
        imagePath: root.panelPath
        prefix: ["south", ""]
    }

    Component.onCompleted: {
        if (themeRoot === "")
            throw new Error("--theme-root is required")
        checkTimer.start()
    }

    Timer {
        id: checkTimer
        interval: 50
        onTriggered: {
            root.assertPrefix(normalFrame, "normal")
            root.assertPrefix(normalHoverFrame, "normal-hover")
            root.assertPrefix(focusFrame, "focus")
            root.assertPrefix(focusHoverFrame, "focus-hover")
            root.assertPrefix(progressFrame, "progress")
            if (!panelFrame.hasElement("center"))
                throw new Error("Floating Dock panel frame is missing its center element")
            if (!translucentPanelFrame.hasElement("center"))
                throw new Error("Translucent floating Dock panel frame is missing its center element")
            root.assertPrefix(northPanelFrame, "north")
            root.assertPrefix(southPanelFrame, "south")
            root.assertPrefix(translucentPanelFrame, "north")
            if (northPanelFrame.minimumDrawingHeight !== 32)
                throw new Error("Top panel frame must permit a 32 px height")
            if (translucentPanelFrame.minimumDrawingHeight !== 32)
                throw new Error("Translucent top panel frame must permit a 32 px height")
            if (southPanelFrame.minimumDrawingHeight !== 56)
                throw new Error("Bottom Dock frame must retain its 56 px minimum")
            if (northPanelFrame.fixedMargins.top !== 4 || northPanelFrame.fixedMargins.bottom !== 4)
                throw new Error("Top panel frame must retain 4 px content margins")
            if (southPanelFrame.fixedMargins.top !== 4 || southPanelFrame.fixedMargins.bottom !== 4)
                throw new Error("Bottom Dock frame must retain 4 px content margins")

            console.warn("MEO_NATIVE_DOCK_FRAME_OK", root.themeRoot)
            if (root.snapshotPath === "") {
                Qt.quit()
                return
            }
            root.contentItem.grabToImage(function(result) {
                if (!result.saveToFile(root.snapshotPath))
                    throw new Error("Unable to save Dock frame snapshot")
                Qt.quit()
            })
        }
    }
}
