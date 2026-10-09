#include "meostylecontent.h"

#include "meostylehelper.h"

#include <QtGui/QIcon>
#include <QtGui/QPainter>
#include <QtGui/QPixmap>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionMenuItem>
#include <QtWidgets/QStyleOptionToolButton>

#include <meodesigntokens.h>

namespace {

QPalette::ColorGroup optionColorGroup(const QStyleOption *option)
{
    if (!option->state.testFlag(QStyle::State_Enabled)) {
        return QPalette::Disabled;
    }
    return option->state.testFlag(QStyle::State_Active) ? QPalette::Active : QPalette::Inactive;
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
    if (variant == QLatin1String("text")
        || (button && button->features.testFlag(QStyleOptionButton::Flat))) {
        return ButtonVisual::Text;
    }
    if (button && button->features.testFlag(QStyleOptionButton::DefaultButton)) {
        return ButtonVisual::Filled;
    }
    return ButtonVisual::Tonal;
}

QIcon::Mode iconMode(const QStyleOption *option)
{
    if (!option->state.testFlag(QStyle::State_Enabled)) {
        return QIcon::Disabled;
    }
    if (option->state.testFlag(QStyle::State_Active)) {
        return QIcon::Active;
    }
    return QIcon::Normal;
}

QIcon::State iconState(const QStyleOption *option)
{
    return option->state.testFlag(QStyle::State_On) ? QIcon::On : QIcon::Off;
}

int textFlags(const MeoStyleContent *style, const QStyleOption *option,
              const QWidget *widget, Qt::Alignment horizontal)
{
    int flags = Qt::TextSingleLine | Qt::TextShowMnemonic | Qt::AlignVCenter | horizontal;
    if (!style->styleHint(QStyle::SH_UnderlineShortcut, option, widget)) {
        flags |= Qt::TextHideMnemonic;
    }
    return flags;
}

QRect centeredRect(const QRect &bounds, const QSize &size)
{
    const QSize fitted(qMin(bounds.width(), size.width()), qMin(bounds.height(), size.height()));
    return QRect(bounds.x() + (bounds.width() - fitted.width()) / 2,
                 bounds.y() + (bounds.height() - fitted.height()) / 2,
                 fitted.width(), fitted.height());
}

void drawButtonLabel(const MeoStyleContent *style, const QStyleOptionButton *button,
                     QPainter *painter, const QWidget *widget)
{
    const bool enabled = button->state.testFlag(QStyle::State_Enabled);
    const QPalette::ColorGroup group = optionColorGroup(button);
    const ButtonVisual visual = buttonVisual(button, widget);

    QPalette palette = button->palette;
    const QColor foreground = visual == ButtonVisual::Filled
        ? palette.color(group, QPalette::HighlightedText)
        : visual == ButtonVisual::Text ? primaryColor(palette, group)
                                       : palette.color(group, QPalette::Text);
    palette.setColor(group, QPalette::ButtonText, foreground);

    const QRect contents = style->subElementRect(QStyle::SE_PushButtonContents, button, widget);
    const bool hasIcon = !button->icon.isNull();
    const bool hasText = !button->text.isEmpty();
    const int gap = hasIcon && hasText ? qRound(Meo::DesignTokens::space8()) : 0;
    const QSize iconSize = hasIcon
        ? QSize(qMin(contents.height(), qMax(1, button->iconSize.width())),
                qMin(contents.height(), qMax(1, button->iconSize.height())))
        : QSize();
    const int textWidth = hasText
        ? qMin(contents.width(), painter->fontMetrics().size(Qt::TextSingleLine | Qt::TextShowMnemonic,
                                                          button->text).width() + qRound(Meo::DesignTokens::space8()))
        : 0;
    const int totalWidth = qMin(contents.width(), iconSize.width() + gap + textWidth);
    int x = contents.x() + (contents.width() - totalWidth) / 2;

    if (hasIcon) {
        const QRect logicalIcon(x, contents.y() + (contents.height() - iconSize.height()) / 2,
                                iconSize.width(), iconSize.height());
        const QRect iconRect = QStyle::visualRect(button->direction, contents, logicalIcon);
        const QPixmap pixmap = button->icon.pixmap(iconSize, iconMode(button), iconState(button));
        style->drawItemPixmap(painter, iconRect, Qt::AlignCenter, pixmap);
        x += iconSize.width() + gap;
    }

    if (hasText) {
        const QRect logicalText(x, contents.y(), qMax(0, totalWidth - (x - (contents.x() + (contents.width() - totalWidth) / 2))),
                                contents.height());
        const QRect textRect = QStyle::visualRect(button->direction, contents, logicalText);
        const Qt::Alignment hAlign = button->direction == Qt::RightToLeft ? Qt::AlignRight : Qt::AlignLeft;
        style->drawItemText(painter, textRect,
                            textFlags(style, button, widget, hAlign),
                            palette, enabled, button->text, QPalette::ButtonText);
    }
}

void drawSectionLabel(const MeoStyleContent *style, const QStyleOptionMenuItem *item,
                      QPainter *painter, const QWidget *widget)
{
    if (item->text.isEmpty()) {
        return;
    }
    painter->save();
    QFont font = item->font;
    font.setBold(true);
    painter->setFont(font);
    const QRect rect = item->rect.adjusted(qRound(Meo::DesignTokens::space12()), 0,
                                           -qRound(Meo::DesignTokens::space12()), 0);
    const Qt::Alignment hAlign = item->direction == Qt::RightToLeft ? Qt::AlignRight : Qt::AlignLeft;
    style->drawItemText(painter, rect,
                        textFlags(style, item, widget, hAlign),
                        item->palette, item->state.testFlag(QStyle::State_Enabled),
                        item->text, QPalette::Text);
    painter->restore();
}

void drawMenuItem(const MeoStyleContent *style, const QStyleOptionMenuItem *item,
                  QPainter *painter, const QWidget *widget)
{
    if (item->menuItemType == QStyleOptionMenuItem::Separator) {
        drawSectionLabel(style, item, painter, widget);
        return;
    }

    const bool enabled = item->state.testFlag(QStyle::State_Enabled);
    const bool hover = item->state.testFlag(QStyle::State_MouseOver)
        || item->state.testFlag(QStyle::State_Selected);
    const bool pressed = item->state.testFlag(QStyle::State_Sunken);
    const bool focus = item->state.testFlag(QStyle::State_HasFocus);
    const QPalette::ColorGroup group = optionColorGroup(item);
    const QColor accent = primaryColor(item->palette, group);
    const QColor restingSurface = enabled
        ? tonalContainerColor(item->palette, group)
        : item->palette.color(QPalette::Disabled, QPalette::AlternateBase);
    const qreal opacity = pressed ? Meo::DesignTokens::stateOpacityPressed()
                                  : focus ? Meo::DesignTokens::stateOpacityFocus()
                                          : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0;
    const QColor fill = enabled ? MeoStyleHelper::blend(restingSurface, accent, opacity)
                                : restingSurface;
    const QRectF background = item->rect.adjusted(Meo::DesignTokens::space2(),
                                                   Meo::DesignTokens::space2(),
                                                   -Meo::DesignTokens::space2(),
                                                   -Meo::DesignTokens::space2());
    MeoStyleHelper::drawRoundedSurface(painter, background,
                                        Meo::DesignTokens::shapeLarge(), fill);
    if (focus) {
        MeoStyleHelper::drawFocusRing(painter, background,
                                       Meo::DesignTokens::shapeLarge(), accent);
    }

    const int inset = qRound(Meo::DesignTokens::space12());
    const int gap = qRound(Meo::DesignTokens::space8());
    const int iconExtent = qRound(Meo::DesignTokens::iconSizeS());
    const QRect content = item->rect.adjusted(inset, qRound(Meo::DesignTokens::space4()),
                                              -inset, -qRound(Meo::DesignTokens::space4()));
    const bool checkable = item->checkType != QStyleOptionMenuItem::NotCheckable;
    const bool hasLeading = checkable || !item->icon.isNull() || item->maxIconWidth > 0;
    const int leadingWidth = hasLeading ? qMax(iconExtent, item->maxIconWidth) : 0;
    const bool hasSubmenu = item->menuItemType == QStyleOptionMenuItem::SubMenu;
    const int arrowWidth = hasSubmenu ? iconExtent : 0;

    const QString label = item->text.section(QLatin1Char('\t'), 0, 0);
    const QString shortcut = item->text.contains(QLatin1Char('\t'))
        ? item->text.section(QLatin1Char('\t'), 1)
        : QString();
    const int shortcutWidth = shortcut.isEmpty() ? 0
        : qMax(item->reservedShortcutWidth,
               item->fontMetrics.horizontalAdvance(shortcut));

    int logicalLeft = content.left();
    QRect leadingLogical;
    if (hasLeading) {
        leadingLogical = QRect(logicalLeft, content.top(), leadingWidth, content.height());
        logicalLeft += leadingWidth + gap;
    }

    int logicalRight = content.right() + 1;
    QRect arrowLogical;
    if (hasSubmenu) {
        logicalRight -= arrowWidth;
        arrowLogical = QRect(logicalRight, content.top(), arrowWidth, content.height());
        logicalRight -= gap;
    }

    QRect shortcutLogical;
    if (!shortcut.isEmpty()) {
        logicalRight -= shortcutWidth;
        shortcutLogical = QRect(logicalRight, content.top(), shortcutWidth, content.height());
        logicalRight -= gap;
    }

    const QRect textLogical(logicalLeft, content.top(), qMax(0, logicalRight - logicalLeft), content.height());

    if (hasLeading) {
        const QRect leading = QStyle::visualRect(item->direction, content, leadingLogical);
        const QRect glyphRect = centeredRect(leading, QSize(iconExtent, iconExtent));
        if (checkable && item->checked) {
            QStyleOption indicator;
            indicator.rect = glyphRect;
            indicator.palette = item->palette;
            indicator.direction = item->direction;
            indicator.state = item->state | QStyle::State_On;
            const QStyle::PrimitiveElement primitive = item->checkType == QStyleOptionMenuItem::Exclusive
                ? QStyle::PE_IndicatorRadioButton : QStyle::PE_IndicatorCheckBox;
            style->drawPrimitive(primitive, &indicator, painter, widget);
        } else if (!item->icon.isNull()) {
            const QPixmap pixmap = item->icon.pixmap(glyphRect.size(), iconMode(item), iconState(item));
            style->drawItemPixmap(painter, glyphRect, Qt::AlignCenter, pixmap);
        }
    }

    const Qt::Alignment labelAlign = item->direction == Qt::RightToLeft ? Qt::AlignRight : Qt::AlignLeft;
    const QRect textRect = QStyle::visualRect(item->direction, content, textLogical);
    style->drawItemText(painter, textRect,
                        textFlags(style, item, widget, labelAlign),
                        item->palette, enabled, label, QPalette::Text);

    if (!shortcut.isEmpty()) {
        const QRect shortcutRect = QStyle::visualRect(item->direction, content, shortcutLogical);
        const Qt::Alignment shortcutAlign = item->direction == Qt::RightToLeft ? Qt::AlignLeft : Qt::AlignRight;
        style->drawItemText(painter, shortcutRect,
                            textFlags(style, item, widget, shortcutAlign),
                            item->palette, enabled, shortcut, QPalette::Text);
    }

    if (hasSubmenu) {
        const QRect arrowRect = QStyle::visualRect(item->direction, content, arrowLogical);
        MeoStyleHelper::drawChevron(painter, centeredRect(arrowRect, QSize(iconExtent, iconExtent)),
                                     item->palette.color(group, QPalette::Text),
                                     item->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow);
    }
}

void drawArrowPrimitive(const MeoStyleContent *style, Qt::ArrowType arrowType,
                        const QRect &rect, const QStyleOption *source,
                        QPainter *painter, const QWidget *widget)
{
    QStyle::PrimitiveElement primitive = QStyle::PE_IndicatorArrowDown;
    switch (arrowType) {
    case Qt::UpArrow: primitive = QStyle::PE_IndicatorArrowUp; break;
    case Qt::LeftArrow: primitive = QStyle::PE_IndicatorArrowLeft; break;
    case Qt::RightArrow: primitive = QStyle::PE_IndicatorArrowRight; break;
    case Qt::DownArrow:
    default: primitive = QStyle::PE_IndicatorArrowDown; break;
    }
    QStyleOption arrow;
    arrow.rect = rect;
    arrow.palette = source->palette;
    arrow.direction = source->direction;
    arrow.state = source->state;
    style->drawPrimitive(primitive, &arrow, painter, widget);
}

void drawToolButtonLabel(const MeoStyleContent *style, const QStyleOptionToolButton *button,
                         const QRect &logicalBounds, QPainter *painter, const QWidget *widget)
{
    if (logicalBounds.isEmpty()) {
        return;
    }

    const bool enabled = button->state.testFlag(QStyle::State_Enabled);
    QRect bounds = logicalBounds.adjusted(qRound(Meo::DesignTokens::space8()),
                                          qRound(Meo::DesignTokens::space4()),
                                          -qRound(Meo::DesignTokens::space8()),
                                          -qRound(Meo::DesignTokens::space4()));
    if (bounds.isEmpty()) {
        return;
    }

    Qt::ToolButtonStyle presentation = button->toolButtonStyle;
    if (presentation == Qt::ToolButtonFollowStyle) {
        presentation = static_cast<Qt::ToolButtonStyle>(
            style->styleHint(QStyle::SH_ToolButtonStyle, button, widget));
    }

    const int iconExtent = qMin(bounds.height(), qRound(Meo::DesignTokens::iconSizeS()));
    const QSize preferredIconSize = button->iconSize.isValid()
        ? QSize(qMin(iconExtent, button->iconSize.width()), qMin(iconExtent, button->iconSize.height()))
        : QSize(iconExtent, iconExtent);
    const bool hasIcon = button->arrowType != Qt::NoArrow || !button->icon.isNull();
    const bool hasText = !button->text.isEmpty() && presentation != Qt::ToolButtonIconOnly;
    const int gap = hasIcon && hasText ? qRound(Meo::DesignTokens::space8()) : 0;

    const auto drawIcon = [&](const QRect &rect) {
        if (button->arrowType != Qt::NoArrow) {
            drawArrowPrimitive(style, button->arrowType, rect, button, painter, widget);
        } else if (!button->icon.isNull()) {
            const QPixmap pixmap = button->icon.pixmap(rect.size(), iconMode(button), iconState(button));
            style->drawItemPixmap(painter, rect, Qt::AlignCenter, pixmap);
        }
    };

    if (presentation == Qt::ToolButtonTextUnderIcon && hasText) {
        const int iconHeight = hasIcon ? preferredIconSize.height() : 0;
        const int textHeight = button->fontMetrics.height();
        const int totalHeight = qMin(bounds.height(), iconHeight + gap + textHeight);
        int y = bounds.y() + (bounds.height() - totalHeight) / 2;
        if (hasIcon) {
            const QRect logicalIcon(bounds.x() + (bounds.width() - preferredIconSize.width()) / 2,
                                    y, preferredIconSize.width(), preferredIconSize.height());
            drawIcon(QStyle::visualRect(button->direction, bounds, logicalIcon));
            y += iconHeight + gap;
        }
        const QRect textRect(bounds.x(), y, bounds.width(), qMax(0, bounds.bottom() - y + 1));
        style->drawItemText(painter, textRect,
                            textFlags(style, button, widget, Qt::AlignHCenter),
                            button->palette, enabled, button->text, QPalette::ButtonText);
        return;
    }

    if (presentation == Qt::ToolButtonTextOnly || (!hasIcon && hasText)) {
        style->drawItemText(painter, bounds,
                            textFlags(style, button, widget, Qt::AlignHCenter),
                            button->palette, enabled, button->text, QPalette::ButtonText);
        return;
    }

    if (!hasText) {
        if (hasIcon) {
            drawIcon(centeredRect(bounds, preferredIconSize));
        }
        return;
    }

    const int textWidth = qMin(bounds.width(),
        button->fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, button->text).width());
    const int totalWidth = qMin(bounds.width(), preferredIconSize.width() + gap + textWidth);
    int x = bounds.x() + (bounds.width() - totalWidth) / 2;
    const QRect logicalIcon(x, bounds.y() + (bounds.height() - preferredIconSize.height()) / 2,
                            preferredIconSize.width(), preferredIconSize.height());
    drawIcon(QStyle::visualRect(button->direction, bounds, logicalIcon));
    x += preferredIconSize.width() + gap;
    const QRect logicalText(x, bounds.y(), qMax(0, totalWidth - preferredIconSize.width() - gap), bounds.height());
    const QRect textRect = QStyle::visualRect(button->direction, bounds, logicalText);
    const Qt::Alignment hAlign = button->direction == Qt::RightToLeft ? Qt::AlignRight : Qt::AlignLeft;
    style->drawItemText(painter, textRect,
                        textFlags(style, button, widget, hAlign),
                        button->palette, enabled, button->text, QPalette::ButtonText);
}

void drawLeadingLabel(const MeoStyleContent *style, const QStyleOption *option,
                      const QRect &contents, const QString &text, const QIcon &icon,
                      QSize iconSize, QPalette::ColorRole role, bool mnemonic,
                      QPainter *painter, const QWidget *widget)
{
    painter->save(); painter->setClipRect(contents, Qt::IntersectClip);
    QRect textRect = contents;
    if (!icon.isNull()) {
        if (!iconSize.isValid()) iconSize = QSize(qRound(Meo::DesignTokens::iconSizeS()), qRound(Meo::DesignTokens::iconSizeS()));
        iconSize = iconSize.boundedTo(contents.size());
        const QRect logicalIcon(contents.left(), contents.center().y() - iconSize.height() / 2,
                                iconSize.width(), iconSize.height());
        const QRect iconRect = QStyle::visualRect(option->direction, contents, logicalIcon);
        style->drawItemPixmap(painter, iconRect, Qt::AlignCenter, icon.pixmap(iconSize, iconMode(option), iconState(option)));
        const int gap = text.isEmpty() ? 0 : qRound(Meo::DesignTokens::space8());
        const QRect logicalText = contents.adjusted(iconSize.width() + gap, 0, 0, 0);
        textRect = QStyle::visualRect(option->direction, contents, logicalText);
    }
    const Qt::Alignment alignment = option->direction == Qt::RightToLeft ? Qt::AlignRight : Qt::AlignLeft;
    const int flags = mnemonic ? (textFlags(style, option, widget, alignment) & ~Qt::TextSingleLine)
                               : int(Qt::TextSingleLine | Qt::AlignVCenter | alignment);
    QPalette palette = option->palette;
    palette.setCurrentColorGroup(optionColorGroup(option));
    style->drawItemText(painter, textRect, flags, palette,
                        option->state.testFlag(QStyle::State_Enabled), text, role);
    painter->restore();
}

} // namespace

void MeoStyleContent::drawControl(ControlElement element, const QStyleOption *option,
                                  QPainter *painter, const QWidget *widget) const
{
    if (element == CE_CheckBox || element == CE_RadioButton) {
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option)) {
            const bool radio = element == CE_RadioButton;
            QStyleOptionButton indicator(*button);
            indicator.rect = subElementRect(radio ? SE_RadioButtonIndicator : SE_CheckBoxIndicator, button, widget);
            drawPrimitive(radio ? PE_IndicatorRadioButton : PE_IndicatorCheckBox, &indicator, painter, widget);
            drawControl(radio ? CE_RadioButtonLabel : CE_CheckBoxLabel, button, painter, widget);
            return;
        }
    }
    if (element == CE_CheckBoxLabel || element == CE_RadioButtonLabel) {
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option)) {
            const QRect contents = subElementRect(element == CE_RadioButtonLabel ? SE_RadioButtonContents : SE_CheckBoxContents, button, widget);
            drawLeadingLabel(this, button, contents, button->text, button->icon, button->iconSize,
                              QPalette::WindowText, true, painter, widget);
            return;
        }
    }
    if (element == CE_ComboBoxLabel) {
        if (const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option)) {
            const QRect contents = subControlRect(CC_ComboBox, combo, SC_ComboBoxEditField, widget);
            // The editable child's QLineEdit retains selection, cursor and IME.
            drawLeadingLabel(this, combo, contents, combo->editable ? QString() : combo->currentText,
                              combo->currentIcon, combo->iconSize, QPalette::Text, false, painter, widget);
            return;
        }
    }
    if (element == CE_PushButtonLabel) {
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option)) {
            drawButtonLabel(this, button, painter, widget);
            return;
        }
    }

    if (element == CE_MenuItem) {
        if (const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option)) {
            drawMenuItem(this, item, painter, widget);
            return;
        }
    }

    MeoStyle::drawControl(element, option, painter, widget);
}

void MeoStyleContent::drawComplexControl(ComplexControl control, const QStyleOptionComplex *option,
                                         QPainter *painter, const QWidget *widget) const
{
    if (control != CC_ToolButton) {
        MeoStyle::drawComplexControl(control, option, painter, widget);
        return;
    }

    const auto *button = qstyleoption_cast<const QStyleOptionToolButton *>(option);
    if (!button) {
        MeoStyle::drawComplexControl(control, option, painter, widget);
        return;
    }

    MeoStyle::drawPrimitive(PE_PanelButtonTool, button, painter, widget);

    QRect mainRect = subControlRect(CC_ToolButton, button, SC_ToolButton, widget);
    if (mainRect.isEmpty()) {
        mainRect = button->rect;
    }

    QRect menuRect;
    if (button->features.testFlag(QStyleOptionToolButton::MenuButtonPopup)) {
        menuRect = subControlRect(CC_ToolButton, button, SC_ToolButtonMenu, widget);
    }

    QRect labelRect = mainRect;
    const bool inlineMenuArrow = button->features.testFlag(QStyleOptionToolButton::HasMenu)
        && !button->features.testFlag(QStyleOptionToolButton::MenuButtonPopup);
    if (inlineMenuArrow) {
        const int arrowExtent = qRound(Meo::DesignTokens::iconSizeS());
        const QRect logicalArrow(labelRect.right() - arrowExtent + 1, labelRect.top(),
                                 arrowExtent, labelRect.height());
        const QRect arrowRect = QStyle::visualRect(button->direction, labelRect, logicalArrow);
        MeoStyleHelper::drawChevron(painter, centeredRect(arrowRect, QSize(arrowExtent, arrowExtent)),
                                     button->palette.color(optionColorGroup(button), QPalette::ButtonText),
                                     Qt::DownArrow);
        if (button->direction == Qt::RightToLeft) {
            labelRect.setLeft(labelRect.left() + arrowExtent + qRound(Meo::DesignTokens::space4()));
        } else {
            labelRect.setRight(labelRect.right() - arrowExtent - qRound(Meo::DesignTokens::space4()));
        }
    }

    drawToolButtonLabel(this, button, labelRect, painter, widget);

    if (!menuRect.isEmpty()) {
        painter->save();
        painter->setPen(QPen(button->palette.color(optionColorGroup(button), QPalette::Midlight), 1.0));
        const int separatorX = button->direction == Qt::RightToLeft ? menuRect.right() : menuRect.left();
        painter->drawLine(separatorX, button->rect.top() + qRound(Meo::DesignTokens::space4()),
                          separatorX, button->rect.bottom() - qRound(Meo::DesignTokens::space4()));
        painter->restore();
        const int arrowExtent = qRound(Meo::DesignTokens::iconSizeS());
        MeoStyleHelper::drawChevron(painter, centeredRect(menuRect, QSize(arrowExtent, arrowExtent)),
                                     button->palette.color(optionColorGroup(button), QPalette::ButtonText),
                                     Qt::DownArrow);
    }
}
