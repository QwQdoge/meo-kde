import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import MeoUI 1.0
import MeoKDE 1.0

QQC2.Popup {
    id: launcherPopup

    y: -height - ShellMetrics.popupGap
    x: (parent.width - width) / 2
    width: Math.min(ShellMetrics.launcherWidth, Screen.width - 2 * ShellMetrics.screenMargin)
    height: Math.min(ShellMetrics.launcherMaxHeight, Screen.height * 0.68)
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnPressOutside | QQC2.Popup.CloseOnEscape

    transformOrigin: Item.Bottom

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.97; to: 1.0; duration: MeoMotion.popupOpen; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: MeoMotion.popupClose; easing.type: Easing.InCubic }
    }

    background: FrostedSurface {}

    // Models from Kicker backend
    Kicker.RootModel {
        id: rootAppModel
        autoPopulate: true
    }

    Kicker.RunnerModel {
        id: runnerModel
        query: searchField.text
    }

    contentItem: FocusScope {
        anchors.fill: parent
        focus: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * MeoTheme.globalScale
            spacing: MeoTheme.space16

            // 1. Search Bar Header
            MeoTextField {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: ShellMetrics.launcherSearchHeight
                placeholderText: "Search apps, files and settings..."
                leadingIcon: "search"
                focus: true

                Keys.onEscapePressed: {
                    if (text !== "") {
                        text = ""
                    } else {
                        launcherPopup.close()
                    }
                }

                Keys.onDownPressed: {
                    if (searchResultList.visible && searchResultList.count > 0) {
                        searchResultList.focus = true
                        searchResultList.currentIndex = 0
                    } else if (allAppsGrid.visible && allAppsGrid.count > 0) {
                        allAppsGrid.focus = true
                        allAppsGrid.currentIndex = 0
                    }
                }
            }

            // 2. SEARCH RESULTS VIEW (Visible when query is typed)
            ListView {
                id: searchResultList
                visible: searchField.text.trim() !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: MeoTheme.space4

                model: runnerModel

                delegate: Rectangle {
                    required property int index
                    required property string display
                    property var icon: null
                    property string category: ""

                    width: searchResultList.width
                    height: 52 * MeoTheme.globalScale
                    radius: ShellMetrics.radiusMedium

                    color: searchResultList.currentIndex === index ? MeoTheme.secondaryContainer : (searchMouse.containsMouse ? MeoTheme.surfaceContainerHigh : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: MeoTheme.space12
                        anchors.rightMargin: MeoTheme.space12
                        spacing: MeoTheme.space12

                        Kirigami.Icon {
                            source: typeof icon === "string" && icon !== "" ? icon : "application-x-executable"
                            implicitWidth: ShellMetrics.appIconSize
                            implicitHeight: ShellMetrics.appIconSize
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: display || ""
                                font.family: MeoTheme.fontFamily
                                font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                                font.weight: Font.Medium
                                color: MeoTheme.onSurface
                                elide: Text.ElideRight
                            }
                            Text {
                                text: category !== "" ? category : "Application"
                                font.family: MeoTheme.fontFamily
                                font.pixelSize: 12 * MeoTheme.globalScale * MeoTheme.fontScale
                                color: MeoTheme.onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: searchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            runnerModel.trigger(index, "", null)
                            launcherPopup.close()
                        }
                    }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        runnerModel.trigger(currentIndex, "", null)
                        launcherPopup.close()
                    }
                }
            }

            // 3. DEFAULT VIEW (Suggested Apps + All Apps Grid)
            QQC2.ScrollView {
                visible: searchField.text.trim() === ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: MeoTheme.space16

                    // Suggested Apps Section
                    Text {
                        text: "Suggested"
                        font.family: MeoTheme.fontFamily
                        font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                        font.weight: Font.Medium
                        color: MeoTheme.onSurfaceVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MeoTheme.space8

                        Repeater {
                            model: rootAppModel.favoritesModel
                            delegate: Item {
                                required property int index
                                required property string display
                                property var icon: null

                                implicitWidth: ShellMetrics.appDelegateWidth
                                implicitHeight: ShellMetrics.appDelegateHeight
                                scale: favMouse.pressed ? 0.97 : 1.0

                                Behavior on scale { NumberAnimation { duration: MeoMotion.press; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: ShellMetrics.radiusMedium
                                    color: favMouse.containsMouse ? MeoTheme.surfaceContainerHigh : "transparent"

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: MeoTheme.space8

                                        Kirigami.Icon {
                                            source: typeof icon === "string" && icon !== "" ? icon : "application-x-executable"
                                            implicitWidth: ShellMetrics.appIconSize
                                            implicitHeight: ShellMetrics.appIconSize
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: display || ""
                                            font.family: MeoTheme.fontFamily
                                            font.pixelSize: 12 * MeoTheme.globalScale * MeoTheme.fontScale
                                            font.weight: Font.Medium
                                            color: MeoTheme.onSurface
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 62 * MeoTheme.globalScale
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: favMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            rootAppModel.favoritesModel.trigger(index, "", null)
                                            launcherPopup.close()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // All Apps Section
                    Text {
                        text: "All Apps"
                        font.family: MeoTheme.fontFamily
                        font.pixelSize: 14 * MeoTheme.globalScale * MeoTheme.fontScale
                        font.weight: Font.Medium
                        color: MeoTheme.onSurfaceVariant
                    }

                    GridView {
                        id: allAppsGrid
                        Layout.fillWidth: true
                        readonly property int columnCount: Math.max(4, Math.min(6,
                            Math.floor((width + MeoTheme.space8) /
                                       (ShellMetrics.appDelegateWidth + MeoTheme.space8))))
                        implicitHeight: Math.ceil(count / columnCount) * (ShellMetrics.appDelegateHeight + MeoTheme.space8)
                        cellWidth: Math.floor(width / columnCount)
                        cellHeight: ShellMetrics.appDelegateHeight + MeoTheme.space8

                        model: rootAppModel

                        delegate: Item {
                            required property int index
                            required property string display
                            property var icon: null

                            width: allAppsGrid.cellWidth
                            height: allAppsGrid.cellHeight
                            scale: appMouse.pressed ? 0.97 : 1.0

                            Behavior on scale { NumberAnimation { duration: MeoMotion.press; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: ShellMetrics.appDelegateWidth
                                height: ShellMetrics.appDelegateHeight
                                radius: ShellMetrics.radiusMedium
                                color: appMouse.containsMouse ? MeoTheme.surfaceContainerHigh : "transparent"

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: MeoTheme.space8

                                    Kirigami.Icon {
                                        source: typeof icon === "string" && icon !== "" ? icon : "application-x-executable"
                                        implicitWidth: ShellMetrics.appIconSize
                                        implicitHeight: ShellMetrics.appIconSize
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: display || ""
                                        font.family: MeoTheme.fontFamily
                                        font.pixelSize: 12 * MeoTheme.globalScale * MeoTheme.fontScale
                                        color: MeoTheme.onSurface
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        Layout.maximumWidth: 62 * MeoTheme.globalScale
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        rootAppModel.trigger(index, "", null)
                                        launcherPopup.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
