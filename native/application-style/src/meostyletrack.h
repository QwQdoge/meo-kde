#pragma once

#include <QtCore/QRectF>
#include <QtGui/QPainterPath>

#include <algorithm>

// Slider and linear-progress geometry from MeoUI's MeoSlider/MeoProgressBar.
// The native MeoUI token header does not carry these yet, so each value names
// the MeoTheme property it mirrors; move them there once MeoUI exports them.
namespace MeoTrack {

constexpr qreal sliderTrackHeight = 16.0;        // MeoTheme.sliderTrackHeightXS
constexpr qreal sliderTrackRadius = 8.0;         // MeoTheme.sliderTrackCornerRadiusXS
constexpr qreal sliderInsideRadius = 2.0;        // MeoTheme.sliderTrackInsideCornerRadius
constexpr qreal sliderThumbWidth = 4.0;          // MeoTheme.sliderThumbWidthExpressive
constexpr qreal sliderThumbPressedWidth = 2.0;   // MeoTheme.sliderThumbPressedWidthExpressive
constexpr qreal sliderThumbHeight = 44.0;        // MeoTheme.sliderThumbHeightXS
constexpr qreal sliderThumbGap = 6.0;            // MeoTheme.sliderThumbGapExpressive
constexpr qreal stopSize = 4.0;                  // MeoTheme.sliderStopSizeExpressive / progress end stop
constexpr qreal sliderHitLength = 20.0;          // pointer target along the axis; the bar stays 4dp

constexpr qreal progressThickness = 4.0;         // MeoProgressBar.trackThickness
constexpr qreal progressGap = 4.0;               // ProgressIndicatorDefaults TrackActiveSpace

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
