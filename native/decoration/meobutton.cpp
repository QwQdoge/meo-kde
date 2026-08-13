#include "meobutton.h"
#include "meodecoration.h"

#include <QEvent>
#include <QLineF>
#include <QMouseEvent>
#include <QPainterPath>
#include <QPainterPathStroker>
#include <QTransform>
#include <QtMath>

namespace MeoDecoration {
namespace {

constexpr qreal kGlyphViewport = 16.0;

QPainterPath centerGlyphPath(const QPainterPath &source,
                             const QPointF &targetCenter,
                             const QPointF &opticalOffset,
                             qreal strokeWidth)
{
    QPainterPathStroker stroker;
    stroker.setWidth(strokeWidth);
    stroker.setCapStyle(Qt::RoundCap);
    stroker.setJoinStyle(Qt::RoundJoin);
    const QRectF visualBounds = source.united(stroker.createStroke(source)).boundingRect();
    const QPointF translation = targetCenter - visualBounds.center() + opticalOffset;
    QTransform transform;
    transform.translate(translation.x(), translation.y());
    return transform.map(source);
}

} // namespace

Button::Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
    , m_decoration(decoration)
{
    const int hitSize = decoration ? decoration->config().buttonHitSize : 32;
    setGeometry(QRectF(0, 0, hitSize, hitSize));

    m_hoverAnimation = new QVariantAnimation(this);
    m_hoverAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_hoverAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_hoverProgress = value.toReal();
        update();
    });
    m_rippleAnimation = new QVariantAnimation(this);
    m_rippleAnimation->setDuration(180);
    m_rippleAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_rippleAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_rippleProgress = value.toReal();
        update();
    });
}

Button::~Button() = default;

bool Button::event(QEvent *event)
{
    switch (event->type()) {
    case QEvent::HoverEnter:
        animateHover(1.0, m_decoration->config().hoverInDuration);
        break;
    case QEvent::HoverLeave:
        animateHover(0.0, m_decoration->config().hoverOutDuration);
        break;
    case QEvent::MouseButtonPress:
        beginRipple(static_cast<QMouseEvent *>(event)->position());
        break;
    default:
        break;
    }
    return KDecoration3::DecorationButton::event(event);
}

void Button::animateHover(qreal target, int duration)
{
    m_hoverAnimation->stop();
    m_hoverAnimation->setDuration(duration);
    m_hoverAnimation->setStartValue(m_hoverProgress);
    m_hoverAnimation->setEndValue(target);
    m_hoverAnimation->start();
}

void Button::beginRipple(const QPointF &position)
{
    m_rippleOrigin = position;
    m_rippleAnimation->stop();
    m_rippleAnimation->setStartValue(0.0);
    m_rippleAnimation->setEndValue(1.0);
    m_rippleAnimation->start();
}

void Button::paint(QPainter *painter, const QRectF &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter || !m_decoration) {
        return;
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const QRectF hitRect = geometry();
    const QPointF center = hitRect.center();
    const qreal stateLayerDiameter = m_decoration->config().buttonDiameter;
    const QRectF interactionRect(center.x() - stateLayerDiameter / 2.0,
                                 center.y() - stateLayerDiameter / 2.0,
                                 stateLayerDiameter,
                                 stateLayerDiameter);
    const qreal hoverProgress = isPressed() ? 1.0 : m_hoverProgress;
    QColor interaction = m_decoration->titleTextColor();

    // Keep the 40px input target separate from the 30px interaction shape.
    // Close deliberately uses the same tonal feedback as the other controls.
    if (m_decoration->config().showButtonBackground && hoverProgress > 0.001) {
        interaction.setAlphaF(0.08 * hoverProgress);
        painter->setPen(Qt::NoPen);
        painter->setBrush(interaction);
        painter->drawEllipse(interactionRect);
    }

    if (m_rippleAnimation->state() == QAbstractAnimation::Running) {
        QPainterPath clip;
        clip.addEllipse(interactionRect);
        painter->save();
        painter->setClipPath(clip);
        const QPointF origin = hitRect.topLeft() + m_rippleOrigin;
        qreal maxDistance = 0.0;
        for (const QPointF &corner : {interactionRect.topLeft(), interactionRect.topRight(), interactionRect.bottomLeft(), interactionRect.bottomRight()}) {
            maxDistance = qMax(maxDistance, QLineF(origin, corner).length());
        }
        QColor ripple = m_decoration->titleTextColor();
        ripple.setAlphaF(0.06 * (1.0 - m_rippleProgress));
        painter->setPen(Qt::NoPen);
        painter->setBrush(ripple);
        painter->drawEllipse(origin, maxDistance * m_rippleProgress, maxDistance * m_rippleProgress);
        painter->restore();
    }

    QColor iconColor = m_decoration->titleTextColor();
    const qreal normalOpacity = m_decoration->captionIconOpacity();
    iconColor.setAlphaF((hoverProgress > 0.001 || isPressed()) ? 1.0 : normalOpacity);

    QPen pen(iconColor, 1.25, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);

    // Every caption glyph shares this centered 16px viewport. The button
    // slot and its position never participate in per-glyph corrections.
    const QRectF glyphViewport(center.x() - kGlyphViewport / 2.0,
                               center.y() - kGlyphViewport / 2.0,
                               kGlyphViewport,
                               kGlyphViewport);
    painter->save();
    painter->translate(glyphViewport.topLeft());

    switch (type()) {
    case KDecoration3::DecorationButtonType::Minimize:
        painter->drawLine(QPointF(4.5, 9.5), QPointF(11.5, 9.5));
        break;
    case KDecoration3::DecorationButtonType::Maximize:
        if (isChecked()) {
            constexpr qreal restoreStroke = 1.15;
            QPainterPath restorePath;
            restorePath.addRoundedRect(QRectF(4.75, 6.0, 6.25, 6.25), 0.55, 0.55);
            restorePath.moveTo(6.5, 4.75);
            restorePath.lineTo(11.5, 4.75);
            restorePath.quadTo(11.75, 4.75, 11.75, 5.0);
            restorePath.lineTo(11.75, 10.0);

            // Center the complete, stroke-aware composite—not only its
            // front rectangle—then apply the minimal optical correction.
            painter->setPen(QPen(iconColor, restoreStroke, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            painter->drawPath(centerGlyphPath(restorePath, QPointF(8.0, 8.0), QPointF(0.0, 0.5), restoreStroke));
        } else {
            painter->drawRoundedRect(QRectF(4.75, 4.75, 6.5, 6.5), 0.6, 0.6);
        }
        break;
    case KDecoration3::DecorationButtonType::Close:
        painter->drawLine(QPointF(4.75, 4.75), QPointF(11.25, 11.25));
        painter->drawLine(QPointF(11.25, 4.75), QPointF(4.75, 11.25));
        break;
    default:
        break;
    }

    painter->restore();

    painter->restore();
}

} // namespace MeoDecoration
