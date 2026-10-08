#include "meostyle.h"

#include <QtCore/QtGlobal>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QWidget>

#include <meotokens.h>

namespace {

int px(qreal value)
{
    return qRound(value);
}

QRect meoVisualRect(const QStyleOption *option, const QRect &logical)
{
    if (!option) {
        return logical;
    }
    return QStyle::visualRect(option->direction, option->rect, logical);
}

QRect centeredLeadingIndicator(const QStyleOption *option)
{
    if (!option) {
        return {};
    }

    const int size = px(Meo::DesignTokens::iconSizeS());
    const int inset = px(Meo::DesignTokens::space4());
    const QRect logical(option->rect.left() + inset,
                        option->rect.center().y() - size / 2,
                        size,
                        size);
    return meoVisualRect(option, logical);
}

QRect labeledControlContents(const QStyleOption *option)
{
    if (!option) {
        return {};
    }

    const int indicator = px(Meo::DesignTokens::iconSizeS());
    const int leading = px(Meo::DesignTokens::space4()) + indicator
        + px(Meo::DesignTokens::space8());
    const int trailing = px(Meo::DesignTokens::space4());
    const QRect logical = option->rect.adjusted(leading, 0, -trailing, 0);
    return meoVisualRect(option, logical);
}

} // namespace

QRect MeoStyle::subElementRect(SubElement element, const QStyleOption *option,
                               const QWidget *widget) const
{
    if (!option) {
        return QProxyStyle::subElementRect(element, option, widget);
    }

    switch (element) {
    case SE_PushButtonContents: {
        const int horizontal = px(Meo::DesignTokens::space16());
        const int vertical = px(Meo::DesignTokens::space4());
        return option->rect.adjusted(horizontal, vertical, -horizontal, -vertical);
    }
    case SE_PushButtonFocusRect:
        return option->rect.adjusted(px(Meo::DesignTokens::space2()),
                                     px(Meo::DesignTokens::space2()),
                                     -px(Meo::DesignTokens::space2()),
                                     -px(Meo::DesignTokens::space2()));
    case SE_LineEditContents: {
        const bool searchField = widget
            && widget->property("meo.role").toString() == QLatin1String("search");
        const int horizontal = px(searchField ? Meo::DesignTokens::space16()
                                              : Meo::DesignTokens::space12());
        const int vertical = px(Meo::DesignTokens::space4());
        return option->rect.adjusted(horizontal, vertical, -horizontal, -vertical);
    }
    case SE_CheckBoxIndicator:
    case SE_RadioButtonIndicator:
        return centeredLeadingIndicator(option);
    case SE_CheckBoxContents:
    case SE_RadioButtonContents:
        return labeledControlContents(option);
    case SE_ComboBoxFocusRect: {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        if (combo) {
            return subControlRect(CC_ComboBox, combo, SC_ComboBoxEditField, widget);
        }
        break;
    }
    default:
        break;
    }

    return QProxyStyle::subElementRect(element, option, widget);
}

QRect MeoStyle::subControlRect(ComplexControl control, const QStyleOptionComplex *option,
                               SubControl subControl, const QWidget *widget) const
{
    if (!option) {
        return QProxyStyle::subControlRect(control, option, subControl, widget);
    }

    if (control == CC_ComboBox) {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        if (!combo) {
            return QProxyStyle::subControlRect(control, option, subControl, widget);
        }

        const int arrowWidth = qMin(option->rect.width(),
                                    px(Meo::DesignTokens::controlHeight()));
        const int contentLeading = px(Meo::DesignTokens::space12());
        const int contentTrailing = px(Meo::DesignTokens::space8());
        const int vertical = px(Meo::DesignTokens::space4());

        switch (subControl) {
        case SC_ComboBoxFrame:
        case SC_ComboBoxListBoxPopup:
            return option->rect;
        case SC_ComboBoxArrow: {
            const QRect logical(option->rect.right() - arrowWidth + 1,
                                option->rect.top(),
                                arrowWidth,
                                option->rect.height());
            return meoVisualRect(option, logical);
        }
        case SC_ComboBoxEditField: {
            const int width = qMax(0, option->rect.width() - contentLeading
                                      - arrowWidth - contentTrailing);
            const QRect logical(option->rect.left() + contentLeading,
                                option->rect.top() + vertical,
                                width,
                                qMax(0, option->rect.height() - 2 * vertical));
            return meoVisualRect(option, logical);
        }
        default:
            break;
        }
    }

    if (control == CC_ToolButton) {
        const auto *toolButton = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        if (!toolButton) {
            return QProxyStyle::subControlRect(control, option, subControl, widget);
        }

        const bool split = toolButton->features.testFlag(QStyleOptionToolButton::MenuButtonPopup);
        if (!split) {
            if (subControl == SC_ToolButton) {
                return option->rect;
            }
            if (subControl == SC_ToolButtonMenu) {
                return {};
            }
        }

        const int menuWidth = qMin(option->rect.width(),
                                   px(Meo::DesignTokens::space32()));
        if (subControl == SC_ToolButtonMenu) {
            const QRect logical(option->rect.right() - menuWidth + 1,
                                option->rect.top(),
                                menuWidth,
                                option->rect.height());
            return meoVisualRect(option, logical);
        }
        if (subControl == SC_ToolButton) {
            const QRect logical(option->rect.left(),
                                option->rect.top(),
                                qMax(0, option->rect.width() - menuWidth),
                                option->rect.height());
            return meoVisualRect(option, logical);
        }
    }

    if (control == CC_Slider) {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) {
            return QProxyStyle::subControlRect(control, option, subControl, widget);
        }

        const int handleLength = px(Meo::DesignTokens::iconSizeS());
        const int halfHandle = handleLength / 2;

        if (subControl == SC_SliderGroove) {
            if (slider->orientation == Qt::Horizontal) {
                return option->rect.adjusted(halfHandle, 0, -halfHandle, 0);
            }
            return option->rect.adjusted(0, halfHandle, 0, -halfHandle);
        }

        if (subControl == SC_SliderHandle) {
            if (slider->orientation == Qt::Horizontal) {
                const int span = qMax(0, option->rect.width() - handleLength);
                const int pos = sliderPositionFromValue(slider->minimum,
                                                        slider->maximum,
                                                        slider->sliderPosition,
                                                        span,
                                                        slider->upsideDown);
                return QRect(option->rect.left() + pos,
                             option->rect.center().y() - handleLength / 2,
                             handleLength,
                             handleLength);
            }

            const int span = qMax(0, option->rect.height() - handleLength);
            const int pos = sliderPositionFromValue(slider->minimum,
                                                    slider->maximum,
                                                    slider->sliderPosition,
                                                    span,
                                                    slider->upsideDown);
            return QRect(option->rect.center().x() - handleLength / 2,
                         option->rect.top() + pos,
                         handleLength,
                         handleLength);
        }
    }

    return QProxyStyle::subControlRect(control, option, subControl, widget);
}
