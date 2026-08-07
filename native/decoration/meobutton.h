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

private:
    void animateHover(qreal targetOpacity);
    void startRipple(const QPointF &pressPos);

    Decoration *m_decoration = nullptr;
    bool m_hovered = false;
    bool m_pressed = false;

    qreal m_hoverOpacity = 0.0;
    QVariantAnimation *m_hoverAnim = nullptr;

    QPointF m_pressPos;
    qreal m_rippleProgress = 0.0;
    qreal m_rippleOpacity = 0.0;
    QVariantAnimation *m_rippleAnim = nullptr;
    QVariantAnimation *m_rippleFadeAnim = nullptr;
};

} // namespace MeoDecoration
