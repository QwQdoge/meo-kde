#pragma once

#include <QtCore/QRectF>
#include <QtGui/QPainterPath>

#include <algorithm>

#include <meodesigntokens.h>

// Path helpers for the split slider and linear progress tracks. Their
// dimensions are MeoUI design tokens (Meo::DesignTokens::slider*/progress*).
namespace MeoTrack {

// The painted thumb is a 4dp bar; the pointer target along the axis stays
// wider so a Qt Widgets slider remains easy to grab. Native-style only.
constexpr qreal sliderHitLength = 20.0;

// Rounded rectangle with independent corner radii, clamped to the rect.
inline QPainterPath roundedPath(const QRectF &r, qreal topLeft, qreal topRight,
                                qreal bottomRight, qreal bottomLeft)
{
    QPainterPath path;
    if (r.width() <= 0 || r.height() <= 0) return path;
    const qreal limit = std::min(r.width(), r.height()) / 2.0;
    const auto clamp = [limit](qreal v) { return std::clamp(v, 0.0, limit); };
    topLeft = clamp(topLeft); topRight = clamp(topRight);
    bottomRight = clamp(bottomRight); bottomLeft = clamp(bottomLeft);
    path.moveTo(r.left() + topLeft, r.top());
    path.lineTo(r.right() - topRight, r.top());
    path.arcTo(QRectF(r.right() - 2 * topRight, r.top(), 2 * topRight, 2 * topRight), 90, -90);
    path.lineTo(r.right(), r.bottom() - bottomRight);
    path.arcTo(QRectF(r.right() - 2 * bottomRight, r.bottom() - 2 * bottomRight, 2 * bottomRight, 2 * bottomRight), 0, -90);
    path.lineTo(r.left() + bottomLeft, r.bottom());
    path.arcTo(QRectF(r.left(), r.bottom() - 2 * bottomLeft, 2 * bottomLeft, 2 * bottomLeft), 270, -90);
    path.lineTo(r.left(), r.top() + topLeft);
    path.arcTo(QRectF(r.left(), r.top(), 2 * topLeft, 2 * topLeft), 180, -90);
    path.closeSubpath();
    return path;
}

// A track segment along an axis. `startRadius` applies to the end nearer the
// axis origin (left / top), `endRadius` to the far end.
inline QPainterPath segment(const QRectF &track, bool horizontal, qreal from, qreal to,
                            qreal startRadius, qreal endRadius)
{
    if (to <= from) return {};
    QRectF r = track;
    if (horizontal) { r.setLeft(from); r.setRight(to); }
    else { r.setTop(from); r.setBottom(to); }
    return horizontal ? roundedPath(r, startRadius, endRadius, endRadius, startRadius)
                      : roundedPath(r, startRadius, startRadius, endRadius, endRadius);
}

} // namespace MeoTrack
