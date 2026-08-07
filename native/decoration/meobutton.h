#pragma once

#include <KDecoration3/DecorationButton>
#include <QVariantAnimation>
#include <QPainter>
#include <QPointF>

namespace MeoDecoration {

class Decoration;

class Button : public KDecoration3::DecorationButton {
    Q_OBJECT
public:
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);
    ~Button() override;

    void paint(QPainter *painter, const QRectF &repaintRegion) override;
    bool event(QEvent *event) override;

    void setGroupHovered(bool hovered);

private:
    void animateGroupHover(qreal target);
    void animateDirectHover(qreal target);
    void startRipple(const QPointF &pressPos);

    Decoration *m_decoration = nullptr;

    qreal m_groupHoverOpacity = 0.0;
    QVariantAnimation *m_groupHoverAnim = nullptr;

    qreal m_directHoverOpacity = 0.0;
    QVariantAnimation *m_directHoverAnim = nullptr;

    QPointF m_pressPos;
    qreal m_rippleProgress = 0.0;
    qreal m_rippleOpacity = 0.0;
    QVariantAnimation *m_rippleAnim = nullptr;
    QVariantAnimation *m_rippleFadeAnim = nullptr;
};

} // namespace MeoDecoration
