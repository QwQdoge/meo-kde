#pragma once

#include <KDecoration3/DecorationButton>
#include <QPainter>
#include <QPointF>
#include <QVariantAnimation>

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
    void animateHover(qreal target, int duration);
    void beginRipple(const QPointF &position);

    Decoration *m_decoration = nullptr;
    QVariantAnimation *m_hoverAnimation = nullptr;
    QVariantAnimation *m_rippleAnimation = nullptr;
    qreal m_hoverProgress = 0.0;
    qreal m_rippleProgress = 1.0;
    QPointF m_rippleOrigin;
};

} // namespace MeoDecoration
