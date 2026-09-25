/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Lightweight Caelestia-style liquid fill for a MeoShape silhouette.
    The wave is scene-graph geometry; animation only translates the cached
    shape instead of repainting a Canvas every frame.
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

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
    readonly property string wavePath: buildWavePath()

    visible: boundedValue > 0.001

    function buildWavePath() {
        const stripWidth = Math.max(1, width * 2)
        const period = Math.max(16, width / 2)
        const mid = amplitude
        let path = "M 0 " + mid

        for (let x = 0; x < stripWidth; x += period) {
            const quarter = period / 4
            const half = period / 2
            path += " C " + (x + quarter) + " 0 "
                    + (x + quarter) + " " + (amplitude * 2) + " "
                    + (x + half) + " " + mid
            path += " C " + (x + quarter * 3) + " 0 "
                    + (x + quarter * 3) + " " + (amplitude * 2) + " "
                    + (x + period) + " " + mid
        }

        path += " L " + stripWidth + " " + waveHeight
                + " L 0 " + waveHeight + " Z"
        return path
    }

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

        Shape {
            x: -root.waveOffset
            y: Math.max(-root.amplitude, root.fillTop - root.amplitude)
            width: root.width * 2
            height: root.waveHeight

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.fillColor

                PathSvg {
                    path: root.wavePath
                }
            }
        }
    }
}
