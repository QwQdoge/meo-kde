import QtQuick
import MeoUI 1.0

// Shared visual shell for compact top-panel triggers.
//
// Motion is deliberately not implemented here: callers compose the generic
// MeoUI MeoInteractionMotion primitive. This component owns only MeoKDE's
// shell-level silhouette, semantic colors, focus/ripple presentation, and the
// quiet-at-rest / tonal-on-interaction visual contract.
MeoShape {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool active: false
    property bool rippleEnabled: true

    property color restingColor: "transparent"
    property color interactionColor: MeoTheme.surfaceContainerHighest
    property color selectedColor: MeoTheme.primaryContainer
    property color restingContentColor: MeoTheme.onSurface
    property color selectedContentColor: MeoTheme.onPrimaryContainer

    readonly property color contentColor: active
                                          ? selectedContentColor
                                          : restingContentColor

    type: "round"
    radius: MeoTheme.shapeSmall
    color: active ? selectedColor
                  : (hovered || pressed ? interactionColor : restingColor)
    strokeColor: "transparent"
    strokeWidth: 0

    function triggerFromKeyboard() {
        stateLayer.triggerFromKeyboard()
    }

    Behavior on color {
        ColorAnimation {
            duration: MeoTheme.motionDurationEffectDefault
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingStandard
        }
    }

    MeoStateLayer {
        id: stateLayer
        anchors.fill: parent
        hovered: root.hovered
        pressed: root.pressed
        focused: root.focused
        rippleEnabled: root.rippleEnabled
        radius: root.radius
        color: root.contentColor
        focusColor: MeoTheme.primary
    }
}
