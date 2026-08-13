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
    const QColor base = palette.color(group, QPalette::Button);
    const QColor content = palette.color(group, QPalette::ButtonText);
    return blend(base, content, pressed ? Meo::DesignTokens::stateOpacityPressed()
                                        : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0);
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
    QPen pen(color, Meo::DesignTokens::space2());
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

} // namespace MeoStyleHelper
