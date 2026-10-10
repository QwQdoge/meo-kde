#include "meostylegroup.h"
#include "meostyleheader.h"
#include "meostyleitem.h"
#include "meostyle.h"
#include "meostyletab.h"

#include <QtCore/QtGlobal>
#include <initializer_list>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionSpinBox>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QStyleOptionToolBar>
#include <QtWidgets/QLayout>
#include <QtWidgets/QWidget>

#include <meodesigntokens.h>

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

    if (const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option)) {
        if (element == SE_HeaderLabel) return MeoHeader::labelRect(*header);
        if (element == SE_HeaderArrow) return MeoHeader::arrowRect(*header);
    }
    if (const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option)) {
        const auto layout = MeoTab::layout(*tab);
        if (element == SE_TabBarTabText) return layout.physical(layout.content);
        if (element == SE_TabBarTabLeftButton) return layout.physical(layout.leftButton);
        if (element == SE_TabBarTabRightButton) return layout.physical(layout.rightButton);
    }
    if (const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option)) {
        const auto layout = MeoItem::layout(*item);
        if (element == SE_ItemViewItemText) return layout.text;
        if (element == SE_ItemViewItemDecoration) return layout.decoration;
        if (element == SE_ItemViewItemCheckIndicator) return layout.check;
        if (element == SE_ItemViewItemFocusRect) return item->rect.adjusted(1, 1, -1, -1);
    }
    switch (element) {
    case SE_ProgressBarGroove:
    case SE_ProgressBarContents:
    case SE_ProgressBarLabel:
        return option->rect;
    case SE_ToolBarHandle: {
        if (const auto *bar = qstyleoption_cast<const QStyleOptionToolBar *>(option)) {
            if (!bar->features.testFlag(QStyleOptionToolBar::Movable)) return {};
            const int inset = px(Meo::DesignTokens::space4());
            const QMargins margins = widget && widget->layout() ? widget->layout()->contentsMargins() : QMargins(inset, inset, inset, inset);
            QRect rect = option->rect.marginsRemoved(margins);
            const int extent = pixelMetric(PM_ToolBarHandleExtent, option, widget);
            if (bar->state.testFlag(State_Horizontal)) {
                rect.setWidth(qMin(extent, qMax(0, rect.width())));
                return meoVisualRect(option, rect);
            }
            rect.setHeight(qMin(extent, qMax(0, rect.height())));
            return rect;
        }
        return {};
    }
    case SE_GroupBoxLayoutItem: return option->rect;
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

    if (control == CC_GroupBox) {
        if (const auto *group = qstyleoption_cast<const QStyleOptionGroupBox *>(option)) {
            const auto layout = MeoGroup::layout(*group);
            switch (subControl) {
            case SC_GroupBoxFrame: return layout.frame;
            case SC_GroupBoxContents: return layout.contents;
            case SC_GroupBoxLabel: return layout.label;
            case SC_GroupBoxCheckBox: return layout.check;
            default: return {};
            }
        }
    }
    if (control == CC_SpinBox) {
        if (const auto *spin = qstyleoption_cast<const QStyleOptionSpinBox *>(option)) {
            const int width = spin->buttonSymbols == QAbstractSpinBox::NoButtons ? 0
                : qMin(option->rect.width(), px(Meo::DesignTokens::space32()));
            const int topHeight = option->rect.height() / 2;
            switch (subControl) {
            case SC_SpinBoxFrame: return option->rect;
            case SC_SpinBoxUp:
                return width ? meoVisualRect(option, QRect(option->rect.right() - width + 1, option->rect.top(), width, topHeight)) : QRect();
            case SC_SpinBoxDown:
                return width ? meoVisualRect(option, QRect(option->rect.right() - width + 1, option->rect.top() + topHeight, width, option->rect.height() - topHeight)) : QRect();
            case SC_SpinBoxEditField:
                return meoVisualRect(option, QRect(option->rect.left() + px(Meo::DesignTokens::space12()),
                    option->rect.top() + px(Meo::DesignTokens::space4()),
                    qMax(0, option->rect.width() - width - px(Meo::DesignTokens::space12()) - px(Meo::DesignTokens::space8())),
                    qMax(0, option->rect.height() - 2 * px(Meo::DesignTokens::space4()))));
            default: return {};
            }
        }
    }
    if (control == CC_ScrollBar) {
        if (const auto *bar = qstyleoption_cast<const QStyleOptionSlider *>(option)) {
            const bool horizontal = bar->orientation == Qt::Horizontal;
            const int length = qMax(0, horizontal ? bar->rect.width() : bar->rect.height());
            const int end = qMin(length / 2, pixelMetric(PM_ScrollBarExtent, option, widget));
            const int track = qMax(0, length - 2 * end);
            const qint64 range = qMax<qint64>(0, qint64(bar->maximum) - bar->minimum);
            const qint64 page = qMax(0, bar->pageStep);
            int thumb = range == 0 ? track
                : int(page * track / qMax<qint64>(1, range + page));
            thumb = qBound(0, qMax(pixelMetric(PM_ScrollBarSliderMin, option, widget), thumb), track);
            const int start = end + sliderPositionFromValue(bar->minimum, bar->maximum, bar->sliderPosition, track - thumb, bar->upsideDown);
            auto rect = [&](int offset, int extent) {
                if (extent <= 0) return QRect();
                const QRect logical = horizontal
                    ? QRect(bar->rect.left() + offset, bar->rect.top(), extent, bar->rect.height())
                    : QRect(bar->rect.left(), bar->rect.top() + offset, bar->rect.width(), extent);
                return meoVisualRect(option, logical);
            };
            switch (subControl) {
            case SC_ScrollBarSubLine: return rect(0, end);
            case SC_ScrollBarAddLine: return rect(length - end, end);
            case SC_ScrollBarGroove: return rect(end, track);
            case SC_ScrollBarSlider: return rect(start, thumb);
            case SC_ScrollBarSubPage: return rect(end, start - end);
            case SC_ScrollBarAddPage: return rect(start + thumb, length - end - start - thumb);
            default: return {};
            }
        }
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

QStyle::SubControl MeoStyle::hitTestComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                                                 const QPoint &position, const QWidget *widget) const
{
    if (!option || !option->rect.contains(position)) return SC_None;
    // Hit-test the actual painted geometry. Qt may pass SC_None while querying
    // a scroll bar, so subControls is a paint mask rather than a hit-test mask.
    auto hit = [&](std::initializer_list<SubControl> parts) {
        for (const auto part : parts) {
            if (subControlRect(control, option, part, widget).contains(position)) return part;
        }
        return SC_None;
    };
    switch (control) {
    case CC_GroupBox: return hit({SC_GroupBoxCheckBox, SC_GroupBoxLabel});
    case CC_SpinBox: return hit({SC_SpinBoxUp, SC_SpinBoxDown, SC_SpinBoxEditField, SC_SpinBoxFrame});
    case CC_ScrollBar: return hit({SC_ScrollBarSlider, SC_ScrollBarSubLine, SC_ScrollBarAddLine, SC_ScrollBarSubPage, SC_ScrollBarAddPage});
    case CC_ComboBox: return hit({SC_ComboBoxArrow, SC_ComboBoxEditField, SC_ComboBoxFrame});
    case CC_ToolButton: return hit({SC_ToolButtonMenu, SC_ToolButton});
    default: return QProxyStyle::hitTestComplexControl(control, option, position, widget);
    }
}
