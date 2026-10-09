#include "meostyle.h"

#include "meostylehelper.h"
#include "meostylemotion.h"
#include <QAbstractButton>
#include <QLineEdit>
#include <QComboBox>
#include <QAbstractSlider>
#include <QProgressBar>

#include <QtGui/QPainterPath>
#include <QtGui/QPainter>
#include <QtWidgets/QApplication>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionComplex>
#include <QtWidgets/QStyleOptionMenuItem>
#include <QtWidgets/QStyleFactory>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionProgressBar>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionTab>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QStyleOptionViewItem>
#include <QtWidgets/QWidget>
#include <QtWidgets/QStyleOptionSpinBox>
#include <QAbstractSpinBox>
#include <QtWidgets/QStyleOptionHeader>
#include <QtWidgets/QStyleOptionGroupBox>
#include <QtGui/QTextLayout>
#include <QtCore/QVariant>

#include <meodesigntokens.h>

namespace {

qreal controlRadius()
{
    return Meo::DesignTokens::controlRadius();
}

qreal buttonRadius(const QStyleOption *option, bool pressed)
{
    const qreal halfHeight = qMax<qreal>(0.0, option->rect.height() / 2.0);
    if (!pressed) {
        return halfHeight;
    }
    return qMin(halfHeight,
                qMax(Meo::DesignTokens::controlPressedRadius(),
                     qMin(Meo::DesignTokens::controlRadius(),
                          halfHeight - Meo::DesignTokens::space8())));
}

enum class ButtonVisual {
    Filled,
    Tonal,
    Text,
};

ButtonVisual buttonVisual(const QStyleOptionButton *button, const QWidget *widget)
{
    const QString variant = widget ? widget->property("meo.variant").toString().toLower()
                                   : QString();
    if (variant == QLatin1String("filled")) {
        return ButtonVisual::Filled;
    }
    if (variant == QLatin1String("text") || (button && button->features.testFlag(QStyleOptionButton::Flat))) {
        return ButtonVisual::Text;
    }
    if (button && button->features.testFlag(QStyleOptionButton::DefaultButton)) {
        return ButtonVisual::Filled;
    }
    return ButtonVisual::Tonal;
}

QColor primaryColor(const QPalette &palette, QPalette::ColorGroup group)
{
    const QColor link = palette.color(group, QPalette::Link);
    return link.isValid() ? link : palette.color(group, QPalette::Highlight);
}

QColor tonalContainerColor(const QPalette &palette, QPalette::ColorGroup group)
{
    const QColor alternate = palette.color(group, QPalette::AlternateBase);
    return alternate.isValid() ? alternate : palette.color(group, QPalette::Button);
}

QPalette::ColorGroup colorGroup(const QStyleOption *option)
{
    if (!option->state.testFlag(QStyle::State_Enabled)) {
        return QPalette::Disabled;
    }
    return option->state.testFlag(QStyle::State_Active) ? QPalette::Active : QPalette::Inactive;
}

QStyle *createPlatformBaseStyle()
{
    const QStringList keys = QStyleFactory::keys();
    const auto createMatching = [&keys](const QString &wanted) -> QStyle * {
        for (const QString &key : keys) {
            if (key.compare(wanted, Qt::CaseInsensitive) == 0) {
                return QStyleFactory::create(key);
            }
        }
        return nullptr;
    };

    // Breeze is the KDE platform style and preserves native metrics, icons,
    // mnemonics, and application-specific control behaviour that Meo does not
    // override. Do not permanently reduce every KDE application to Fusion.
    if (QStyle *breeze = createMatching(QStringLiteral("Breeze"))) {
        return breeze;
    }

    if (QApplication::instance() && QApplication::style()) {
        const QString currentKey = QApplication::style()->objectName();
        if (currentKey.compare(QStringLiteral("Meo"), Qt::CaseInsensitive) != 0) {
            if (QStyle *platform = createMatching(currentKey)) {
                return platform;
            }
        }
    }

    // A non-KDE host may not ship Breeze. Fusion remains only the portable
    // last-resort base, never the fixed KDE base.
    return QStyleFactory::create(QStringLiteral("Fusion"));
}

QRectF centeredTrack(const QRect &source, Qt::Orientation orientation, qreal thickness)
{
    QRectF track(source);
    if (orientation == Qt::Horizontal) {
        track.setTop(source.center().y() - thickness / 2.0);
        track.setHeight(thickness);
    } else {
        track.setLeft(source.center().x() - thickness / 2.0);
        track.setWidth(thickness);
    }
    return track;
}

QRectF sliderActiveTrack(const QRectF &track, const QPointF &handleCenter,
                         Qt::Orientation orientation, bool upsideDown)
{
    QRectF active = track;
    if (orientation == Qt::Horizontal) {
        if (upsideDown) {
            active.setLeft(qBound(track.left(), handleCenter.x(), track.right()));
        } else {
            active.setRight(qBound(track.left(), handleCenter.x(), track.right()));
        }
    } else if (upsideDown) {
        active.setTop(qBound(track.top(), handleCenter.y(), track.bottom()));
    } else {
        active.setBottom(qBound(track.top(), handleCenter.y(), track.bottom()));
    }
    return active;
}

void drawItemViewSurface(const QStyleOption *option, QPainter *painter)
{
    const bool selected = option->state.testFlag(QStyle::State_Selected);
    const bool hover = option->state.testFlag(QStyle::State_MouseOver);
    const bool pressed = option->state.testFlag(QStyle::State_Sunken);
    const bool focused = option->state.testFlag(QStyle::State_HasFocus);
    const bool enabled = option->state.testFlag(QStyle::State_Enabled);
    if (!selected && !hover && !pressed && !focused) {
        return;
    }

    const QPalette::ColorGroup group = !enabled ? QPalette::Disabled
        : option->state.testFlag(QStyle::State_Active) ? QPalette::Active : QPalette::Inactive;
    const QColor surface = tonalContainerColor(option->palette, group);
    const QColor accent = primaryColor(option->palette, group);
    const qreal selectionOpacity = selected ? 0.18 : 0.0;
    const qreal stateOpacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                       : focused ? Meo::DesignTokens::stateOpacityFocus()
                                                 : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0;
    const QColor fill = enabled
        ? MeoStyleHelper::blend(surface, accent, qMin<qreal>(0.30, selectionOpacity + stateOpacity))
        : option->palette.color(QPalette::Disabled, QPalette::AlternateBase);
    const QRectF itemRect = option->rect.adjusted(1.0, 1.0, -1.0, -1.0);
    MeoStyleHelper::drawRoundedSurface(painter, itemRect, Meo::DesignTokens::shapeSmall(), fill);
    if (focused) {
        MeoStyleHelper::drawFocusRing(painter, itemRect, Meo::DesignTokens::shapeSmall(), accent);
    }
}

} // namespace

MeoStyle::MeoStyle()
    : QProxyStyle(createPlatformBaseStyle())
    , m_motion(new MeoStyleMotion(this))
{
    setObjectName(QStringLiteral("Meo"));
}

void MeoStyle::polish(QWidget *widget)
{
    QProxyStyle::polish(widget);
    if (qobject_cast<QAbstractButton *>(widget) || qobject_cast<QLineEdit *>(widget)
        || qobject_cast<QComboBox *>(widget) || qobject_cast<QAbstractSlider *>(widget)
        || qobject_cast<QProgressBar *>(widget)) {
        m_motion->watch(widget);
    }
}

void MeoStyle::unpolish(QWidget *widget)
{
    m_motion->unwatch(widget);
    QProxyStyle::unpolish(widget);
}

QPalette MeoStyle::standardPalette() const
{
    // Keep the palette supplied by KDE's platform theme. Dynamic accent and
    // light/dark changes remain application palette changes; Meo only consumes
    // semantic roles while painting and never substitutes a static theme.
    if (QApplication::instance()) {
        return QApplication::palette();
    }
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
    case PM_ButtonShiftHorizontal:
    case PM_ButtonShiftVertical:
    case PM_ButtonDefaultIndicator:
        return 0;
    case PM_LayoutLeftMargin:
    case PM_LayoutTopMargin:
    case PM_LayoutRightMargin:
    case PM_LayoutBottomMargin:
        return qRound(Meo::DesignTokens::space16());
    case PM_LayoutHorizontalSpacing:
    case PM_LayoutVerticalSpacing:
    case PM_CheckBoxLabelSpacing:
    case PM_RadioButtonLabelSpacing:
    case PM_ToolBarItemSpacing:
        return qRound(Meo::DesignTokens::space8());
    case PM_ToolBarItemMargin:
    case PM_ToolBarFrameWidth:
        return 0;
    case PM_ToolBarIconSize:
    case PM_SmallIconSize:
    case PM_ButtonIconSize:
        return qRound(Meo::DesignTokens::iconSizeM());
    case PM_MenuButtonIndicator:
    case PM_ScrollBarSliderMin:
        return qRound(Meo::DesignTokens::space24());
    case PM_TabBarTabHSpace:
        return qRound(Meo::DesignTokens::space32());
    case PM_TabBarTabVSpace:
        return qRound(Meo::DesignTokens::space16());
    case PM_HeaderMargin:
        return qRound(Meo::DesignTokens::space12());
    case PM_MenuHMargin:
    case PM_MenuVMargin:
        return qRound(Meo::DesignTokens::space4());
    case PM_MenuPanelWidth:
        // The rounded PE_PanelMenu surface owns the outline. A second native
        // frame would reintroduce the square Breeze border around Meo menus.
        return 0;
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
    const int height = qRound(Meo::DesignTokens::controlHeight());
    const int padding = qRound(Meo::DesignTokens::space16());
    const int gap = qRound(Meo::DesignTokens::space8());
    switch (type) {
    case CT_PushButton: {
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        return QSize(contentsSize.width() + 2 * padding
                         + (button && button->features.testFlag(QStyleOptionButton::HasMenu) ? 24 : 0),
                     qMax(height, contentsSize.height() + 2 * gap));
    }
    case CT_ToolButton: {
        const auto *tool = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        const int menuWidth = tool && tool->features.testFlag(QStyleOptionToolButton::MenuButtonPopup) ? 24 : 0;
        return QSize(qMax(height, contentsSize.width() + 2 * gap) + menuWidth,
                     qMax(height, contentsSize.height() + 2 * gap));
    }
    case CT_LineEdit:
        return QSize(contentsSize.width() + 2 * padding, qMax(height, contentsSize.height() + 2 * gap));
    case CT_ComboBox:
    case CT_SpinBox:
        return QSize(contentsSize.width() + 2 * padding + 24, qMax(height, contentsSize.height() + 2 * gap));
    case CT_CheckBox:
    case CT_RadioButton:
        return QSize(contentsSize.width() + 18 + gap, qMax(height, contentsSize.height() + gap));
    case CT_MenuItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) break;
        if (item->menuItemType == QStyleOptionMenuItem::Separator)
            return QSize(contentsSize.width(), item->text.isEmpty() ? gap : height);
        const QString label = item->text.section(QLatin1Char('\t'), 0, 0);
        const QString shortcut = item->text.section(QLatin1Char('\t'), 1);
        const int leading = qMax(24, item->maxIconWidth);
        const int shortcutWidth = qMax(item->reservedShortcutWidth, item->fontMetrics.horizontalAdvance(shortcut));
        return QSize(2 * padding + leading + gap + item->fontMetrics.horizontalAdvance(label)
                         + (item->menuHasCheckableItems ? 18 + gap : 0)
                         + (shortcutWidth ? shortcutWidth + 2 * gap : 0) + 24,
                     qMax(height + gap, item->fontMetrics.height() + 2 * gap));
    }
    case CT_MenuBarItem:
        return QSize(contentsSize.width() + 2 * padding, qMax(height, contentsSize.height() + 2 * gap));
    case CT_TabBarTab:
        return QSize(contentsSize.width() + 2 * padding, qMax(height, contentsSize.height() + 2 * gap));
    case CT_ItemViewItem:
        return QSize(contentsSize.width() + 2 * gap, qMax(height, contentsSize.height() + gap));
    default: break;
    }
    return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
}

int MeoStyle::styleHint(StyleHint hint, const QStyleOption *option,
                        const QWidget *widget, QStyleHintReturn *returnData) const
{
    switch (hint) {
    case SH_UnderlineShortcut: return QProxyStyle::styleHint(hint, option, widget, returnData);
    case SH_ComboBox_Popup: return 0;
    case SH_ItemView_ShowDecorationSelected: return 1;
    case SH_Widget_Animate: return m_motion->animationsEnabled(widget) ? 1 : 0;
    default: return QProxyStyle::styleHint(hint, option, widget, returnData);
    }
}

QRect MeoStyle::subElementRect(SubElement element, const QStyleOption *option, const QWidget *widget) const
{
    if (!option) return {};
    const QRect bounds = option->rect;
    const int padding = qRound(Meo::DesignTokens::space16());
    const int gap = qRound(Meo::DesignTokens::space8());
    const auto visual = [&](const QRect &rect) { return visualRect(option->direction, bounds, rect); };
    switch (element) {
    case SE_PushButtonContents: return bounds.adjusted(padding, 4, -padding, -4);
    case SE_LineEditContents: return bounds.adjusted(padding, 4, -padding, -4);
    case SE_CheckBoxIndicator:
    case SE_RadioButtonIndicator:
        return visual(QRect(bounds.left(), bounds.center().y() - 9, 18, 18));
    case SE_CheckBoxContents:
    case SE_RadioButtonContents:
        return visual(bounds.adjusted(18 + gap, 0, 0, 0));
    case SE_CheckBoxFocusRect:
    case SE_RadioButtonFocusRect: return bounds.adjusted(1, 1, -1, -1);
    case SE_ProgressBarGroove:
    case SE_ProgressBarContents:
    case SE_ProgressBarLabel: return bounds;
    case SE_ItemViewItemFocusRect: return bounds.adjusted(gap, 1, -gap, -1);
    case SE_TabBarTabText: return bounds.adjusted(padding, 4, -padding, -4);
    case SE_ItemViewItemCheckIndicator:
    case SE_ItemViewItemDecoration:
    case SE_ItemViewItemText: {
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (!item) break;
        QRect content = bounds.adjusted(gap, 4, -gap, -4);
        if (item->features.testFlag(QStyleOptionViewItem::HasCheckIndicator)) {
            const QRect check(content.left(), content.center().y() - 9, 18, 18);
            if (element == SE_ItemViewItemCheckIndicator) return visual(check);
            content.setLeft(content.left() + 18 + gap);
        } else if (element == SE_ItemViewItemCheckIndicator) return {};
        if (item->features.testFlag(QStyleOptionViewItem::HasDecoration)) {
            const QSize icon = item->decorationSize;
            QRect decoration;
            switch (item->decorationPosition) {
            case QStyleOptionViewItem::Top:
                decoration = QRect(content.center().x() - icon.width() / 2, content.top(), icon.width(), icon.height());
                content.setTop(decoration.bottom() + gap + 1); break;
            case QStyleOptionViewItem::Bottom:
                decoration = QRect(content.center().x() - icon.width() / 2, content.bottom() - icon.height() + 1, icon.width(), icon.height());
                content.setBottom(decoration.top() - gap - 1); break;
            case QStyleOptionViewItem::Right:
                decoration = QRect(content.right() - icon.width() + 1, content.center().y() - icon.height() / 2, icon.width(), icon.height());
                content.setRight(decoration.left() - gap - 1); break;
            default:
                decoration = QRect(content.left(), content.center().y() - icon.height() / 2, icon.width(), icon.height());
                content.setLeft(decoration.right() + gap + 1); break;
            }
            if (element == SE_ItemViewItemDecoration) return visual(decoration);
        } else if (element == SE_ItemViewItemDecoration) return {};
        return visual(content);
    }
    default: break;
    }
    return QProxyStyle::subElementRect(element, option, widget);
}

QRect MeoStyle::subControlRect(ComplexControl control, const QStyleOptionComplex *option,
                              SubControl subControl, const QWidget *widget) const
{
    if (!option) return {};
    const QRect bounds = option->rect;
    const auto visual = [&](const QRect &rect) { return visualRect(option->direction, bounds, rect); };
    if (control == CC_GroupBox) {
        const auto *box = qstyleoption_cast<const QStyleOptionGroupBox *>(option);
        if (!box) return {};
        const int gap = qRound(Meo::DesignTokens::space8());
        const int padding = qRound(Meo::DesignTokens::space16());
        const bool checkable = box->subControls.testFlag(SC_GroupBoxCheckBox);
        const int labelWidth = box->fontMetrics.horizontalAdvance(box->text) + (checkable ? 18 + gap : 0);
        const int titleHeight = qMax(18, box->fontMetrics.height());
        int x = bounds.left() + padding;
        if (box->textAlignment.testFlag(Qt::AlignHCenter)) x = bounds.center().x() - labelWidth / 2;
        else if (box->textAlignment.testFlag(Qt::AlignRight)) x = bounds.right() - padding - labelWidth + 1;
        const QRect title(x, bounds.top(), labelWidth, titleHeight);
        if (subControl == SC_GroupBoxCheckBox) return checkable ? visual(QRect(x, title.center().y() - 9, 18, 18)) : QRect();
        if (subControl == SC_GroupBoxLabel) return visual(title.adjusted(checkable ? 18 + gap : 0, 0, 0, 0));
        if (subControl == SC_GroupBoxFrame) return bounds.adjusted(0, titleHeight / 2, 0, 0);
        if (subControl == SC_GroupBoxContents) return bounds.adjusted(padding, titleHeight + gap, -padding, -padding);
    }
    if (control == CC_ComboBox || control == CC_SpinBox) {
        const QRect arrow(bounds.right() - 31, bounds.top() + 4, 24, qMax(0, bounds.height() - 8));
        if (control == CC_ComboBox && subControl == SC_ComboBoxArrow) return visual(arrow);
        if (control == CC_SpinBox) {
            if (subControl == SC_SpinBoxUp) return visual(QRect(arrow.x(), arrow.y(), arrow.width(), arrow.height() / 2));
            if (subControl == SC_SpinBoxDown) return visual(QRect(arrow.x(), arrow.y() + arrow.height() / 2, arrow.width(), arrow.height() - arrow.height() / 2));
        }
        if ((control == CC_ComboBox && subControl == SC_ComboBoxEditField)
            || (control == CC_SpinBox && subControl == SC_SpinBoxEditField))
            return visual(bounds.adjusted(16, 4, -40, -4));
        return bounds;
    }
    if (control == CC_ToolButton) {
        const auto *tool = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        const bool split = tool && tool->features.testFlag(QStyleOptionToolButton::MenuButtonPopup);
        if (subControl == SC_ToolButtonMenu)
            return split ? visual(QRect(bounds.right() - 23, bounds.top(), 24, bounds.height())) : QRect();
        if (subControl == SC_ToolButton) return split ? visual(bounds.adjusted(0, 0, -24, 0)) : bounds;
    }
    if (control == CC_Slider || control == CC_ScrollBar) {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) return {};
        const bool horizontal = slider->orientation == Qt::Horizontal;
        const int length = horizontal ? bounds.width() : bounds.height();
        if (control == CC_ScrollBar) {
            if (subControl == SC_ScrollBarAddLine || subControl == SC_ScrollBarSubLine) return {};
            if (subControl == SC_ScrollBarGroove) return bounds;
            const qint64 range = qint64(slider->maximum) - slider->minimum;
            const int thumb = range <= 0 ? length : qBound(qMin(length, 24),
                int(qint64(length) * qMax(0, slider->pageStep) / qMax<qint64>(1, range + qMax(0, slider->pageStep))), length);
            const int position = sliderPositionFromValue(slider->minimum, slider->maximum, slider->sliderPosition, qMax(0, length - thumb), slider->upsideDown);
            const auto axisRect = [&](int start, int span) {
                return horizontal ? QRect(bounds.left() + start, bounds.top(), span, bounds.height())
                                  : QRect(bounds.left(), bounds.top() + start, bounds.width(), span);
            };
            if (subControl == SC_ScrollBarSlider) return axisRect(position, thumb);
            if (subControl == SC_ScrollBarSubPage) return axisRect(0, position);
            if (subControl == SC_ScrollBarAddPage) return axisRect(position + thumb, length - position - thumb);
        } else {
            const int handle = 18;
            const int position = sliderPositionFromValue(slider->minimum, slider->maximum, slider->sliderPosition, qMax(0, length - handle), slider->upsideDown);
            if (subControl == SC_SliderHandle)
                return horizontal ? QRect(bounds.left() + position, bounds.center().y() - handle / 2, handle, handle)
                                  : QRect(bounds.center().x() - handle / 2, bounds.top() + position, handle, handle);
            if (subControl == SC_SliderGroove)
                return horizontal ? QRect(bounds.left() + handle / 2, bounds.center().y() - 2, qMax(0, length - handle), 4)
                                  : QRect(bounds.center().x() - 2, bounds.top() + handle / 2, 4, qMax(0, length - handle));
        }
    }
    return QProxyStyle::subControlRect(control, option, subControl, widget);
}

void MeoStyle::drawPrimitive(PrimitiveElement element, const QStyleOption *option,
                             QPainter *painter, const QWidget *widget) const
{
    const bool enabled = option->state.testFlag(State_Enabled);
    const bool hover = option->state.testFlag(State_MouseOver);
    const bool pressed = option->state.testFlag(State_Sunken);
    const bool focus = option->state.testFlag(State_HasFocus);
    const QPalette::ColorGroup group = colorGroup(option);

    if (element == PE_FrameFocusRect) {
        MeoStyleHelper::drawFocusRing(painter, option->rect, controlRadius(), primaryColor(option->palette, group));
        return;
    }
    if (element == PE_PanelTipLabel) {
        MeoStyleHelper::drawRoundedSurface(painter, option->rect.adjusted(1, 1, -1, -1),
            Meo::DesignTokens::shapeSmall(), option->palette.color(group, QPalette::ToolTipBase));
        return;
    }
    if (element == PE_FrameTabWidget) return;
    if (element == PE_IndicatorBranch) {
        if (option->state.testFlag(State_Children)) {
            const QRect arrow(option->rect.center().x() - 7, option->rect.center().y() - 7, 14, 14);
            MeoStyleHelper::drawChevron(painter, arrow, option->palette.color(group, QPalette::Text),
                option->state.testFlag(State_Open) ? Qt::DownArrow
                    : option->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow);
        }
        return;
    }
    if (element == PE_PanelItemViewRow) {
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (item && item->features.testFlag(QStyleOptionViewItem::Alternate))
            painter->fillRect(option->rect, option->palette.color(group, QPalette::AlternateBase));
        return;
    }
    if (element == PE_IndicatorToolBarSeparator) {
        const QRect rect = option->rect;
        const QRect line = option->state.testFlag(State_Horizontal)
            ? QRect(rect.center().x(), rect.top() + 8, 1, qMax(0, rect.height() - 16))
            : QRect(rect.left() + 8, rect.center().y(), qMax(0, rect.width() - 16), 1);
        painter->fillRect(line, option->palette.color(group, QPalette::Midlight)); return;
    }

    if (element == PE_PanelMenu) {
        QColor outline = option->palette.color(group, QPalette::Mid);
        outline.setAlphaF(0.22);
        MeoStyleHelper::drawRoundedSurface(
            painter,
            option->rect.adjusted(0.5, 0.5, -0.5, -0.5),
            Meo::DesignTokens::shapeLargeIncreased(),
            option->palette.color(group, QPalette::Window),
            outline);
        return;
    }

    if (element == PE_FrameMenu) {
        // PE_PanelMenu already paints the semantic surface and outline.
        return;
    }

    if (element == PE_PanelButtonCommand || element == PE_PanelButtonTool) {
        const auto *button = element == PE_PanelButtonCommand
            ? qstyleoption_cast<const QStyleOptionButton *>(option) : nullptr;
        const auto *toolButton = element == PE_PanelButtonTool
            ? qstyleoption_cast<const QStyleOptionToolButton *>(option) : nullptr;
        const bool checked = option->state.testFlag(State_On);
        const ButtonVisual visual = button ? buttonVisual(button, widget)
            : (checked ? ButtonVisual::Tonal : ButtonVisual::Text);
        const bool textButton = visual == ButtonVisual::Text
            || (toolButton && option->state.testFlag(State_AutoRaise) && !checked);
        const QColor surface = visual == ButtonVisual::Filled
            ? primaryColor(option->palette, group)
            : tonalContainerColor(option->palette, group);
        const QColor content = visual == ButtonVisual::Filled
            ? option->palette.color(group, QPalette::HighlightedText)
            : visual == ButtonVisual::Text ? primaryColor(option->palette, group)
                                            : option->palette.color(group, QPalette::Text);
        const qreal opacity = m_motion->opacity(widget,
            pressed ? Meo::DesignTokens::stateOpacityPressed()
                    : focus ? Meo::DesignTokens::stateOpacityFocus()
                            : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0);
        QColor fill = enabled
            ? MeoStyleHelper::blend(surface, content, opacity)
            : option->palette.color(QPalette::Disabled,
                                    visual == ButtonVisual::Filled ? QPalette::Highlight : QPalette::AlternateBase);
        if (textButton && enabled && opacity <= 0.0) {
            fill = Qt::transparent;
        }
        const QColor outline;
        const qreal progress = m_motion->pressProgress(widget, pressed);
        const qreal resting = buttonRadius(option, false);
        const qreal radius = resting + (buttonRadius(option, true) - resting) * progress;
        MeoStyleHelper::drawRoundedSurface(painter, option->rect, radius, fill, outline);
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, option->rect, radius,
                                           primaryColor(option->palette, group));
        }
        return;
    }

    // The default action already has a filled accent container and focus
    // outline.  Suppress platform styles' additional square default frame.
    if (element == PE_FrameDefaultButton) {
        return;
    }

    if (element == PE_FrameLineEdit || element == PE_PanelLineEdit) {
        const bool searchField = widget && widget->property("meo.role").toString() == QLatin1String("search");
        const qreal radius = searchField ? option->rect.height() / 2.0 : controlRadius();
        const QColor outline;
        MeoStyleHelper::drawRoundedSurface(painter, option->rect.adjusted(0.5, 0.5, -0.5, -0.5),
                                            radius, tonalContainerColor(option->palette, group), outline);
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, option->rect, radius,
                                           primaryColor(option->palette, group));
        }
        return;
    }

    if (element == PE_IndicatorArrowDown || element == PE_IndicatorArrowUp
        || element == PE_IndicatorArrowLeft || element == PE_IndicatorArrowRight) {
        Qt::ArrowType direction = Qt::DownArrow;
        if (element == PE_IndicatorArrowUp) direction = Qt::UpArrow;
        if (element == PE_IndicatorArrowLeft) direction = Qt::LeftArrow;
        if (element == PE_IndicatorArrowRight) direction = Qt::RightArrow;
        MeoStyleHelper::drawChevron(painter, option->rect,
                                     option->palette.color(group, QPalette::ButtonText), direction);
        return;
    }

    if (element == PE_IndicatorCheckBox || element == PE_IndicatorRadioButton
        || element == PE_IndicatorItemViewItemCheck) {
        const QRectF indicator = option->rect.adjusted(1.0, 1.0, -1.0, -1.0);
        const bool checked = option->state.testFlag(State_On);
        const bool partial = option->state.testFlag(State_NoChange);
        const qreal checkedProgress = m_motion->checkProgress(widget, checked);
        const QColor primary = primaryColor(option->palette, group);
        const QColor outline = option->palette.color(group, QPalette::Mid);
        const QColor indicatorSurface = enabled
            ? MeoStyleHelper::stateLayer(option->palette, group,
                                          checked || partial ? QPalette::Link : QPalette::AlternateBase,
                                          checked || partial ? QPalette::HighlightedText : QPalette::Text,
                                          hover, pressed, focus)
            : option->palette.color(QPalette::Disabled,
                                    checked || partial ? QPalette::Highlight : QPalette::AlternateBase);
        if (element == PE_IndicatorRadioButton) {
            MeoStyleHelper::drawRoundedSurface(painter, indicator, indicator.width() / 2.0,
                                                indicatorSurface, outline);
            if (checkedProgress > 0.0) {
                const qreal inset = indicator.width() / 2.0 - (indicator.width() / 2.0 - 5.0) * checkedProgress;
                MeoStyleHelper::drawRoundedSurface(painter, indicator.adjusted(inset, inset, -inset, -inset),
                                                    indicator.width() / 2.0,
                                                    option->palette.color(group, QPalette::HighlightedText));
            }
        } else {
            MeoStyleHelper::drawRoundedSurface(painter, indicator, Meo::DesignTokens::shapeExtraSmall(),
                                                indicatorSurface,
                                                checked || partial ? primary : outline);
            if (checkedProgress > 0.0) {
                QColor mark = option->palette.color(group, QPalette::HighlightedText);
                mark.setAlphaF(mark.alphaF() * checkedProgress);
                MeoStyleHelper::drawCheckMark(painter, indicator, mark);
            } else if (partial) {
                painter->fillRect(indicator.adjusted(4.0, indicator.height() / 2.0 - 1.0,
                                                     -4.0, -indicator.height() / 2.0 + 1.0),
                                  option->palette.color(group, QPalette::HighlightedText));
            }
        }
        if (enabled && (hover || pressed)) {
            QColor interactionRing = primary;
            interactionRing.setAlphaF(pressed ? 0.60 : 0.35);
            MeoStyleHelper::drawFocusRing(painter, option->rect.adjusted(-1.0, -1.0, 1.0, 1.0),
                                           controlRadius(), interactionRing);
        }
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, option->rect.adjusted(-2.0, -2.0, 2.0, 2.0),
                                           controlRadius(), primary);
        }
        return;
    }

    if (element == PE_PanelItemViewItem) {
        drawItemViewSurface(option, painter);
        return;
    }

    QProxyStyle::drawPrimitive(element, option, painter, widget);
}

void MeoStyle::drawControl(ControlElement element, const QStyleOption *option,
                           QPainter *painter, const QWidget *widget) const
{
    const bool enabled = option->state.testFlag(State_Enabled);
    const bool hover = option->state.testFlag(State_MouseOver);
    const bool pressed = option->state.testFlag(State_Sunken);
    const bool focus = option->state.testFlag(State_HasFocus);
    const QPalette::ColorGroup group = colorGroup(option);

    const auto drawLabel = [&](QRect rect, const QString &text, const QIcon &icon, QSize iconSize,
                               const QColor &foreground, Qt::Alignment alignment = Qt::AlignCenter) {
        painter->save();
        painter->setPen(foreground);
        const int gap = qRound(Meo::DesignTokens::space8());
        const int flags = Qt::TextSingleLine | (styleHint(SH_UnderlineShortcut, option, widget)
            ? Qt::TextShowMnemonic : Qt::TextHideMnemonic);
        const int textWidth = option->fontMetrics.size(flags, text).width();
        if (!icon.isNull()) {
            iconSize = iconSize.boundedTo(rect.size());
            const int combined = iconSize.width() + (text.isEmpty() ? 0 : gap + textWidth);
            QRect logical(rect.left() + (alignment.testFlag(Qt::AlignHCenter) ? qMax(0, (rect.width() - combined) / 2) : 0),
                          rect.center().y() - iconSize.height() / 2, iconSize.width(), iconSize.height());
            icon.paint(painter, visualRect(option->direction, rect, logical), Qt::AlignCenter,
                       enabled ? (hover ? QIcon::Active : QIcon::Normal) : QIcon::Disabled,
                       option->state.testFlag(State_On) ? QIcon::On : QIcon::Off);
            logical.setLeft(logical.right() + gap + 1);
            logical.setWidth(qMax(0, rect.right() - logical.left() + 1));
            logical.setTop(rect.top()); logical.setHeight(rect.height());
            rect = visualRect(option->direction, rect, logical);
            alignment = visualAlignment(option->direction, Qt::AlignLeft | Qt::AlignVCenter);
        }
        painter->drawText(rect, alignment | flags, text);
        painter->restore();
    };

    if (element == CE_PushButtonLabel) {
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option)) {
            const ButtonVisual visual = buttonVisual(button, widget);
            const QColor foreground = visual == ButtonVisual::Filled
                ? option->palette.color(group, QPalette::HighlightedText)
                : visual == ButtonVisual::Text ? primaryColor(option->palette, group)
                                              : option->palette.color(group, QPalette::Text);
            QRect content = subElementRect(SE_PushButtonContents, option, widget);
            if (button->features.testFlag(QStyleOptionButton::HasMenu)) {
                const QRect logical(content.right() - 17, content.center().y() - 9, 18, 18);
                MeoStyleHelper::drawChevron(painter, visualRect(option->direction, content, logical), foreground, Qt::DownArrow);
                content = visualRect(option->direction, content, content.adjusted(0, 0, -24, 0));
            }
            drawLabel(content, button->text, button->icon, button->iconSize, foreground);
            return;
        }
    }
    if (element == CE_CheckBox || element == CE_RadioButton) {
        const bool radio = element == CE_RadioButton;
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        if (!button) { QProxyStyle::drawControl(element, option, painter, widget); return; }
        QStyleOptionButton indicator(*button);
        indicator.rect = subElementRect(radio ? SE_RadioButtonIndicator : SE_CheckBoxIndicator, option, widget);
        drawPrimitive(radio ? PE_IndicatorRadioButton : PE_IndicatorCheckBox, &indicator, painter, widget);
        drawControl(radio ? CE_RadioButtonLabel : CE_CheckBoxLabel, option, painter, widget);
        return;
    }
    if (element == CE_CheckBoxLabel || element == CE_RadioButtonLabel) {
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option)) {
            drawLabel(subElementRect(element == CE_RadioButtonLabel ? SE_RadioButtonContents : SE_CheckBoxContents, option, widget),
                      button->text, button->icon, button->iconSize, option->palette.color(group, QPalette::WindowText),
                      visualAlignment(option->direction, Qt::AlignLeft | Qt::AlignVCenter));
            return;
        }
    }
    if (element == CE_ToolButtonLabel) {
        if (const auto *tool = qstyleoption_cast<const QStyleOptionToolButton *>(option)) {
            QRect content = subControlRect(CC_ToolButton, tool, SC_ToolButton, widget);
            const int inset = qMin(8, qMax(0, (content.width() - 16) / 2));
            content.adjust(inset, 4, -inset, -4);
            const QColor foreground = option->palette.color(group, QPalette::ButtonText);
            const QString text = tool->toolButtonStyle == Qt::ToolButtonIconOnly ? QString() : tool->text;
            const QIcon icon = tool->toolButtonStyle == Qt::ToolButtonTextOnly ? QIcon() : tool->icon;
            if (tool->toolButtonStyle == Qt::ToolButtonTextUnderIcon && !icon.isNull()) {
                QRect iconRect(content.left(), content.top(), content.width(), tool->iconSize.height());
                icon.paint(painter, iconRect, Qt::AlignCenter, enabled ? QIcon::Normal : QIcon::Disabled,
                           option->state.testFlag(State_On) ? QIcon::On : QIcon::Off);
                content.setTop(iconRect.bottom() + 5);
                drawLabel(content, text, {}, {}, foreground);
            } else if (tool->features.testFlag(QStyleOptionToolButton::Arrow)) {
                MeoStyleHelper::drawChevron(painter, content, foreground, tool->arrowType);
            } else drawLabel(content, text, icon, tool->iconSize, foreground);
            return;
        }
    }
    if (element == CE_ComboBoxLabel) {
        if (const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option)) {
            // Editable combobox text belongs to its child line edit.
            if (!combo->editable) drawLabel(subControlRect(CC_ComboBox, combo, SC_ComboBoxEditField, widget),
                combo->currentText, combo->currentIcon, combo->iconSize,
                option->palette.color(group, QPalette::Text), visualAlignment(option->direction, Qt::AlignLeft | Qt::AlignVCenter));
            return;
        }
    }

    if (element == CE_MenuItem) {
        const auto *menuItem = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!menuItem) {
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }

        if (menuItem->menuItemType == QStyleOptionMenuItem::Separator) {
            // Plain separators are intentionally visual gaps, matching the
            // segmented MeoContextMenu contract. Preserve section labels that
            // applications intentionally supplied rather than erasing content.
            if (!menuItem->text.isEmpty()) {
                painter->save();
                painter->setFont(menuItem->font);
                drawLabel(option->rect.adjusted(16, 0, -16, 0), menuItem->text, {}, {},
                          option->palette.color(group, QPalette::WindowText),
                          visualAlignment(option->direction, Qt::AlignLeft | Qt::AlignVCenter));
                painter->restore();
            }
            return;
        }

        const QColor accent = primaryColor(option->palette, group);
        const QColor restingSurface = enabled
            ? tonalContainerColor(option->palette, group)
            : option->palette.color(QPalette::Disabled, QPalette::AlternateBase);
        const qreal opacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                      : focus ? Meo::DesignTokens::stateOpacityFocus()
                                              : (hover || option->state.testFlag(State_Selected))
                                                    ? Meo::DesignTokens::stateOpacityHover()
                                                    : 0.0;
        const QColor fill = enabled
            ? MeoStyleHelper::blend(restingSurface, accent, opacity)
            : restingSurface;
        const QRectF background = option->rect.adjusted(
            Meo::DesignTokens::space2(),
            Meo::DesignTokens::space2(),
            -Meo::DesignTokens::space2(),
            -Meo::DesignTokens::space2());
        MeoStyleHelper::drawRoundedSurface(
            painter, background, Meo::DesignTokens::shapeLarge(), fill);

        if (focus) {
            MeoStyleHelper::drawFocusRing(
                painter, background, Meo::DesignTokens::shapeLarge(), accent);
        }

        painter->save();
        QFont font = menuItem->font;
        if (menuItem->menuItemType == QStyleOptionMenuItem::DefaultItem) font.setBold(true);
        painter->setFont(font);
        painter->setPen(option->palette.color(group, QPalette::Text));
        QRect logical = option->rect.adjusted(16, 4, -16, -4);
        const int iconWidth = qMax(24, menuItem->maxIconWidth);
        if (menuItem->menuHasCheckableItems) {
            QRect check(logical.left(), logical.center().y() - 9, 18, 18);
            if (menuItem->checked) {
                const QRect visible = visualRect(option->direction, option->rect, check);
                if (menuItem->checkType == QStyleOptionMenuItem::Exclusive) {
                    MeoStyleHelper::drawRoundedSurface(painter, visible.adjusted(5, 5, -5, -5), 4, accent);
                } else MeoStyleHelper::drawCheckMark(painter, visible, accent);
            }
            logical.setLeft(logical.left() + 26);
        }
        const QRect iconRect(logical.left(), logical.center().y() - 12, iconWidth, 24);
        if (!menuItem->icon.isNull()) menuItem->icon.paint(painter, visualRect(option->direction, option->rect, iconRect),
            Qt::AlignCenter, enabled ? QIcon::Normal : QIcon::Disabled, menuItem->checked ? QIcon::On : QIcon::Off);
        logical.setLeft(iconRect.right() + 9);
        const QRect arrow(logical.right() - 17, logical.center().y() - 9, 18, 18);
        if (menuItem->menuItemType == QStyleOptionMenuItem::SubMenu)
            MeoStyleHelper::drawChevron(painter, visualRect(option->direction, option->rect, arrow),
                option->palette.color(group, QPalette::Text), option->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow);
        logical.setRight(arrow.left() - 9);
        const QString shortcut = menuItem->text.section(QLatin1Char('\t'), 1);
        const int shortcutWidth = qMax(menuItem->reservedShortcutWidth, menuItem->fontMetrics.horizontalAdvance(shortcut));
        if (shortcutWidth) {
            const QRect shortcutRect(logical.right() - shortcutWidth + 1, logical.top(), shortcutWidth, logical.height());
            painter->drawText(visualRect(option->direction, option->rect, shortcutRect),
                visualAlignment(option->direction, Qt::AlignRight | Qt::AlignVCenter) | Qt::TextSingleLine, shortcut);
            logical.setRight(shortcutRect.left() - 17);
        }
        drawLabel(visualRect(option->direction, option->rect, logical), menuItem->text.section(QLatin1Char('\t'), 0, 0),
                  {}, {}, option->palette.color(group, QPalette::Text), visualAlignment(option->direction, Qt::AlignLeft | Qt::AlignVCenter));
        painter->restore();
        return;
    }

    if (element == CE_MenuBarItem) {
        const auto *menuItem = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!menuItem) {
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }

        const bool selected = option->state.testFlag(State_Selected);
        if (selected || hover || pressed || focus) {
            const QColor surface = tonalContainerColor(option->palette, group);
            const QColor accent = primaryColor(option->palette, group);
            const qreal opacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                          : focus ? Meo::DesignTokens::stateOpacityFocus()
                                                  : Meo::DesignTokens::stateOpacityHover();
            const QRectF background = option->rect.adjusted(
                Meo::DesignTokens::space2(),
                Meo::DesignTokens::space2(),
                -Meo::DesignTokens::space2(),
                -Meo::DesignTokens::space2());
            MeoStyleHelper::drawRoundedSurface(
                painter, background, Meo::DesignTokens::shapeSmall(),
                MeoStyleHelper::blend(surface, accent, opacity));
            if (focus) {
                MeoStyleHelper::drawFocusRing(
                    painter, background, Meo::DesignTokens::shapeSmall(), accent);
            }
        }

        drawLabel(option->rect.adjusted(16, 4, -16, -4), menuItem->text, menuItem->icon, QSize(24, 24),
                  option->palette.color(group, QPalette::WindowText));
        return;
    }

    if (element == CE_TabBarTab) {
        drawControl(CE_TabBarTabShape, option, painter, widget);
        drawControl(CE_TabBarTabLabel, option, painter, widget);
        return;
    }

    if (element == CE_TabBarTabLabel) {
        if (const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option)) {
            painter->save();
            QStyleOptionTab label(*tab);
            const bool vertical = tab->shape == QTabBar::RoundedWest || tab->shape == QTabBar::TriangularWest
                || tab->shape == QTabBar::RoundedEast || tab->shape == QTabBar::TriangularEast;
            if (vertical) {
                painter->translate(tab->rect.center());
                painter->rotate(tab->shape == QTabBar::RoundedWest || tab->shape == QTabBar::TriangularWest ? -90 : 90);
                label.rect = QRect(-tab->rect.height() / 2, -tab->rect.width() / 2, tab->rect.height(), tab->rect.width());
            }
            QRect content = label.rect.adjusted(16, 4, -16, -4);
            content.setLeft(content.left() + tab->leftButtonSize.width());
            content.setRight(content.right() - tab->rightButtonSize.width());
            drawLabel(content, tab->text, tab->icon, tab->iconSize, option->palette.color(group, QPalette::WindowText));
            painter->restore(); return;
        }
    }

    if (element == CE_TabBarTabShape) {
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (!tab) {
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }

        const bool selected = option->state.testFlag(State_Selected);
        const QPalette::ColorRole surfaceRole = selected ? QPalette::AlternateBase : QPalette::Window;
        const QPalette::ColorRole contentRole = selected ? QPalette::Text : QPalette::WindowText;
        const QColor fill = enabled
            ? MeoStyleHelper::stateLayer(option->palette, group, surfaceRole, contentRole, hover, pressed, focus)
            : option->palette.color(QPalette::Disabled, surfaceRole);
        const QRectF tabRect = option->rect.adjusted(1.0, 1.0, -1.0, -1.0);
        MeoStyleHelper::drawRoundedSurface(painter, tabRect, Meo::DesignTokens::shapeSmall(), fill);

        if (selected) {
            QRectF indicator = tabRect;
            const qreal thickness = Meo::DesignTokens::space2();
            switch (tab->shape) {
            case QTabBar::RoundedSouth:
            case QTabBar::TriangularSouth:
                indicator.setHeight(thickness);
                break;
            case QTabBar::RoundedWest:
            case QTabBar::TriangularWest:
                indicator.setWidth(thickness);
                break;
            case QTabBar::RoundedEast:
            case QTabBar::TriangularEast:
                indicator.setLeft(indicator.right() - thickness);
                break;
            case QTabBar::RoundedNorth:
            case QTabBar::TriangularNorth:
            default:
                indicator.setTop(indicator.bottom() - thickness);
                break;
            }
            MeoStyleHelper::drawRoundedSurface(painter, indicator, thickness / 2.0,
                                                primaryColor(option->palette, group));
        }
        if (focus) {
            MeoStyleHelper::drawFocusRing(painter, tabRect, Meo::DesignTokens::shapeSmall(),
                                           primaryColor(option->palette, group));
        }
        return;
    }

    if (element == CE_ItemViewItem) {
        const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option);
        if (!item) {
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }

        if (item->backgroundBrush.style() != Qt::NoBrush) painter->fillRect(item->rect, item->backgroundBrush);
        drawItemViewSurface(item, painter);
        painter->save(); painter->setFont(item->font);
        if (item->features.testFlag(QStyleOptionViewItem::HasCheckIndicator)) {
            QStyleOption check(*item);
            check.rect = subElementRect(SE_ItemViewItemCheckIndicator, item, widget);
            check.state &= ~(State_On | State_Off | State_NoChange);
            check.state |= item->checkState == Qt::Checked ? State_On
                : item->checkState == Qt::PartiallyChecked ? State_NoChange : State_Off;
            drawPrimitive(PE_IndicatorItemViewItemCheck, &check, painter, widget);
        }
        if (item->features.testFlag(QStyleOptionViewItem::HasDecoration))
            item->icon.paint(painter, subElementRect(SE_ItemViewItemDecoration, item, widget), item->decorationAlignment,
                enabled ? QIcon::Normal : QIcon::Disabled, option->state.testFlag(State_Open) ? QIcon::On : QIcon::Off);
        const QRect textRect = subElementRect(SE_ItemViewItemText, item, widget);
        painter->setPen(item->palette.color(group, QPalette::Text));
        painter->setClipRect(textRect);
        if (item->features.testFlag(QStyleOptionViewItem::WrapText)) {
            QTextLayout layout(item->text, item->font);
            QTextOption textOption;
            textOption.setWrapMode(QTextOption::WrapAtWordBoundaryOrAnywhere);
            textOption.setTextDirection(item->direction);
            textOption.setAlignment(visualAlignment(item->direction, item->displayAlignment));
            layout.setTextOption(textOption);
            qreal y = 0; layout.beginLayout();
            while (true) {
                QTextLine line = layout.createLine(); if (!line.isValid()) break;
                line.setLineWidth(qMax(0, textRect.width())); line.setPosition(QPointF(0, y)); y += line.height();
            }
            layout.endLayout();
            const qreal offset = item->displayAlignment.testFlag(Qt::AlignVCenter) ? qMax<qreal>(0, (textRect.height() - y) / 2)
                : item->displayAlignment.testFlag(Qt::AlignBottom) ? qMax<qreal>(0, textRect.height() - y) : 0;
            layout.draw(painter, QPointF(textRect.left(), textRect.top() + offset));
        } else {
            painter->drawText(textRect, item->displayAlignment | Qt::TextSingleLine,
                item->fontMetrics.elidedText(item->text, item->textElideMode, qMax(0, textRect.width())));
        }
        painter->restore();
        return;
    }

    if (element == CE_Header) {
        drawControl(CE_HeaderSection, option, painter, widget);
        drawControl(CE_HeaderLabel, option, painter, widget); return;
    }
    if (element == CE_ToolBar) {
        painter->fillRect(option->rect, option->palette.color(group, QPalette::Window)); return;
    }

    if (element == CE_HeaderSection) {
        MeoStyleHelper::drawRoundedSurface(painter, option->rect.adjusted(1, 1, -1, -1), 4,
            MeoStyleHelper::stateLayer(option->palette, group, QPalette::Window, QPalette::WindowText, hover, pressed, focus));
        return;
    }
    if (element == CE_HeaderLabel) {
        if (const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option)) {
            QRect content = option->rect.adjusted(12, 4, -12, -4);
            if (header->sortIndicator != QStyleOptionHeader::None) {
                const QRect arrow(content.right() - 17, content.center().y() - 9, 18, 18);
                MeoStyleHelper::drawChevron(painter, visualRect(option->direction, content, arrow),
                    option->palette.color(group, QPalette::WindowText), header->sortIndicator == QStyleOptionHeader::SortDown ? Qt::DownArrow : Qt::UpArrow);
                content = visualRect(option->direction, content, content.adjusted(0, 0, -24, 0));
            }
            drawLabel(content, header->text, header->icon, QSize(24, 24),
                      option->palette.color(group, QPalette::WindowText), header->textAlignment | Qt::AlignVCenter);
            return;
        }
    }

    if (element == CE_ProgressBarGroove) {
        MeoStyleHelper::drawRoundedSurface(painter, option->rect, option->rect.height() / 2.0,
                                            option->palette.color(colorGroup(option), QPalette::Midlight));
        return;
    }
    if (element == CE_ProgressBarContents) {
        const auto *progress = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (progress) {
            const bool vertical = !option->state.testFlag(State_Horizontal);
            const bool reverse = progress->invertedAppearance
                != (!vertical && progress->direction == Qt::RightToLeft);
            QRectF fill = option->rect;
            const bool busy = progress->maximum == 0 && progress->minimum == 0;
            const qreal length = vertical ? fill.height() : fill.width();
            qreal start = 0, span = 0;
            if (busy) {
                span = length * 0.3;
                start = (length + span) * m_motion->busyProgress(widget) - span;
            } else if (progress->maximum > progress->minimum && progress->progress >= progress->minimum) {
                const qreal ratio = qBound<qreal>(0.0,
                    (qreal(progress->progress) - progress->minimum) / (qreal(progress->maximum) - progress->minimum), 1.0);
                span = length * ratio;
            }
            if (reverse) start = length - start - span;
            painter->save(); painter->setClipRect(option->rect);
            if (vertical) { fill.setTop(fill.top() + (length - start - span)); fill.setHeight(span); }
            else { fill.setLeft(fill.left() + start); fill.setWidth(span); }
            MeoStyleHelper::drawRoundedSurface(painter, fill, qMin(fill.width(), fill.height()) / 2.0,
                primaryColor(option->palette, colorGroup(option)));
            painter->restore();
        }
        return;
    }
    QProxyStyle::drawControl(element, option, painter, widget);
}

void MeoStyle::drawComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                                  QPainter *painter, const QWidget *widget) const
{
    const bool enabled = option->state.testFlag(State_Enabled);
    const bool hover = option->state.testFlag(State_MouseOver);
    const bool pressed = option->state.testFlag(State_Sunken);
    const bool focus = option->state.testFlag(State_HasFocus);
    const QPalette::ColorGroup group = colorGroup(option);

    if (control == CC_SpinBox) {
        if (const auto *spin = qstyleoption_cast<const QStyleOptionSpinBox *>(option)) {
            if (spin->frame && spin->subControls.testFlag(SC_SpinBoxFrame))
                drawPrimitive(PE_PanelLineEdit, option, painter, widget);
            if (spin->buttonSymbols != QAbstractSpinBox::NoButtons) {
                for (const auto sub : {SC_SpinBoxUp, SC_SpinBoxDown}) {
                    if (!spin->subControls.testFlag(sub)) continue;
                    const auto step = sub == SC_SpinBoxUp ? QAbstractSpinBox::StepUpEnabled : QAbstractSpinBox::StepDownEnabled;
                    const bool canStep = enabled && spin->stepEnabled.testFlag(step);
                    const QRect rect = subControlRect(CC_SpinBox, spin, sub, widget);
                    if (spin->activeSubControls.testFlag(sub) && (hover || pressed))
                        MeoStyleHelper::drawRoundedSurface(painter, rect, 4,
                            MeoStyleHelper::stateLayer(option->palette, group, QPalette::AlternateBase, QPalette::Text, hover, pressed));
                    const QColor color = option->palette.color(canStep ? group : QPalette::Disabled, QPalette::Text);
                    if (spin->buttonSymbols == QAbstractSpinBox::PlusMinus) {
                        painter->save(); painter->setPen(QPen(color, 2));
                        painter->drawLine(rect.center() + QPoint(-4, 0), rect.center() + QPoint(4, 0));
                        if (sub == SC_SpinBoxUp) painter->drawLine(rect.center() + QPoint(0, -4), rect.center() + QPoint(0, 4));
                        painter->restore();
                    } else MeoStyleHelper::drawChevron(painter, rect.adjusted(4, 1, -4, -1), color,
                                                      sub == SC_SpinBoxUp ? Qt::UpArrow : Qt::DownArrow);
                }
            }
            return;
        }
    }
    if (control == CC_GroupBox) {
        if (const auto *box = qstyleoption_cast<const QStyleOptionGroupBox *>(option)) {
            painter->save();
            QRect content = box->rect.adjusted(8, box->fontMetrics.height() / 2, -8, -4);
            MeoStyleHelper::drawRoundedSurface(painter, content, controlRadius(),
                option->palette.color(group, QPalette::Window), option->palette.color(group, QPalette::Midlight));
            QRect label = subControlRect(CC_GroupBox, box, SC_GroupBoxLabel, widget);
            painter->fillRect(label.adjusted(-4, 0, 4, 0), option->palette.color(group, QPalette::Window));
            drawItemText(painter, label, box->textAlignment | Qt::TextShowMnemonic,
                         option->palette, enabled, box->text, QPalette::WindowText);
            if (box->subControls.testFlag(SC_GroupBoxCheckBox)) {
                QStyleOptionButton check; check.QStyleOption::operator=(*box);
                check.rect = subControlRect(CC_GroupBox, box, SC_GroupBoxCheckBox, widget);
                drawPrimitive(PE_IndicatorCheckBox, &check, painter, widget);
            }
            painter->restore(); return;
        }
    }

    if (control == CC_ComboBox) {
        const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option);
        if (!combo) {
            QProxyStyle::drawComplexControl(control, option, painter, widget);
            return;
        }

        const QPalette::ColorRole surfaceRole = QPalette::AlternateBase;
        const QPalette::ColorRole contentRole = QPalette::Text;
        if (combo->frame && option->subControls.testFlag(SC_ComboBoxFrame)) {
            const QColor fill = enabled
                ? MeoStyleHelper::stateLayer(option->palette, group, surfaceRole, contentRole,
                                              hover, pressed, focus)
                : option->palette.color(QPalette::Disabled, surfaceRole);
            const QColor outline;
            MeoStyleHelper::drawRoundedSurface(painter, option->rect.adjusted(0.5, 0.5, -0.5, -0.5),
                                                controlRadius(), fill, outline);
            if (focus) {
                MeoStyleHelper::drawFocusRing(painter, option->rect, controlRadius(),
                                               primaryColor(option->palette, group));
            }
        }

        if (option->subControls.testFlag(SC_ComboBoxArrow)) {
            const QRect arrowRect = subControlRect(CC_ComboBox, combo, SC_ComboBoxArrow, widget);
            MeoStyleHelper::drawChevron(painter, arrowRect,
                                         option->palette.color(group, contentRole), Qt::DownArrow);
        }
        return;
    }

    if (control == CC_ToolButton) {
        const auto *toolButton = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        if (!toolButton) {
            QProxyStyle::drawComplexControl(control, option, painter, widget);
            return;
        }

        // Keep Qt/Breeze's label, icon, shortcut and menu-arrow layout while
        // applying the Meo container to both ordinary and split tool buttons.
        drawPrimitive(PE_PanelButtonTool, toolButton, painter, widget);
        QStyleOptionToolButton label(*toolButton);
        drawControl(CE_ToolButtonLabel, &label, painter, widget);

        if (toolButton->features.testFlag(QStyleOptionToolButton::MenuButtonPopup)) {
            const QRect menuRect = subControlRect(CC_ToolButton, toolButton, SC_ToolButtonMenu, widget);
            if (!menuRect.isEmpty()) {
                painter->save();
                painter->setPen(QPen(toolButton->palette.color(group, QPalette::Midlight), 1.0));
                const int x = toolButton->direction == Qt::RightToLeft ? menuRect.right() : menuRect.left();
                painter->drawLine(x, option->rect.top() + 4, x, option->rect.bottom() - 4);
                painter->restore();
                MeoStyleHelper::drawChevron(painter, menuRect.adjusted(3, 8, -3, -8),
                    option->palette.color(group, QPalette::ButtonText), Qt::DownArrow);
            }
        }
        return;
    }

    if (control == CC_Slider) {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) {
            QProxyStyle::drawComplexControl(control, option, painter, widget);
            return;
        }

        if (option->subControls.testFlag(SC_SliderTickmarks)) {
            QStyleOptionSlider tickOption(*slider);
            tickOption.subControls = SC_SliderTickmarks;
            QProxyStyle::drawComplexControl(control, &tickOption, painter, widget);
        }

        const QRect grooveRect = subControlRect(CC_Slider, slider, SC_SliderGroove, widget);
        const QRect handleRect = subControlRect(CC_Slider, slider, SC_SliderHandle, widget);
        const QRectF track = centeredTrack(grooveRect, slider->orientation, Meo::DesignTokens::space4());
        if (option->subControls.testFlag(SC_SliderGroove)) {
            MeoStyleHelper::drawRoundedSurface(painter, track, Meo::DesignTokens::space2(),
                                                option->palette.color(group, QPalette::Midlight));
            MeoStyleHelper::drawRoundedSurface(painter,
                                                sliderActiveTrack(track, handleRect.center(), slider->orientation,
                                                                  slider->upsideDown),
                                                Meo::DesignTokens::space2(),
                                                primaryColor(option->palette, group));
        }

        if (option->subControls.testFlag(SC_SliderHandle)) {
            const QRectF handle = QRectF(handleRect).adjusted(1.0, 1.0, -1.0, -1.0);
            const bool handleActive = option->activeSubControls.testFlag(SC_SliderHandle);
            if (enabled && (handleActive || hover || pressed || focus)) {
                const QRectF stateLayer = handle.adjusted(-Meo::DesignTokens::space4(),
                                                           -Meo::DesignTokens::space4(),
                                                           Meo::DesignTokens::space4(),
                                                           Meo::DesignTokens::space4());
                const QColor layer = MeoStyleHelper::blend(option->palette.color(group, QPalette::Window),
                                                            primaryColor(option->palette, group),
                                                            pressed ? Meo::DesignTokens::stateOpacityPressed()
                                                                    : focus ? Meo::DesignTokens::stateOpacityFocus()
                                                                            : Meo::DesignTokens::stateOpacityHover());
                MeoStyleHelper::drawRoundedSurface(painter, stateLayer, stateLayer.width() / 2.0, layer);
            }
            MeoStyleHelper::drawRoundedSurface(painter, handle, handle.width() / 2.0,
                                                primaryColor(option->palette, group));
            if (focus) {
                MeoStyleHelper::drawFocusRing(painter, handle.adjusted(-2.0, -2.0, 2.0, 2.0),
                                               handle.width() / 2.0,
                                               primaryColor(option->palette, group));
            }
        }
        return;
    }

    if (control == CC_ScrollBar) {
        const auto *scrollBar = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!scrollBar) {
            QProxyStyle::drawComplexControl(control, option, painter, widget);
            return;
        }

        const QRect grooveRect = subControlRect(CC_ScrollBar, scrollBar, SC_ScrollBarGroove, widget);
        const QRect sliderRect = subControlRect(CC_ScrollBar, scrollBar, SC_ScrollBarSlider, widget);
        if (option->subControls.testFlag(SC_ScrollBarGroove)) {
            const QRectF track = centeredTrack(grooveRect, scrollBar->orientation,
                                                Meo::DesignTokens::space4());
            MeoStyleHelper::drawRoundedSurface(painter, track, Meo::DesignTokens::space2(),
                                                option->palette.color(group, QPalette::Midlight));
        }

        const auto drawScrollButton = [&](SubControl subControl) {
            if (!option->subControls.testFlag(subControl)) {
                return;
            }
            const QRect buttonRect = subControlRect(CC_ScrollBar, scrollBar, subControl, widget);
            if (buttonRect.isEmpty()) {
                return;
            }

            const bool active = option->activeSubControls.testFlag(subControl);
            if (active && enabled) {
                MeoStyleHelper::drawRoundedSurface(
                    painter, QRectF(buttonRect).adjusted(1.0, 1.0, -1.0, -1.0),
                    Meo::DesignTokens::shapeExtraSmall(),
                    MeoStyleHelper::stateLayer(option->palette, group, QPalette::Button,
                                                QPalette::ButtonText, true, pressed));
            }

            Qt::ArrowType direction;
            if (scrollBar->orientation == Qt::Horizontal) {
                direction = buttonRect.center().x() < option->rect.center().x()
                    ? Qt::LeftArrow
                    : Qt::RightArrow;
            } else {
                direction = buttonRect.center().y() < option->rect.center().y()
                    ? Qt::UpArrow
                    : Qt::DownArrow;
            }
            MeoStyleHelper::drawChevron(painter, buttonRect,
                                         option->palette.color(group, QPalette::ButtonText), direction);
        };
        drawScrollButton(SC_ScrollBarSubLine);
        drawScrollButton(SC_ScrollBarAddLine);

        if (option->subControls.testFlag(SC_ScrollBarSlider)) {
            const bool sliderActive = option->activeSubControls.testFlag(SC_ScrollBarSlider);
            const QColor thumb = enabled
                ? (pressed && sliderActive
                       ? primaryColor(option->palette, group)
                       : MeoStyleHelper::stateLayer(option->palette, group, QPalette::Mid,
                                                    QPalette::Text, sliderActive || hover, false, focus))
                : option->palette.color(QPalette::Disabled, QPalette::Mid);
            const QRectF thumbRect = QRectF(sliderRect).adjusted(1.0, 1.0, -1.0, -1.0);
            MeoStyleHelper::drawRoundedSurface(painter, thumbRect,
                                                qMin(thumbRect.width(), thumbRect.height()) / 2.0, thumb);
            if (focus) {
                MeoStyleHelper::drawFocusRing(painter, thumbRect,
                                               qMin(thumbRect.width(), thumbRect.height()) / 2.0,
                                               primaryColor(option->palette, group));
            }
        }
        return;
    }

    QProxyStyle::drawComplexControl(control, option, painter, widget);
}
