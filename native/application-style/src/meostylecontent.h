#pragma once

#include "meostyle.h"

class MeoStyleContent final : public MeoStyle
{
public:
    MeoStyleContent() = default;

    void drawControl(ControlElement element, const QStyleOption *option,
                     QPainter *painter, const QWidget *widget = nullptr) const override;
    void drawComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                            QPainter *painter, const QWidget *widget = nullptr) const override;
};
