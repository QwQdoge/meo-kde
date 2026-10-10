#pragma once

#include <QtCore/QEasingCurve>
#include <QtWidgets/QStyleOptionProgressBar>
#include <meodesigntokens.h>

namespace MeoProgress {
inline bool horizontal(const QStyleOptionProgressBar &bar) { return bar.state.testFlag(QStyle::State_Horizontal); }
inline QRectF segment(const QStyleOptionProgressBar &bar, qreal start, qreal end)
{
    const QRectF rect(bar.rect);
    if (end <= start) return {};
    if (horizontal(bar)) {
        const bool reverse = bar.invertedAppearance != (bar.direction == Qt::RightToLeft);
        return QRectF(rect.left() + (reverse ? 1 - end : start) * rect.width(), rect.top(),
                      (end - start) * rect.width(), rect.height());
    }
    return QRectF(rect.left(), rect.top() + (bar.invertedAppearance ? start : 1 - end) * rect.height(),
                  rect.width(), (end - start) * rect.height());
}
inline QList<QRectF> activeRects(const QStyleOptionProgressBar &bar, qreal phase)
{
    if (bar.minimum == 0 && bar.maximum == 0) {
        // Same two-line 1750ms clock and emphasized-accelerate curve as MeoUI.
        QEasingCurve curve(QEasingCurve::BezierSpline);
        curve.addCubicBezierSegment(QPointF(0.3, 0), QPointF(0.8, 0.15), QPointF(1, 1));
        auto position = [&](int delay, int duration) {
            return curve.valueForProgress(qBound(0.0, (phase * 1750 - delay) / duration, 1.0));
        };
        return {segment(bar, position(250, 1000), position(0, 1000)),
                segment(bar, position(900, 850), position(650, 850))};
    }
    const qint64 range = qint64(bar.maximum) - bar.minimum;
    if (range <= 0 || bar.progress < bar.minimum) return {};
    return {segment(bar, 0, qBound(0.0, qreal(qint64(bar.progress) - bar.minimum) / range, 1.0))};
}
} // namespace MeoProgress
