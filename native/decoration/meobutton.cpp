#include "meobutton.h"
#include "meodecoration.h"

#include <QEasingCurve>
#include <QEvent>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainterPath>
#include <QRadialGradient>
#include <QLineF>
#include <QtMath>
#include <KDecoration3/Decoration>

namespace MeoDecoration {

Button::Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
    , m_decoration(decoration)
{
    if (decoration) {
        int hitSz = decoration->config().buttonHitSize;
        setGeometry(QRectF(0, 0, hitSz, hitSz));
    } else {
        setGeometry(QRectF(0, 0, 26, 26));
    }

    m_groupHoverAnim = new QVariantAnimation(this);
    m_groupHoverAnim->setDuration(160);
    m_groupHoverAnim->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_groupHoverAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_groupHoverOpacity = value.toReal();
        update();
    });

    m_directHoverAnim = new QVariantAnimation(this);
    m_directHoverAnim->setDuration(140);
    m_directHoverAnim->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_directHoverAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_directHoverOpacity = value.toReal();
        update();
    });

    m_rippleAnim = new QVariantAnimation(this);
    m_rippleAnim->setDuration(240);
    m_rippleAnim->setEasingCurve(QEasingCurve::OutQuad);
    connect(m_rippleAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_rippleProgress = value.toReal();
        update();
    });

    m_rippleFadeAnim = new QVariantAnimation(this);
    m_rippleFadeAnim->setDuration(180);
    m_rippleFadeAnim->setEasingCurve(QEasingCurve::OutQuad);
    connect(m_rippleFadeAnim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_rippleOpacity = value.toReal();
        update();
    });
}

Button::~Button() = default;

void Button::setGroupHovered(bool hovered)
{
    animateGroupHover(hovered ? 1.0 : 0.0);
}

void Button::animateGroupHover(qreal target)
{
    m_groupHoverAnim->stop();
    m_groupHoverAnim->setStartValue(m_groupHoverOpacity);
    m_groupHoverAnim->setEndValue(target);
    m_groupHoverAnim->start();
}

void Button::animateDirectHover(qreal target)
{
    m_directHoverAnim->stop();
    m_directHoverAnim->setStartValue(m_directHoverOpacity);
    m_directHoverAnim->setEndValue(target);
    m_directHoverAnim->start();
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

bool Button::event(QEvent *event)
{
    switch (event->type()) {
    case QEvent::HoverEnter:
        animateDirectHover(1.0);
        if (m_decoration) {
            m_decoration->updateGroupHoverState();
        }
        break;
    case QEvent::HoverLeave:
        animateDirectHover(0.0);
        if (m_decoration) {
            m_decoration->updateGroupHoverState();
        }
        break;
    case QEvent::MouseButtonPress: {
        auto mouseEv = static_cast<QMouseEvent*>(event);
        startRipple(mouseEv->position());
        break;
    }
    case QEvent::MouseButtonRelease:
        m_rippleFadeAnim->stop();
        m_rippleFadeAnim->setStartValue(m_rippleOpacity);
        m_rippleFadeAnim->setEndValue(0.0);
        m_rippleFadeAnim->start();
        break;
    default:
        break;
    }
    return KDecoration3::DecorationButton::event(event);
}

void Button::paint(QPainter *painter, const QRectF &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter || !m_decoration) return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const auto &cfg = m_decoration->config();
    const QRectF hitRect = geometry();
    const QPointF center = hitRect.center();

    // The hit target intentionally remains larger than the visible control.
    // Material controls use a generous target with a compact circular affordance.
    const qreal circleRadius = qMax<qreal>(1.0, cfg.buttonDiameter / 2.0);
    const bool active = m_decoration->isWindowActive();
    const bool isCloseBtn = (type() == KDecoration3::DecorationButtonType::Close);

    qreal combinedHover = qMax(m_groupHoverOpacity, m_directHoverOpacity);

    // 1. Draw Circular Drop Shadow when Group Hovered or Direct Hovered
    if (cfg.showButtonBackground && combinedHover > 0.001) {
        qreal shadowRadius = circleRadius + 3.5;
        QRadialGradient shadowGrad(center, shadowRadius);
        shadowGrad.setColorAt(0.0, QColor(0, 0, 0, int(28 * combinedHover)));
        shadowGrad.setColorAt(0.65, QColor(0, 0, 0, int(10 * combinedHover)));
        shadowGrad.setColorAt(1.0, QColor(0, 0, 0, 0));

        painter->setPen(Qt::NoPen);
        painter->setBrush(shadowGrad);
        painter->drawEllipse(center, shadowRadius, shadowRadius);

        // 2. Draw Circular Background (Group Hover vs Direct Hover Darkening)
        QColor circleColor;
        if (isCloseBtn) {
            // Group hover: soft red (180 alpha). Direct hover: deeper vivid red (235 alpha).
            int alpha = int(180 * m_groupHoverOpacity + (235 - 180) * m_directHoverOpacity);
            int redVal = int(229 - (229 - 211) * m_directHoverOpacity);
            circleColor = QColor(redVal, 57, 53, alpha);
        } else {
            // Group hover: light circle (16 alpha). Direct hover: deepened circle (36 alpha).
            int alpha = int(16 * m_groupHoverOpacity + (36 - 16) * m_directHoverOpacity);
            if (!active) alpha = int(alpha * 0.75);
            circleColor = QColor(0, 0, 0, alpha);
        }

        painter->setBrush(circleColor);
        painter->drawEllipse(center, circleRadius, circleRadius);
    }

    // 3. Draw Press Ripple Expansion Animation from Mouse Press Origin
    if (m_rippleOpacity > 0.001 && m_rippleProgress > 0.001) {
        // Convert m_pressPos (button-local coords) to painter's decoration coords:
        QPointF pressPosInDeco = hitRect.topLeft() + m_pressPos;

        QPainterPath clipBounds;
        clipBounds.addEllipse(center, circleRadius, circleRadius);

        painter->save();
        painter->setClipPath(clipBounds);

        qreal maxDist = qMax(QLineF(pressPosInDeco, center).length() + circleRadius, circleRadius * 2.0);
        qreal currentRippleRadius = maxDist * m_rippleProgress;

        QColor rippleColor;
        if (isCloseBtn) {
            rippleColor = QColor(183, 28, 28, int(200 * m_rippleOpacity));
        } else {
            rippleColor = QColor(0, 0, 0, int(50 * m_rippleOpacity));
        }

        painter->setPen(Qt::NoPen);
        painter->setBrush(rippleColor);
        painter->drawEllipse(pressPosInDeco, currentRippleRadius, currentRippleRadius);

        painter->restore();
    }

    // 4. Vector Icon Drawing
    QColor iconColor;
    if (isCloseBtn && combinedHover > 0.3) {
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
    case KDecoration3::DecorationButtonType::Minimize: {
        qreal halfW = 3.2;
        painter->drawLine(QPointF(center.x() - halfW, center.y()),
                          QPointF(center.x() + halfW, center.y()));
        break;
    }
    case KDecoration3::DecorationButtonType::Maximize: {
        if (isChecked()) { // Restore
            QRectF backBox(center.x() - 1.5, center.y() - 3.5, 4.5, 4.5);
            QRectF frontBox(center.x() - 3.5, center.y() - 1.5, 4.5, 4.5);
            painter->drawRect(backBox);
            painter->drawRect(frontBox);
        } else { // Maximize
            QRectF box(center.x() - 3.2, center.y() - 3.2, 6.4, 6.4);
            painter->drawRect(box);
        }
        break;
    }
    case KDecoration3::DecorationButtonType::Close: {
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
