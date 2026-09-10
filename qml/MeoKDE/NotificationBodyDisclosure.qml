// The disclosure state model is adapted from DankMaterialShell's
// NotificationCard.qml (MIT, Copyright 2025 Avenge Media LLC).
//
// This is a Qt Quick Controls / MeoUI reimplementation.  It deliberately
// keeps Plasma NotificationManager outside this component: the caller owns
// the model index and every real notification action.
import QtQuick
import MeoUI 1.0

Item {
    id: root

    property string bodyText: ""
    property int collapsedLines: 4
    property bool compact: false
    property bool expanded: false
    property bool critical: false

    // Keep the outgoing expanded projection alive through the collapse. This
    // avoids an abrupt text disappearance while the enclosing card contracts.
    property bool _retainedExpandedContent: false
    property bool _clipAnimatedContent: false
    property bool userInitiatedExpansion: false
    readonly property real expandedContentOpacity: expanded ? 1 : 0
    readonly property real collapsedContentOpacity: expanded ? 0 : 1
    readonly property bool renderExpandedContent: expanded || _retainedExpandedContent
    readonly property bool renderCollapsedContent: !expanded || _retainedExpandedContent
    readonly property bool expandable: !compact && bodyText.length > 180
    readonly property bool animating: settleTimer.running
    readonly property int transitionDuration: expanded
                                           ? MeoTheme.motionDurationDisclosureEnter
                                           : MeoTheme.motionDurationDisclosureExit

    signal expansionChanged()

    implicitWidth: content.implicitWidth
    implicitHeight: bodyText === "" ? 0
                                  : content.implicitHeight
                                    + (disclosureButton.visible
                                       ? disclosureButton.implicitHeight + MeoTheme.space4 : 0)

    function toggleExpanded() {
        if (!expandable)
            return
        userInitiatedExpansion = true
        expanded = !expanded
        expansionChanged()
    }

    onExpandedChanged: {
        if (MeoTheme.reduceMotion) {
            _retainedExpandedContent = false
            _clipAnimatedContent = false
            userInitiatedExpansion = false
            return
        }

        // The collapsed projection fades in while an outgoing expanded one is
        // retained. This is the same lifecycle DMS uses for notification text.
        _retainedExpandedContent = !expanded
        _clipAnimatedContent = true
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        interval: root.transitionDuration
        repeat: false
        onTriggered: {
            root._retainedExpandedContent = false
            root._clipAnimatedContent = false
            root.userInitiatedExpansion = false
        }
    }

    Item {
        id: content
        width: root.width
        implicitWidth: Math.max(collapsedBody.implicitWidth, expandedBody.implicitWidth)
        implicitHeight: root.expanded ? expandedBody.implicitHeight : collapsedBody.implicitHeight

        MeoText {
            id: collapsedBody
            width: parent.width
            visible: root.renderCollapsedContent
            opacity: root.collapsedContentOpacity
            text: root.bodyText
            typeRole: "body"
            typeSize: "medium"
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            maximumLineCount: root.collapsedLines
            elide: Text.ElideRight
            color: root.critical ? MeoTheme.onErrorContainer : MeoTheme.onSurfaceVariant
            Behavior on opacity {
                NumberAnimation {
                    duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationPanelState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingStandard
                }
            }
        }

        MeoText {
            id: expandedBody
            width: parent.width
            visible: root.renderExpandedContent
            opacity: root.expandedContentOpacity
            text: root.bodyText
            typeRole: "body"
            typeSize: "medium"
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            maximumLineCount: 1000
            color: root.critical ? MeoTheme.onErrorContainer : MeoTheme.onSurfaceVariant
            Behavior on opacity {
                NumberAnimation {
                    duration: MeoTheme.reduceMotion ? 0 : MeoTheme.motionDurationPanelState
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: MeoTheme.motionEasingStandard
                }
            }
        }
    }

    MeoButton {
        id: disclosureButton
        anchors.top: content.bottom
        anchors.topMargin: MeoTheme.space4
        visible: root.expandable
        type: "text"
        size: "xs"
        text: root.expanded ? qsTr("Show less") : qsTr("Show more")
        Accessible.name: text
        onClicked: root.toggleExpanded()
    }
}
