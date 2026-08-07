#include "meobutton.h"
#include "meodecoration.h"

#include <QEasingCurve>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainterPath>
#include <QRadialGradient>
#include <QLineF>
#include <QtMath>
#include <KDecoration2/Decoration>

namespace MeoDecoration {

Button::Button(KDecoration2::DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration2::DecorationButton(type, decoration, parent)
    , m_decoration(decoration)
{
    m_hoverAnim = new QVariantAnimation(this);
    m_hoverAnim->setDuration(180);
    m_hoverAnim->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_hoverAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_hoverOpacity = value.toReal();
        update();
    });

    m_rippleAnim = new QVariantAnimation(this);
    m_rippleAnim->setDuration(220);
    m_rippleAnim->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_rippleAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_rippleProgress = value.toReal();
        update();
    });

    m_rippleFadeAnim = new QVariantAnimation(this);
    m_rippleFadeAnim->setDuration(160);
    m_rippleFadeAnim->setEasingCurve(QEasingCurve::OutQuad);
    connect(m_rippleFadeAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_rippleOpacity = value.toReal();
        update();
    });
}

Button::~Button() = default;

void Button::animateHover(qreal targetOpacity)
{
    m_hoverAnim->stop();
    m_hoverAnim->setStartValue(m_hoverOpacity);
    m_hoverAnim->setEndValue(targetOpacity);
    m_hoverAnim->start();
}

void Button::startRipple(const QPointF &pressPos)
{
    m_pressPos = pressPos;
    m_rippleProgress = 0.0;
    m_rippleOpacity = 1.0;

    m_rippleAnim->stop();
    m_rippleAnim->setStartValue(0.0);
    m_rippleAnim->setEndValue(1.0);
    m_rippleAnim->start();
}

void Button::hoverEnteredEvent(QHoverEvent *event)
{
    KDecoration2::DecorationButton::hoverEnteredEvent(event);
    m_hovered = true;
    animateHover(1.0);
}

void Button::hoverLeftEvent(QHoverEvent *event)
{
    KDecoration2::DecorationButton::hoverLeftEvent(event);
    m_hovered = false;
    animateHover(0.0);
}

void Button::mousePressEvent(QMouseEvent *event)
{
    KDecoration2::DecorationButton::mousePressEvent(event);
    m_pressed = true;
    startRipple(event->position());
}

void Button::mouseReleaseEvent(QMouseEvent *event)
{
    KDecoration2::DecorationButton::mouseReleaseEvent(event);
    m_pressed = false;
    
    m_rippleFadeAnim->stop();
    m_rippleFadeAnim->setStartValue(m_rippleOpacity);
    m_rippleFadeAnim->setEndValue(0.0);
    m_rippleFadeAnim->start();
}

void Button::paint(QPainter *painter, const QRect &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter || !m_decoration) return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const auto &cfg = m_decoration->config();
    const QRectF hitRect = geometry();
    const QPointF center = hitRect.center();

    qreal circleRadius = (cfg.buttonHitSize / 2.0) - 1.0;
    const bool active = m_decoration->isWindowActive();
    const bool isCloseBtn = (type() == KDecoration2::DecorationButtonType::Close);

    // 1. Draw Circular Drop Shadow on Hover (放上去有小圆形阴影)
    if (m_hoverOpacity > 0.001) {
        qreal shadowRadius = circleRadius + 3.5;
        QRadialGradient shadowGrad(center, shadowRadius);
        shadowGrad.setColorAt(0.0, QColor(0, 0, 0, int(30 * m_hoverOpacity)));
        shadowGrad.setColorAt(0.65, QColor(0, 0, 0, int(12 * m_hoverOpacity)));
        shadowGrad.setColorAt(1.0, QColor(0, 0, 0, 0));

        painter->setPen(Qt::NoPen);
        painter->setBrush(shadowGrad);
        painter->drawEllipse(center, shadowRadius, shadowRadius);

        // 2. Draw Circular Background on Hover (匹配截图的淡灰蓝/浅色圆框)
        QColor circleColor;
        if (isCloseBtn) {
            circleColor = QColor(229, 57, 53, int(210 * m_hoverOpacity)); // Soft red on close hover
        } else {
            circleColor = active ? QColor(0, 0, 0, int(22 * m_hoverOpacity)) : QColor(0, 0, 0, int(14 * m_hoverOpacity));
        }

        painter->setBrush(circleColor);
        painter->drawEllipse(center, circleRadius, circleRadius);
    }

    // 3. Draw Press Ripple Expansion Animation from Mouse Origin (按下时以鼠标点击点为中心的圆形遮罩扩散)
    if (m_rippleOpacity > 0.001 && m_rippleProgress > 0.001) {
        QPainterPath clipBounds;
        clipBounds.addEllipse(center, circleRadius, circleRadius);

        painter->save();
        painter->setClipPath(clipBounds);

        // Calculate maximum expansion radius from mouse press pos to fill the circle
        qreal maxDist = qMax(QLineF(m_pressPos, center).length() + circleRadius, circleRadius * 2.0);
        qreal currentRippleRadius = maxDist * m_rippleProgress;

        QColor rippleColor;
        if (isCloseBtn) {
            rippleColor = QColor(183, 28, 28, int(180 * m_rippleOpacity));
        } else {
            rippleColor = QColor(0, 0, 0, int(38 * m_rippleOpacity));
        }

        painter->setPen(Qt::NoPen);
        painter->setBrush(rippleColor);
        painter->drawEllipse(m_pressPos, currentRippleRadius, currentRippleRadius);

        painter->restore();
    }

    // 4. Clean Vector Icon Drawing (常态不动时只显示干净的图标)
    QColor iconColor;
    if (isCloseBtn && m_hoverOpacity > 0.5) {
        iconColor = Qt::white;
    } else {
        iconColor = m_decoration->titleTextColor();
        if (!active) {
            iconColor.setAlpha(150);
        }
    }

    QPen pen(iconColor, 1.35, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);

    switch (type()) {
    case KDecoration2::DecorationButtonType::Minimize: {
        qreal halfW = 3.2;
        painter->drawLine(QPointF(center.x() - halfW, center.y()),
                          QPointF(center.x() + halfW, center.y()));
        break;
    }
    case KDecoration2::DecorationButtonType::Maximize: {
        if (isChecked()) { // Restore (Double overlapping box)
            QRectF backBox(center.x() - 1.5, center.y() - 3.5, 4.5, 4.5);
            QRectF frontBox(center.x() - 3.5, center.y() - 1.5, 4.5, 4.5);
            painter->drawRect(backBox);
            painter->drawRect(frontBox);
        } else { // Maximize (Single square)
            QRectF box(center.x() - 3.2, center.y() - 3.2, 6.4, 6.4);
            painter->drawRect(box);
        }
        break;
    }
    case KDecoration2::DecorationButtonType::Close: {
        qreal sz = 3.0;
        painter->drawLine(QPointF(center.x() - sz, center.y() - sz),
                          QPointF(center.x() + sz, center.y() + sz));
        painter->drawLine(QPointF(center.x() + sz, center.y() - sz),
                          QPointF(center.x() - sz, center.y() + sz));
        break;
    }
    default:
        break;
    }

    painter->restore();
}

} // namespace MeoDecoration
