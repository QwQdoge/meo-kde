/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Lightweight Caelestia-style liquid fill for a MeoShape silhouette.
    The sine geometry is painted once into a wide strip; animation translates
    that cached strip rather than repainting a Canvas every frame.
*/

import QtQuick
import QtQuick.Effects

import MeoUI 1.0

Item {
    id: root

    property real value: 0.0
    property string shapeName: "Circle"
    property color fillColor: Qt.rgba(MeoTheme.primary.r, MeoTheme.primary.g,
                                      MeoTheme.primary.b, 0.28)
    property bool animate: true
    readonly property real boundedValue: Math.max(0.0, Math.min(1.0, value))
    property real animatedValue: boundedValue
    readonly property real amplitude: Math.max(2, 3.5 * MeoTheme.globalScale)
    readonly property real waveHeight: amplitude * 2
    readonly property real fillTop: height * (1.0 - animatedValue)
    property real waveOffset: 0.0

    visible: boundedValue > 0.001

    Behavior on animatedValue {
        enabled: !MeoTheme.reduceMotion
        NumberAnimation {
            duration: MeoTheme.motionDurationMedium1
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MeoTheme.motionEasingEmphasizedDecelerate
        }
    }

    NumberAnimation on waveOffset {
        running: root.visible && root.animate
                 && !MeoTheme.reduceMotion
                 && root.boundedValue > 0.02 && root.boundedValue < 0.98
        from: 0
        to: root.width
        duration: MeoTheme.motionDurationExtraLong4 * 2
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    layer.enabled: visible
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: Item {
            width: root.width
            height: root.height

            MeoShape {
                anchors.fill: parent
                type: root.shapeName
                color: "white"
            }
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            x: 0
            y: Math.min(root.height, root.fillTop + root.amplitude)
            width: parent.width
            height: Math.max(0, parent.height - y)
            color: root.fillColor
        }

        Canvas {
            id: wave
            x: -root.waveOffset
            y: Math.max(-root.amplitude, root.fillTop - root.amplitude)
            width: root.width * 2
            height: root.waveHeight
            antialiasing: true
            renderStrategy: Canvas.Cooperative

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            Connections {
                target: root
                function onFillColorChanged() { wave.requestPaint() }
                function onAmplitudeChanged() { wave.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = root.fillColor
                const period = Math.max(16, root.width / 2)
                const step = Math.max(2, 2 * MeoTheme.globalScale)
                ctx.beginPath()
                ctx.moveTo(0, height)
                for (let px = 0; px <= width + step; px += step) {
                    const py = root.amplitude
                             + Math.sin(px / period * Math.PI * 2) * root.amplitude
                    ctx.lineTo(px, py)
                }
                ctx.lineTo(width, height)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
