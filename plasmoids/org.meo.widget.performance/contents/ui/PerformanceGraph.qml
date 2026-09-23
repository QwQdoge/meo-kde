import QtQuick
import MeoUI 1.0

Item {
    id: root

    property var values: []
    property var secondaryValues: []
    property color primaryColor: MeoTheme.primary
    property color secondaryColor: MeoTheme.tertiary
    property real maximum: 0
    property bool fillArea: true

    implicitHeight: 52 * MeoTheme.globalScale

    function effectiveMaximum() {
        if (maximum > 0)
            return maximum
        let maxValue = 1
        for (let i = 0; i < values.length; ++i)
            maxValue = Math.max(maxValue, Number(values[i]) || 0)
        for (let j = 0; j < secondaryValues.length; ++j)
            maxValue = Math.max(maxValue, Number(secondaryValues[j]) || 0)
        return maxValue
    }

    function drawSeries(ctx, series, color, fill) {
        if (!series || series.length < 2)
            return
        const maxValue = effectiveMaximum()
        const denominator = Math.max(1, series.length - 1)
        ctx.beginPath()
        for (let i = 0; i < series.length; ++i) {
            const x = width * i / denominator
            const value = Math.max(0, Number(series[i]) || 0)
            const y = height - (height - 3 * MeoTheme.globalScale)
                    * Math.min(1, value / maxValue)
            if (i === 0)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        if (fill) {
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.10).toString()
            ctx.fill()
            ctx.beginPath()
            for (let k = 0; k < series.length; ++k) {
                const px = width * k / denominator
                const sample = Math.max(0, Number(series[k]) || 0)
                const py = height - (height - 3 * MeoTheme.globalScale)
                        * Math.min(1, sample / maxValue)
                if (k === 0)
                    ctx.moveTo(px, py)
                else
                    ctx.lineTo(px, py)
            }
        }
        ctx.strokeStyle = color.toString()
        ctx.lineWidth = 2 * MeoTheme.globalScale
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.stroke()
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            root.drawSeries(ctx, root.values, root.primaryColor, root.fillArea)
            root.drawSeries(ctx, root.secondaryValues, root.secondaryColor, false)
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onValuesChanged: canvas.requestPaint()
    onSecondaryValuesChanged: canvas.requestPaint()
    onPrimaryColorChanged: canvas.requestPaint()
    onSecondaryColorChanged: canvas.requestPaint()
    onMaximumChanged: canvas.requestPaint()
}
