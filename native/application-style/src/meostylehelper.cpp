#include "meostylehelper.h"

#include <QtGui/QPainter>
#include <QtGui/QPainterPath>
#include <QtGui/QPen>

#include <meotokens.h>

namespace MeoStyleHelper {

QColor blend(const QColor &base, const QColor &overlay, qreal opacity)
{
    QColor result = overlay;
    result.setAlphaF(qBound<qreal>(0.0, opacity, 1.0));
    QImage image(1, 1, QImage::Format_ARGB32_Premultiplied);
    image.fill(base);
    QPainter painter(&image);
    painter.fillRect(image.rect(), result);
    return image.pixelColor(0, 0);
}

QColor stateLayer(const QPalette &palette, QPalette::ColorGroup group, bool hover, bool pressed)
{
    return stateLayer(palette, group, QPalette::Button, QPalette::ButtonText, hover, pressed);
}

QColor stateLayer(const QPalette &palette, QPalette::ColorGroup group,
                  QPalette::ColorRole surfaceRole, QPalette::ColorRole contentRole,
                  bool hover, bool pressed, bool focused)
{
    const QColor base = palette.color(group, surfaceRole);
    const QColor content = palette.color(group, contentRole);
    const qreal opacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                  : focused ? Meo::DesignTokens::stateOpacityFocus()
                                            : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0;
    return blend(base, content, opacity);
}

void drawRoundedSurface(QPainter *painter, const QRectF &rect, qreal radius,
                        const QColor &fill, const QColor &outline)
{
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setBrush(fill);
    painter->setPen(outline.isValid() ? QPen(outline, 1.0) : Qt::NoPen);
    painter->drawRoundedRect(rect, radius, radius);
    painter->restore();
}

void drawFocusRing(QPainter *painter, const QRectF &rect, qreal radius, const QColor &color)
{
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    QPen pen(color, Meo::DesignTokens::focusRingWidth());
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    painter->drawRoundedRect(rect.adjusted(1.0, 1.0, -1.0, -1.0), radius, radius);
    painter->restore();
}

void drawCheckMark(QPainter *painter, const QRectF &rect, const QColor &color)
{
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    QPen pen(color, 2.0, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    QPainterPath mark;
    mark.moveTo(rect.left() + rect.width() * 0.22, rect.center().y());
    mark.lineTo(rect.left() + rect.width() * 0.43, rect.bottom() - rect.height() * 0.24);
    mark.lineTo(rect.right() - rect.width() * 0.18, rect.top() + rect.height() * 0.25);
    painter->drawPath(mark);
    painter->restore();
}

void drawChevron(QPainter *painter, const QRectF &rect, const QColor &color, Qt::ArrowType direction)
{
    const qreal extent = qMin(qMin(rect.width(), rect.height()), Meo::DesignTokens::space8());
    const qreal half = extent / 2.0;
    const QPointF center = rect.center();

    QPainterPath path;
    switch (direction) {
    case Qt::UpArrow:
        path.moveTo(center.x() - half, center.y() + half / 2.0);
        path.lineTo(center.x(), center.y() - half / 2.0);
        path.lineTo(center.x() + half, center.y() + half / 2.0);
        break;
    case Qt::LeftArrow:
        path.moveTo(center.x() + half / 2.0, center.y() - half);
        path.lineTo(center.x() - half / 2.0, center.y());
        path.lineTo(center.x() + half / 2.0, center.y() + half);
        break;
    case Qt::RightArrow:
        path.moveTo(center.x() - half / 2.0, center.y() - half);
        path.lineTo(center.x() + half / 2.0, center.y());
        path.lineTo(center.x() - half / 2.0, center.y() + half);
        break;
    case Qt::DownArrow:
    default:
        path.moveTo(center.x() - half, center.y() - half / 2.0);
        path.lineTo(center.x(), center.y() + half / 2.0);
        path.lineTo(center.x() + half, center.y() - half / 2.0);
        break;
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setBrush(Qt::NoBrush);
    painter->setPen(QPen(color, Meo::DesignTokens::space2(), Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    painter->drawPath(path);
    painter->restore();
}

} // namespace MeoStyleHelper
