/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: LGPL-2.0-or-later

    Geometry-only derivative of Breeze SessionManagementScreen. KDE's models,
    user list, notifications, and session action slots are retained; the
    prompt column is allowed to reach the standalone lock surface's 600dp
    centre width instead of Breeze's compact 16-grid-unit cap.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.breeze.components as Breeze

import MeoUI 1.0

FocusScope {
    id: root

    property alias notificationMessage: notificationsLabel.text
    property alias actionItems: actionItemsLayout.children
    property alias actionItemsVisible: actionItemsLayout.visible
    property alias userListModel: userListView.model
    property alias userListCurrentIndex: userListView.currentIndex
    property alias userListCurrentItem: userListView.currentItem
    property alias userList: userListView
    property bool showUserList: true
    property real fontSize: Kirigami.Theme.defaultFont.pointSize + 2
    // Caelestia's standalone centre uses a 600dp content column at its
    // reference scale. Keep a small-screen floor so secure input stays usable.
    readonly property real standaloneCenterWidth: Math.min(600 * MeoTheme.globalScale,
                                                           Math.max(344 * MeoTheme.globalScale,
                                                                    width - Kirigami.Units.gridUnit * 2))
    default property alias _children: innerLayout.children

    signal userSelected()

    function playHighlightAnimation() {
        bounceAnimation.start()
    }

    Breeze.UserList {
        id: userListView
        visible: root.showUserList && y > 0
        anchors {
            bottom: parent.verticalCenter
            bottomMargin: constrainText ? Kirigami.Units.gridUnit * 3 : 0
            left: parent.left
            right: parent.right
        }
        fontSize: root.fontSize
        onUserSelected: root.userSelected()
    }

    ColumnLayout {
        id: prompts
        anchors {
            top: parent.verticalCenter
            topMargin: Kirigami.Units.largeSpacing
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        PlasmaComponents3.Label {
            id: notificationsLabel
            font.pointSize: root.fontSize
            Layout.maximumWidth: root.standaloneCenterWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.italic: true

            SequentialAnimation {
                id: bounceAnimation
                loops: 1
                PropertyAnimation { target: notificationsLabel; properties: "scale"; from: 1.0; to: 1.1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuad }
                PropertyAnimation { target: notificationsLabel; properties: "scale"; from: 1.1; to: 1.0; duration: Kirigami.Units.longDuration; easing.type: Easing.InQuad }
            }
        }

        ColumnLayout {
            Layout.minimumHeight: implicitHeight
            Layout.maximumHeight: Math.max(implicitHeight, root.height - Kirigami.Units.gridUnit * 4)
            Layout.preferredWidth: root.standaloneCenterWidth
            Layout.maximumWidth: root.standaloneCenterWidth
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            ColumnLayout {
                id: innerLayout
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: actionItemsLayout.implicitHeight
            implicitWidth: actionItemsLayout.implicitWidth
            GridLayout {
                id: actionItemsLayout
                anchors.centerIn: parent
                readonly property int spacing: Kirigami.Units.largeSpacing
                rowSpacing: spacing
                columnSpacing: spacing
                readonly property int buttonCount: visibleChildren.length
                readonly property int singleRowWidth: (children[0].implicitWidth * buttonCount) + (spacing * (buttonCount - 1))
                columns: singleRowWidth < root.width ? buttonCount : Math.ceil(buttonCount / 2)
            }
        }
        Item { Layout.fillHeight: true }
    }
}
