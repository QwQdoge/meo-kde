import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import MeoUI 1.0
import MeoKDE 1.0

PlasmoidItem {
    id: root

    readonly property real stripPadding: MeoTheme.space4
    // Keep the active-application title close to a macOS-style menu-bar item:
    // compact for short names, bounded for long names, and never a task icon.
    readonly property real appExtent: Math.max(72 * MeoTheme.globalScale,
                                               Math.min(196 * MeoTheme.globalScale,
                                                        (32 + visibleApplicationName.length * 8)
                                                        * MeoTheme.globalScale))
    readonly property real compactWidth: appExtent + 2 * stripPadding
    property int taskRevision: 0

    readonly property var activeTaskIndex: {
        taskRevision
        return tasksModel.activeTask
    }
    readonly property string activeApplicationId: {
        taskRevision
        return tasksModel.data(activeTaskIndex,
                               TaskManager.AbstractTasksModel.AppId) || ""
    }
    readonly property string activeApplicationName: {
        taskRevision
        const name = tasksModel.data(activeTaskIndex,
                                     TaskManager.AbstractTasksModel.AppName)
        return name || tasksModel.data(activeTaskIndex, 0) || ""
    }
    readonly property bool activeApplicationAvailable: activeApplicationName !== ""
    readonly property bool activeApplicationClosable: {
        taskRevision
        return activeApplicationAvailable
               && !!tasksModel.data(activeTaskIndex,
                                    TaskManager.AbstractTasksModel.IsClosable)
    }
    readonly property string visibleApplicationName: activeApplicationAvailable
                                                     ? activeApplicationName
                                                     : MeoI18n.translator.i18n("Desktop")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.title: MeoI18n.translator.i18n("Active application")
    toolTipMainText: visibleApplicationName
    toolTipSubText: activeApplicationAvailable
                    ? MeoI18n.translator.i18n("Open this application's configuration menu")
                    : MeoI18n.translator.i18n("No application window is active")
    preferredRepresentation: compactRepresentation
    switchWidth: 0
    switchHeight: 0
    Layout.minimumWidth: compactWidth
    Layout.preferredWidth: compactWidth
    Layout.maximumWidth: compactWidth
    Layout.minimumHeight: ShellMetrics.topBarHeight
    Layout.preferredHeight: ShellMetrics.topBarHeight
    Layout.maximumHeight: ShellMetrics.topBarHeight

    Component.onCompleted: MeoShellTheme.sync()

    // KDE is the source of truth for application identity. The separate
    // org.kde.plasma.appmenu applet placed immediately after this widget owns
    // File/Edit/View/etc and renders only menus exported by the application.
    // This surface deliberately does not invent or mirror application menus.
    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        filterHidden: true
        // The app-name item models the active *window*, not an application
        // group. Alt+F4 semantics must close only that active window.
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    function applicationDeepLink(section) {
        if (!activeApplicationAvailable)
            return ""
        const query = []
        if (/^[A-Za-z0-9][A-Za-z0-9._+@-]{0,255}$/.test(activeApplicationId))
            query.push("appId=" + encodeURIComponent(activeApplicationId))
        query.push("appName=" + encodeURIComponent(activeApplicationName))
        query.push("section=" + encodeURIComponent(section))
        return "meosettings://applications?" + query.join("&")
    }

    function openApplicationInfo() {
        const url = applicationDeepLink("info")
        if (url !== "")
            Qt.openUrlExternally(url)
    }

    function openApplicationConfiguration() {
        const url = applicationDeepLink("config")
        if (url !== "")
            Qt.openUrlExternally(url)
    }

    function closeActiveApplication() {
        if (activeApplicationAvailable && activeApplicationClosable)
            tasksModel.requestClose(activeTaskIndex)
    }

    compactRepresentation: Item {
        id: compactRoot
        implicitWidth: root.compactWidth
        implicitHeight: ShellMetrics.topBarHeight

        QQC2.AbstractButton {
            id: activeAppButton
            anchors.centerIn: parent
            width: root.appExtent
            height: 28 * MeoTheme.globalScale
            hoverEnabled: true
            enabled: root.activeApplicationAvailable
            Accessible.name: root.visibleApplicationName
            activeFocusOnTab: true
            Accessible.description: root.activeApplicationAvailable
                                    ? MeoI18n.translator.i18n("Open application menu")
                                    : MeoI18n.translator.i18n("No application window is active")
            onClicked: appMenu.openFrom(activeAppButton)

            MeoInteractionSpring {
                id: appInteraction
                hovered: activeAppButton.hovered
                pressed: activeAppButton.down
                active: appMenu.opened
                enabled: activeAppButton.enabled
                motionProfile: "pixel"
            }

            transform: [
                Scale {
                    origin.x: activeAppButton.width / 2
                    origin.y: activeAppButton.height / 2
                    xScale: appInteraction.scale
                    yScale: appInteraction.scale
                },
                Translate {
                    x: appInteraction.offsetX
                    y: appInteraction.offsetY
                }
            ]

            background: MeoShape {
                id: appSurface
                type: "round"
                radius: activeAppButton.height / 2
                color: appMenu.opened
                       ? MeoTheme.secondaryContainer
                       : (activeAppButton.hovered || activeAppButton.down
                          ? MeoTheme.surfaceContainerHigh
                          : "transparent")
                strokeColor: "transparent"
                strokeWidth: 0

                Behavior on color {
                    ColorAnimation {
                        duration: MeoTheme.motionDurationEffectDefault
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MeoTheme.motionEasingStandard
                    }
                }

                MeoStateLayer {
                    anchors.fill: parent
                    radius: appSurface.radius
                    hovered: activeAppButton.hovered
                    pressed: activeAppButton.down
                    focused: activeAppButton.visualFocus
                    color: appMenu.opened
                           ? MeoTheme.contentOnSecondaryContainer
                           : MeoTheme.contentOnSurface
                }
            }

            contentItem: RowLayout {
                spacing: 0

                MeoText {
                    Layout.fillWidth: true
                    text: root.visibleApplicationName
                    typeRole: "label"
                    typeSize: "large"
                    emphasized: root.activeApplicationAvailable
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: appMenu.opened
                           ? MeoTheme.contentOnSecondaryContainer
                           : (root.activeApplicationAvailable
                              ? MeoTheme.contentOnSurface
                              : MeoTheme.contentOnSurfaceVariant)
                    Behavior on color {
                        ColorAnimation {
                            duration: MeoTheme.motionDurationEffectDefault
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: MeoTheme.motionEasingStandard
                        }
                    }
                }
            }

            MeoTooltip {
                visible: activeAppButton.hovered
                         && root.activeApplicationAvailable
                text: root.activeApplicationName
                delay: MeoTheme.motionDurationLong1
            }
        }

        // This is the shell-owned application-name menu, analogous to the
        // application-name menu on macOS. It contains only universal window /
        // Meo integration actions. File/Edit/View/etc remain exclusively in
        // the application/KDE Global Menu beside this widget.
        MeoMenu {
            id: appMenu
            parent: QQC2.Overlay.overlay || compactRoot
            placement: "below"
            placementGap: MeoTheme.space4
            preferredMenuWidth: 280 * MeoTheme.globalScale
            itemHeight: 44 * MeoTheme.globalScale
            menuPadding: 6 * MeoTheme.globalScale
            focusReturnItem: activeAppButton
            model: [
                {
                    "label": MeoI18n.translator.i18n("About %1").arg(root.activeApplicationName),
                    "icon": "info",
                    "action": function() { root.openApplicationInfo() }
                },
                {
                    "label": MeoI18n.translator.i18n("Settings…"),
                    "icon": "settings",
                    "action": function() { root.openApplicationConfiguration() }
                },
                {
                    "type": "separator"
                },
                {
                    "label": MeoI18n.translator.i18n("Quit %1").arg(root.activeApplicationName),
                    "icon": "close",
                    "shortcut": "Alt+F4",
                    "enabled": root.activeApplicationClosable,
                    "action": function() { root.closeActiveApplication() }
                }
            ]
        }
    }

    Connections {
        target: tasksModel
        function onActiveTaskChanged() {
            root.taskRevision++
            if (appMenu.opened)
                appMenu.close()
        }
        function onDataChanged() { root.taskRevision++ }
        function onModelReset() { root.taskRevision++ }
        function onRowsInserted() { root.taskRevision++ }
        function onRowsRemoved() { root.taskRevision++ }
    }
}
