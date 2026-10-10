#pragma once

#include <QtWidgets/QProxyStyle>
#include <memory>

class MeoStyleAnimationEngine;

class MeoStyle : public QProxyStyle
{
    Q_OBJECT

public:
    MeoStyle();
    ~MeoStyle() override;
    using QProxyStyle::polish;
    using QProxyStyle::unpolish;
    void polish(QWidget *widget) override;
    void unpolish(QWidget *widget) override;

    QPalette standardPalette() const override;
    QIcon standardIcon(StandardPixmap icon, const QStyleOption *option = nullptr,
                       const QWidget *widget = nullptr) const override;
    int pixelMetric(PixelMetric metric, const QStyleOption *option = nullptr,
                    const QWidget *widget = nullptr) const override;
    int styleHint(StyleHint hint, const QStyleOption *option = nullptr,
                  const QWidget *widget = nullptr, QStyleHintReturn *returnData = nullptr) const override;
    SubControl hitTestComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                                    const QPoint &position, const QWidget *widget = nullptr) const override;
    QSize sizeFromContents(ContentsType type, const QStyleOption *option,
                           const QSize &contentsSize, const QWidget *widget) const override;
    QRect subElementRect(SubElement element, const QStyleOption *option,
                         const QWidget *widget = nullptr) const override;
    QRect subControlRect(ComplexControl control, const QStyleOptionComplex *option,
                         SubControl subControl, const QWidget *widget = nullptr) const override;
    void drawPrimitive(PrimitiveElement element, const QStyleOption *option,
                       QPainter *painter, const QWidget *widget = nullptr) const override;
    void drawControl(ControlElement element, const QStyleOption *option,
                     QPainter *painter, const QWidget *widget = nullptr) const override;
    void drawComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                            QPainter *painter, const QWidget *widget = nullptr) const override;
    // Render-driven channels retain no input ownership; nullptr/offscreen
    // callers receive the target immediately.
    qreal animatedValue(const QWidget *widget, const QString &channel, qreal target, bool spatial = false) const;
private:
    std::unique_ptr<MeoStyleAnimationEngine> m_animation;
};
