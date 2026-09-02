#include "meostyle.h"

#include "meostylehelper.h"

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

#include <meotokens.h>

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
{
    setObjectName(QStringLiteral("Meo"));
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
        result.setHeight(qMax(result.height(), qRound(Meo::DesignTokens::controlHeight())));
        break;
    case CT_LineEdit:
    case CT_ComboBox:
    case CT_SpinBox:
        result.setHeight(qMax(result.height(), qRound(Meo::DesignTokens::controlHeight())));
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
        QColor fill = enabled
            ? MeoStyleHelper::blend(surface, content,
                                    pressed ? Meo::DesignTokens::stateOpacityPressed()
                                            : focus ? Meo::DesignTokens::stateOpacityFocus()
                                                    : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0)
            : option->palette.color(QPalette::Disabled,
                                    visual == ButtonVisual::Filled ? QPalette::Highlight : QPalette::AlternateBase);
        if (textButton && enabled && !hover && !pressed && !focus) {
            fill = Qt::transparent;
        }
        const QColor outline;
        const qreal radius = buttonRadius(option, pressed);
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
            if (checked) {
                MeoStyleHelper::drawRoundedSurface(painter, indicator.adjusted(5.0, 5.0, -5.0, -5.0),
                                                    indicator.width() / 2.0,
                                                    option->palette.color(group, QPalette::HighlightedText));
            }
        } else {
            MeoStyleHelper::drawRoundedSurface(painter, indicator, Meo::DesignTokens::shapeExtraSmall(),
                                                indicatorSurface,
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

    if (element == CE_PushButtonLabel) {
        const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
        if (button) {
            QStyleOptionButton content(*button);
            QPalette palette = content.palette;
            const ButtonVisual visual = buttonVisual(button, widget);
            for (const QPalette::ColorGroup paletteGroup : {QPalette::Active,
                                                             QPalette::Inactive,
                                                             QPalette::Disabled}) {
                const QColor foreground = visual == ButtonVisual::Filled
                    ? palette.color(paletteGroup, QPalette::HighlightedText)
                    : visual == ButtonVisual::Text
                        ? primaryColor(palette, paletteGroup)
                        : palette.color(paletteGroup, QPalette::Text);
                palette.setColor(paletteGroup, QPalette::ButtonText, foreground);
            }
            content.palette = palette;
            QProxyStyle::drawControl(element, &content, painter, widget);
            return;
        }
    }

    if (element == CE_MenuItem || element == CE_MenuBarItem) {
        const auto *menuItem = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!menuItem || (element == CE_MenuItem && menuItem->menuItemType == QStyleOptionMenuItem::Separator)) {
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }

        const bool selected = option->state.testFlag(State_Selected);
        if (selected || hover || pressed || focus) {
            const QColor surface = element == CE_MenuBarItem
                ? tonalContainerColor(option->palette, group)
                : option->palette.color(group, QPalette::Window);
            const QColor accent = primaryColor(option->palette, group);
            const qreal opacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                          : focus ? Meo::DesignTokens::stateOpacityFocus()
                                                  : Meo::DesignTokens::stateOpacityHover();
            const QRectF background = option->rect.adjusted(Meo::DesignTokens::space2(),
                                                             Meo::DesignTokens::space2(),
                                                             -Meo::DesignTokens::space2(),
                                                             -Meo::DesignTokens::space2());
            MeoStyleHelper::drawRoundedSurface(painter, background, Meo::DesignTokens::shapeSmall(),
                                                MeoStyleHelper::blend(surface, accent, opacity));
            if (focus) {
                MeoStyleHelper::drawFocusRing(painter, background, Meo::DesignTokens::shapeSmall(), accent);
            }
        }

        // Ask the platform base to retain native icon/check/submenu/mnemonic
        // layout, but suppress its own selected rectangle so the Meo state
        // layer above remains the single visual selection treatment.
        QStyleOptionMenuItem content(*menuItem);
        content.state &= ~(State_Selected | State_Sunken | State_MouseOver | State_HasFocus);
        QProxyStyle::drawControl(element, &content, painter, widget);
        return;
    }

    if (element == CE_TabBarTab) {
        drawControl(CE_TabBarTabShape, option, painter, widget);
        QProxyStyle::drawControl(CE_TabBarTabLabel, option, painter, widget);
        return;
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

        // QStyledItemDelegate continues to own icon/text/check geometry.  Remove
        // only the platform selection rectangle after drawing Meo's state layer.
        drawItemViewSurface(item, painter);
        QStyleOptionViewItem content(*item);
        content.state &= ~(State_Selected | State_MouseOver | State_Sunken | State_HasFocus);
        QProxyStyle::drawControl(element, &content, painter, widget);
        return;
    }

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
                                                primaryColor(option->palette, colorGroup(option)));
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
        QProxyStyle::drawControl(CE_ToolButtonLabel, &label, painter, widget);

        if (toolButton->features.testFlag(QStyleOptionToolButton::MenuButtonPopup)) {
            const QRect menuRect = subControlRect(CC_ToolButton, toolButton, SC_ToolButtonMenu, widget);
            if (!menuRect.isEmpty()) {
                painter->save();
                painter->setPen(QPen(toolButton->palette.color(group, QPalette::Midlight), 1.0));
                const int x = toolButton->direction == Qt::RightToLeft ? menuRect.right() : menuRect.left();
                painter->drawLine(x, option->rect.top() + 4, x, option->rect.bottom() - 4);
                painter->restore();
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
