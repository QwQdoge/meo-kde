#include "meostyle.h"

#include "meostylehelper.h"

#include <QtGui/QPainter>
#include <QtWidgets/QStyleFactory>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionProgressBar>
#include <QtWidgets/QStyleOptionTab>

#include <meotokens.h>

namespace {

qreal controlRadius()
{
    return Meo::DesignTokens::shapeMedium();
}

QPalette::ColorGroup colorGroup(const QStyleOption *option)
{
    return option->state.testFlag(QStyle::State_Enabled) ? QPalette::Active : QPalette::Disabled;
}

} // namespace

MeoStyle::MeoStyle()
    : QProxyStyle(QStyleFactory::create(QStringLiteral("Fusion")))
{
    setObjectName(QStringLiteral("Meo"));
}

QPalette MeoStyle::standardPalette() const
{
    // Preserve the platform's active light/dark/accent palette. Meo surface
    // treatment is layered at paint time instead of freezing a material colour.
    return QProxyStyle::standardPalette();
}

int MeoStyle::pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const
{
    switch (metric) {
    case PM_DefaultFrameWidth:
    case PM_SpinBoxFrameWidth:
        return qRound(Meo::DesignTokens::space2() / 2.0);
    case PM_ButtonMargin:
        return qRound(Meo::DesignTokens::space12());
    case PM_IndicatorWidth:
    case PM_IndicatorHeight:
    case PM_ExclusiveIndicatorWidth:
    case PM_ExclusiveIndicatorHeight:
        return qRound(Meo::DesignTokens::iconSizeS());
    case PM_ScrollBarExtent:
        return qRound(Meo::DesignTokens::space12() + Meo::DesignTokens::space2());
    case PM_SliderLength:
        return qRound(Meo::DesignTokens::iconSizeS());
    default:
        return QProxyStyle::pixelMetric(metric, option, widget);
    }
}

QSize MeoStyle::sizeFromContents(ContentsType type, const QStyleOption *option,
                                  const QSize &contentsSize, const QWidget *widget) const
{
    QSize result = QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
    switch (type) {
    case CT_PushButton:
    case CT_ToolButton:
        result.setHeight(qMax(result.height(), qRound(Meo::DesignTokens::buttonHeightS())));
        break;
    case CT_LineEdit:
    case CT_ComboBox:
    case CT_SpinBox:
        result.setHeight(qMax(result.height(), qRound(Meo::DesignTokens::buttonHeightS())));
        break;
    default:
        break;
    }
    return result;
}

void MeoStyle::drawPrimitive(PrimitiveElement element, const QStyleOption *option,
                             QPainter *painter, const QWidget *widget) const
{
    const bool enabled = option->state.testFlag(State_Enabled);
    const bool hover = option->state.testFlag(State_MouseOver);
    const bool pressed = option->state.testFlag(State_Sunken);
    const bool focus = option->state.testFlag(State_HasFocus);
    const QPalette::ColorGroup group = colorGroup(option);

    if (element == PE_PanelButtonCommand) {
        const QColor fill = enabled ? MeoStyleHelper::stateLayer(option->palette, group, hover, pressed)
                                    : option->palette.color(QPalette::Disabled, QPalette::Button);
        MeoStyleHelper::drawRoundedSurface(painter, option->rect, controlRadius(), fill);
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, option->rect, controlRadius(),
                                           option->palette.color(group, QPalette::Highlight));
        }
        return;
    }

    if (element == PE_FrameLineEdit) {
        const QColor outline = option->palette.color(group, focus ? QPalette::Highlight : QPalette::Mid);
        MeoStyleHelper::drawRoundedSurface(painter, option->rect.adjusted(0.5, 0.5, -0.5, -0.5),
                                            Meo::DesignTokens::shapeSmall(),
                                            option->palette.color(group, QPalette::Base), outline);
        return;
    }

    if (element == PE_IndicatorCheckBox || element == PE_IndicatorRadioButton) {
        const QRectF indicator = option->rect.adjusted(1.0, 1.0, -1.0, -1.0);
        const bool checked = option->state.testFlag(State_On);
        const bool partial = option->state.testFlag(State_NoChange);
        const QColor primary = option->palette.color(group, QPalette::Highlight);
        const QColor outline = option->palette.color(group, QPalette::Mid);
        if (element == PE_IndicatorRadioButton) {
            MeoStyleHelper::drawRoundedSurface(painter, indicator, indicator.width() / 2.0,
                                                checked ? primary : option->palette.color(group, QPalette::Base), outline);
            if (checked) {
                MeoStyleHelper::drawRoundedSurface(painter, indicator.adjusted(5.0, 5.0, -5.0, -5.0),
                                                    indicator.width() / 2.0,
                                                    option->palette.color(group, QPalette::HighlightedText));
            }
        } else {
            MeoStyleHelper::drawRoundedSurface(painter, indicator, Meo::DesignTokens::shapeExtraSmall(),
                                                checked || partial ? primary : option->palette.color(group, QPalette::Base),
                                                checked || partial ? primary : outline);
            if (checked) {
                MeoStyleHelper::drawCheckMark(painter, indicator,
                                               option->palette.color(group, QPalette::HighlightedText));
            } else if (partial) {
                painter->fillRect(indicator.adjusted(4.0, indicator.height() / 2.0 - 1.0,
                                                     -4.0, -indicator.height() / 2.0 + 1.0),
                                  option->palette.color(group, QPalette::HighlightedText));
            }
        }
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, option->rect.adjusted(-2.0, -2.0, 2.0, 2.0),
                                           controlRadius(), primary);
        }
        return;
    }

    QProxyStyle::drawPrimitive(element, option, painter, widget);
}

void MeoStyle::drawControl(ControlElement element, const QStyleOption *option,
                           QPainter *painter, const QWidget *widget) const
{
    if (element == CE_ProgressBarGroove) {
        MeoStyleHelper::drawRoundedSurface(painter, option->rect, option->rect.height() / 2.0,
                                            option->palette.color(colorGroup(option), QPalette::Midlight));
        return;
    }
    if (element == CE_ProgressBarContents) {
        const auto *progress = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (progress && progress->maximum > progress->minimum) {
            const qreal ratio = qBound<qreal>(0.0,
                qreal(progress->progress - progress->minimum) / qreal(progress->maximum - progress->minimum), 1.0);
            QRectF fill = option->rect;
            fill.setWidth(fill.width() * ratio);
            MeoStyleHelper::drawRoundedSurface(painter, fill, fill.height() / 2.0,
                                                option->palette.color(colorGroup(option), QPalette::Highlight));
        }
        return;
    }
    QProxyStyle::drawControl(element, option, painter, widget);
}
