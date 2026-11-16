#include "meostyleoverflowicon.h"
#include "meostyleprogress.h"
#include "meostylegroup.h"
#include "meostyleheader.h"
#include "meostyleitem.h"
#include "meostyle.h"
#include "meostyleanimation.h"
#include "meostyletab.h"
#include "meostyletrack.h"

#include "meostylehelper.h"

#include <QtGui/QPainterPath>
#include <QtGui/QPainter>
#include <QtGui/QIcon>
#include <QtGui/QPixmap>
#include <QtWidgets/QApplication>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionComplex>
#include <QtWidgets/QStyleOptionMenuItem>
#include <QtWidgets/QStyleFactory>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionProgressBar>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionSpinBox>
#include <QtWidgets/QStyleOptionTab>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QStyleOptionViewItem>
#include <QtWidgets/QWidget>

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
    : QProxyStyle(createPlatformBaseStyle()), m_animation(std::make_unique<MeoStyleAnimationEngine>(this))
{
    setObjectName(QStringLiteral("Meo"));
}

MeoStyle::~MeoStyle() = default;

qreal MeoStyle::animatedValue(const QWidget *widget, const QString &channel, qreal target, bool spatial) const
{
    return m_animation->value(widget, channel, target, spatial);
}

void MeoStyle::polish(QWidget *widget)
{
    QProxyStyle::polish(widget);
    m_animation->watch(widget);
}

void MeoStyle::unpolish(QWidget *widget)
{
    m_animation->forget(widget);
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

QIcon MeoStyle::standardIcon(StandardPixmap icon, const QStyleOption *option, const QWidget *widget) const
{
    if (icon != SP_ToolBarHorizontalExtensionButton && icon != SP_ToolBarVerticalExtensionButton)
        return QProxyStyle::standardIcon(icon, option, widget);
    const QPalette palette = option ? option->palette : widget ? widget->palette() : standardPalette();
    const Qt::LayoutDirection direction = option ? option->direction : widget ? widget->layoutDirection() : Qt::LeftToRight;
    return QIcon(new MeoOverflowIcon(icon == SP_ToolBarVerticalExtensionButton, widget, palette, direction));
}

int MeoStyle::pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const
{
    switch (metric) {
    case PM_ToolTipLabelFrameWidth:
        return qRound(Meo::DesignTokens::space8());
    case PM_DefaultFrameWidth:
    case PM_SpinBoxFrameWidth:
        return qRound(Meo::DesignTokens::space2() / 2.0);
    case PM_TabCloseIndicatorWidth:
    case PM_TabCloseIndicatorHeight:
        return qRound(Meo::DesignTokens::space24());
    case PM_TabBarTabHSpace:
        return 2 * qRound(Meo::DesignTokens::space12());
    case PM_TabBarTabVSpace:
        return 2 * qRound(Meo::DesignTokens::space4());
    case PM_TabBarTabOverlap:
    case PM_TabBarTabShiftHorizontal:
    case PM_TabBarTabShiftVertical:
        return 0;
    case PM_ProgressBarChunkWidth:
        return qRound(Meo::DesignTokens::space8());
    case PM_ToolBarFrameWidth:
    case PM_MenuBarPanelWidth:
        return 0;
    case PM_ToolBarItemSpacing:
    case PM_ToolBarItemMargin:
    case PM_MenuBarHMargin:
    case PM_MenuBarVMargin:
    case PM_MenuBarItemSpacing:
        return qRound(Meo::DesignTokens::space4());
    case PM_ToolBarHandleExtent:
    case PM_ToolBarSeparatorExtent:
        return qRound(Meo::DesignTokens::space12());
    case PM_ToolBarExtensionExtent:
        return qRound(Meo::DesignTokens::space24());
    case PM_ToolBarIconSize:
        return qRound(Meo::DesignTokens::iconSizeS());
    case PM_CheckBoxLabelSpacing:
        return qRound(Meo::DesignTokens::space8());
    case PM_HeaderMargin:
        return qRound(Meo::DesignTokens::space12());
    case PM_HeaderMarkSize:
        return qRound(Meo::DesignTokens::iconSizeS());
    case PM_TreeViewIndentation:
        return qRound(Meo::DesignTokens::space24());
    case PM_ButtonMargin:
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
    case PM_ScrollBarSliderMin:
        return qRound(Meo::DesignTokens::space32());
    case PM_ScrollBarExtent:
        return qRound(Meo::DesignTokens::space12() + Meo::DesignTokens::space2());
    case PM_SliderThickness:
    case PM_SliderControlThickness:
        return qRound(Meo::DesignTokens::sliderThumbHeightXS());
    case PM_SliderTickmarkOffset:
        return 0; // Stops are drawn on the track, not beside it.
    case PM_SliderSpaceAvailable:
        if (const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option))
            return qMax(0, (slider->orientation == Qt::Horizontal ? option->rect.width() : option->rect.height()) - qRound(MeoTrack::sliderHitLength));
        break;
    case PM_SliderLength:
        return qRound(MeoTrack::sliderHitLength);
    default:
        break;
    }
    return QProxyStyle::pixelMetric(metric, option, widget);
}

int MeoStyle::styleHint(StyleHint hint, const QStyleOption *option, const QWidget *widget,
                        QStyleHintReturn *returnData) const
{
    if (hint == SH_ToolTipLabel_Opacity) return 255;
    if (hint == SH_ToolTip_Mask && option) {
        if (auto *mask = qstyleoption_cast<QStyleHintReturnMask *>(returnData)) {
            QPainterPath path;
            path.addRoundedRect(option->rect, Meo::DesignTokens::shapeSmall(), Meo::DesignTokens::shapeSmall());
            mask->region = QRegion(path.toFillPolygon().toPolygon());
            return true;
        }
        return false;
    }
    if (hint == SH_DrawMenuBarSeparator) return false;
    if (hint == SH_ScrollBar_Transient) return false;
    if (hint == SH_GroupBox_TextLabelColor && option) return int(option->palette.color(colorGroup(option), QPalette::WindowText).rgba());
    return QProxyStyle::styleHint(hint, option, widget, returnData);
}

QSize MeoStyle::sizeFromContents(ContentsType type, const QStyleOption *option,
                                  const QSize &contentsSize, const QWidget *widget) const
{
    QSize result = contentsSize;
    switch (type) {
    case CT_Slider: {
        const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
        if (!slider) return contentsSize;
        QSize size = slider->orientation == Qt::Horizontal ? contentsSize : contentsSize.transposed();
        // Room for the 44dp bar thumb; tick marks live on the track.
        size.setHeight(qRound(Meo::DesignTokens::sliderThumbHeightXS()));
        return slider->orientation == Qt::Horizontal ? size : size.transposed();
    }
    case CT_ProgressBar: {
        const auto *bar = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (!bar) return contentsSize;
        QSize size = MeoProgress::horizontal(*bar) ? contentsSize : contentsSize.transposed();
        const int thickness = bar->textVisible ? qMax(qRound(Meo::DesignTokens::space24()), bar->fontMetrics.height() + qRound(Meo::DesignTokens::space8()))
                                               : qRound(Meo::DesignTokens::space8());
        size.setHeight(thickness);
        return MeoProgress::horizontal(*bar) ? size : size.transposed();
    }
    case CT_MenuBar:
        return contentsSize; // QMenuBar already includes the owned margins.
    case CT_MenuBarItem: {
        if (const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option)) {
            const QSize content = item->icon.isNull() ? item->fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, item->text)
                : QSize(qRound(Meo::DesignTokens::iconSizeS()), qRound(Meo::DesignTokens::iconSizeS()));
            return QSize(content.width() + 2 * qRound(Meo::DesignTokens::space12()),
                qMax(qRound(Meo::DesignTokens::controlHeight()), content.height() + 2 * qRound(Meo::DesignTokens::space4())));
        }
        return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
    }
    case CT_GroupBox:
        if (const auto *group = qstyleoption_cast<const QStyleOptionGroupBox *>(option)) return MeoGroup::sizeHint(*group, contentsSize);
        return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
    case CT_HeaderSection:
        if (const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option)) return MeoHeader::sizeHint(*header);
        return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
    case CT_SpinBox: {
        const auto *spin = qstyleoption_cast<const QStyleOptionSpinBox *>(option);
        const int buttons = spin && spin->buttonSymbols == QAbstractSpinBox::NoButtons ? 0 : qRound(Meo::DesignTokens::space32());
        return QSize(contentsSize.width() + buttons + qRound(Meo::DesignTokens::space12() + Meo::DesignTokens::space8()),
                     qMax(qRound(Meo::DesignTokens::controlHeight()), contentsSize.height() + 2 * qRound(Meo::DesignTokens::space4())));
    }
    case CT_ItemViewItem:
        if (const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option)) return MeoItem::sizeHint(*item);
        return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
    case CT_TabBarTab: {
        const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option);
        if (!tab) return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
        // QTabBar already includes PM_TabBarTabH/VSpace and its own 4px
        // gaps in contentsSize. Measure the option directly to avoid double
        // padding and make all gaps follow the shared contract.
        const bool rotated = MeoTab::vertical(tab->shape);
        QSize icon = tab->icon.isNull() ? QSize(0, 0) : tab->iconSize;
        if (!icon.isValid()) icon = QSize(qRound(Meo::DesignTokens::iconSizeS()), qRound(Meo::DesignTokens::iconSizeS()));
        int width = tab->fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, tab->text).width() + icon.width();
        int height = qMax(tab->fontMetrics.height(), icon.height());
        const int gap = qRound(Meo::DesignTokens::space8());
        if (!tab->icon.isNull() && !tab->text.isEmpty()) width += gap;
        for (QSize button : {tab->leftButtonSize, tab->rightButtonSize}) {
            if (button.isEmpty()) continue;
            if (rotated) button.transpose();
            width += button.width() + gap;
            height = qMax(height, button.height());
        }
        QSize size(width + 2 * qRound(Meo::DesignTokens::space12()),
                   qMax(qRound(Meo::DesignTokens::controlHeight()), height + 2 * qRound(Meo::DesignTokens::space4())));
        return rotated ? size.transposed() : size;
    }
    case CT_PushButton:
        result.setWidth(contentsSize.width() + 2 * qRound(Meo::DesignTokens::space16()));
        if (const auto *button = qstyleoption_cast<const QStyleOptionButton *>(option);
            button && button->features.testFlag(QStyleOptionButton::HasMenu)) {
            result.rwidth() += qRound(Meo::DesignTokens::iconSizeS() + Meo::DesignTokens::space8());
        }
        result.setHeight(qMax(contentsSize.height() + 2 * qRound(Meo::DesignTokens::space4()), qRound(Meo::DesignTokens::controlHeight())));
        break;
    case CT_ToolButton: {
        int horizontal = 2 * qRound(Meo::DesignTokens::space8());
        const auto *button = qstyleoption_cast<const QStyleOptionToolButton *>(option);
        if (button && button->features.testFlag(QStyleOptionToolButton::HasMenu)) {
            horizontal += qRound(button->features.testFlag(QStyleOptionToolButton::MenuButtonPopup)
                ? Meo::DesignTokens::space32() : Meo::DesignTokens::iconSizeS());
        }
        result.setWidth(contentsSize.width() + horizontal);
        result.setHeight(qMax(contentsSize.height() + 2 * qRound(Meo::DesignTokens::space4()), qRound(Meo::DesignTokens::controlHeight())));
        break;
    }
    case CT_CheckBox:
    case CT_RadioButton:
        return QSize(contentsSize.width() + qRound(Meo::DesignTokens::space4() * 2
                     + Meo::DesignTokens::iconSizeS() + Meo::DesignTokens::space8()),
                     qMax(qRound(Meo::DesignTokens::controlHeight()), contentsSize.height() + qRound(Meo::DesignTokens::space8())));
    case CT_ComboBox:
        result.setWidth(contentsSize.width()
            + qRound(Meo::DesignTokens::space12() + Meo::DesignTokens::space8()
                     + Meo::DesignTokens::controlHeight()));
        result.setHeight(qMax(contentsSize.height() + qRound(Meo::DesignTokens::space8()), qRound(Meo::DesignTokens::controlHeight())));
        break;
    case CT_LineEdit: {
        const bool search = widget && widget->property("meo.role").toString() == QLatin1String("search");
        const int inset = qRound(search ? Meo::DesignTokens::space16() : Meo::DesignTokens::space12());
        return QSize(contentsSize.width() + 2 * inset,
                     qMax(contentsSize.height() + 2 * qRound(Meo::DesignTokens::space4()), qRound(Meo::DesignTokens::controlHeight())));
    }
    case CT_MenuItem: {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!item) return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
        if (item->menuItemType == QStyleOptionMenuItem::Separator && item->text.isEmpty()) {
            return QSize(0, qRound(Meo::DesignTokens::space8()));
        }
        QFont font = item->font;
        if (item->menuItemType == QStyleOptionMenuItem::DefaultItem
            || item->menuItemType == QStyleOptionMenuItem::Separator) font.setBold(true);
        const QFontMetrics metrics(font);
        const QString label = item->text.section(QLatin1Char('\t'), 0, 0);
        const QString shortcut = item->text.contains(QLatin1Char('\t'))
            ? item->text.section(QLatin1Char('\t'), 1) : QString();
        const int gap = qRound(Meo::DesignTokens::space8());
        const int icon = qRound(Meo::DesignTokens::iconSizeS());
        int width = metrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, label).width()
            + 2 * qRound(Meo::DesignTokens::space12());
        if (item->menuItemType != QStyleOptionMenuItem::Separator) {
            if (item->menuHasCheckableItems || item->checkType != QStyleOptionMenuItem::NotCheckable
                || !item->icon.isNull() || item->maxIconWidth > 0) width += qMax(icon, item->maxIconWidth) + gap;
            if (!shortcut.isEmpty()) width += qMax(item->reservedShortcutWidth, metrics.horizontalAdvance(shortcut)) + gap;
            if (item->menuItemType == QStyleOptionMenuItem::SubMenu) width += icon + gap;
        }
        const int minimum = qRound(item->menuItemType == QStyleOptionMenuItem::Separator
            ? Meo::DesignTokens::space32() : Meo::DesignTokens::controlHeight() + Meo::DesignTokens::space8());
        return QSize(width, qMax(minimum, metrics.height() + 2 * qRound(Meo::DesignTokens::space4())));
    }
    default:
        return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
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

    if (element == PE_PanelTipLabel) {
        QColor outline = option->palette.color(group, QPalette::ToolTipText); outline.setAlphaF(0.16);
        MeoStyleHelper::drawRoundedSurface(painter, QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5),
            Meo::DesignTokens::shapeSmall(), option->palette.color(group, QPalette::ToolTipBase), outline);
        return;
    }
    if (element == PE_FrameStatusBarItem) return; // No per-item platform bevel.
    if (element == PE_PanelStatusBar) {
        painter->fillRect(option->rect, option->palette.brush(group, QPalette::Window));
        return;
    }
    if (element == PE_PanelToolBar || element == PE_PanelMenuBar) {
        painter->fillRect(option->rect, option->palette.brush(group, QPalette::Window));
        return;
    }
    if (element == PE_IndicatorToolBarSeparator || element == PE_IndicatorToolBarHandle) {
        painter->save(); painter->setClipRect(option->rect, Qt::IntersectClip);
        const QColor color = MeoStyleHelper::outlineVariant(option->palette, group);
        painter->setPen(QPen(color, 1.0, Qt::SolidLine, Qt::RoundCap));
        const QRectF rect = QRectF(option->rect).adjusted(Meo::DesignTokens::space8(), Meo::DesignTokens::space8(),
            -Meo::DesignTokens::space8(), -Meo::DesignTokens::space8());
        const QPointF center = QRectF(option->rect).center();
        const bool horizontal = option->state.testFlag(State_Horizontal);
        if (element == PE_IndicatorToolBarSeparator) {
            if (horizontal && rect.height() > 0) painter->drawLine(QPointF(center.x(), rect.top()), QPointF(center.x(), rect.bottom()));
            else if (!horizontal && rect.width() > 0) painter->drawLine(QPointF(rect.left(), center.y()), QPointF(rect.right(), center.y()));
        } else {
            painter->setRenderHint(QPainter::Antialiasing); painter->setPen(Qt::NoPen); painter->setBrush(color);
            for (int row = -1; row <= 1; ++row) for (int column = -1; column <= 0; ++column) {
                const QPointF offset(column * Meo::DesignTokens::space4() + Meo::DesignTokens::space2(), row * Meo::DesignTokens::space4());
                painter->drawEllipse(center + (horizontal ? offset : QPointF(offset.y(), offset.x())), 1.0, 1.0);
            }
        }
        painter->restore(); return;
    }
    if (element == PE_IndicatorBranch) {
        if (!option->state.testFlag(State_Children)) return;
        const int extent = qMin(qRound(Meo::DesignTokens::iconSizeS()), qMin(option->rect.width(), option->rect.height()));
        const QRect glyph(option->rect.center().x() - extent / 2, option->rect.center().y() - extent / 2, extent, extent);
        const QColor foreground = option->palette.color(group, QPalette::Text);
        if (enabled && hover) MeoStyleHelper::drawRoundedSurface(painter, glyph, Meo::DesignTokens::shapeExtraSmall(),
            MeoStyleHelper::blend(option->palette.color(group, QPalette::Window), foreground, Meo::DesignTokens::stateOpacityHover()));
        MeoStyleHelper::drawChevron(painter, glyph, foreground, option->state.testFlag(State_Open) ? Qt::DownArrow
            : option->direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow);
        return;
    }
    if (element == PE_IndicatorHeaderArrow) {
        if (const auto *header = qstyleoption_cast<const QStyleOptionHeader *>(option);
            header && header->sortIndicator != QStyleOptionHeader::None) {
            // Keep Qt's SortUp-to-downward-glyph convention.
            MeoStyleHelper::drawChevron(painter, option->rect, option->palette.color(group, QPalette::Text),
                header->sortIndicator == QStyleOptionHeader::SortUp ? Qt::DownArrow : Qt::UpArrow);
        }
        return;
    }
    if (element == PE_IndicatorTabClose) {
        const QColor foreground = option->palette.color(group, QPalette::WindowText);
        if (enabled && (hover || pressed)) {
            MeoStyleHelper::drawRoundedSurface(painter, option->rect, option->rect.height() / 2.0,
                MeoStyleHelper::blend(option->palette.color(group, QPalette::Window), foreground,
                    pressed ? Meo::DesignTokens::stateOpacityPressed() : Meo::DesignTokens::stateOpacityHover()));
        }
        const qreal half = Meo::DesignTokens::space4();
        const QPointF center = QRectF(option->rect).center();
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setPen(QPen(foreground, Meo::DesignTokens::space2(), Qt::SolidLine, Qt::RoundCap));
        painter->drawLine(center + QPointF(-half, -half), center + QPointF(half, half));
        painter->drawLine(center + QPointF(-half, half), center + QPointF(half, -half));
        painter->restore();
        return;
    }
    if (element == PE_PanelMenu) {
        const QColor outline = MeoStyleHelper::outlineVariant(option->palette, group);
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
        const qreal layer = animatedValue(widget, QStringLiteral("button.layer"), enabled ?
            (pressed ? Meo::DesignTokens::stateOpacityPressed() : focus ? Meo::DesignTokens::stateOpacityFocus()
                     : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0) : 0.0);
        const qreal press = animatedValue(widget, QStringLiteral("button.press"), enabled && pressed ? 1.0 : 0.0, true);
        const qreal focusAmount = animatedValue(widget, QStringLiteral("button.focus"), enabled && focus ? 1.0 : 0.0);
        const qreal selection = animatedValue(widget, QStringLiteral("button.checked"), checked ? 1.0 : 0.0);
        QColor fill = enabled
            ? MeoStyleHelper::blend(surface, content,
                                    layer)
            : option->palette.color(QPalette::Disabled,
                                    visual == ButtonVisual::Filled ? QPalette::Highlight : QPalette::AlternateBase);
        if (enabled && toolButton) {
            fill = MeoStyleHelper::blend(primaryColor(option->palette, group),
                MeoStyleHelper::blend(tonalContainerColor(option->palette, group),
                                      option->palette.color(group, QPalette::Text), layer), selection);
            fill.setAlphaF(qMax(selection, layer));
        } else if (textButton && enabled) {
            fill = content;
            fill.setAlphaF(layer);
        }
        const QColor outline;
        const qreal radius = buttonRadius(option, false) + (buttonRadius(option, true) - buttonRadius(option, false)) * press;
        MeoStyleHelper::drawRoundedSurface(painter, option->rect, radius, fill, outline);
        if (focusAmount > 0) {
            painter->save(); painter->setOpacity(painter->opacity() * focusAmount);
            MeoStyleHelper::drawFocusRing(painter, option->rect, radius,
                                           primaryColor(option->palette, group));
            painter->restore();
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
        const qreal focusAmount = animatedValue(widget, QStringLiteral("field.focus"), enabled && focus ? 1.0 : 0.0);
        if (focusAmount > 0) {
            painter->save(); painter->setOpacity(painter->opacity() * focusAmount);
            MeoStyleHelper::drawFocusRing(painter, option->rect, radius,
                                           primaryColor(option->palette, group));
            painter->restore();
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
        // A delegate's model identity cannot be inferred from its screen rect.
        // Keep item checks immediate; standalone check/radio widgets animate.
        const QWidget *animationWidget = element == PE_IndicatorItemViewItemCheck ? nullptr : widget;
        const QString key = QStringLiteral("indicator.");
        const qreal checkedAmount = animatedValue(animationWidget, key + QStringLiteral("checked"), checked ? 1.0 : 0.0, true);
        const qreal partialAmount = animatedValue(animationWidget, key + QStringLiteral("partial"), partial ? 1.0 : 0.0);
        const qreal focusAmount = animatedValue(animationWidget, key + QStringLiteral("focus"), enabled && focus ? 1.0 : 0.0);
        const qreal layer = animatedValue(animationWidget, key + QStringLiteral("layer"), enabled ?
            (pressed ? Meo::DesignTokens::stateOpacityPressed() : focus ? Meo::DesignTokens::stateOpacityFocus()
                     : hover ? Meo::DesignTokens::stateOpacityHover() : 0.0) : 0.0);
        const QColor primary = primaryColor(option->palette, group);
        // MeoCheckbox/MeoRadioButton: a transparent box with a 2px
        // onSurfaceVariant outline at rest; the selected box fills with primary.
        const QColor outline = MeoStyleHelper::onSurfaceVariant(option->palette, group);
        const qreal stroke = Meo::DesignTokens::space2();
        const qreal selected = qMax(checkedAmount, partialAmount);
        const QColor restingSurface = option->palette.color(group,
            element == PE_IndicatorItemViewItemCheck ? QPalette::Base : QPalette::Window);
        const QColor content = option->palette.color(group, QPalette::WindowText);
        if (element == PE_IndicatorRadioButton) {
            // A selected radio keeps a transparent centre with a primary ring and dot.
            MeoStyleHelper::drawRoundedSurface(painter, indicator, indicator.width() / 2.0,
                                                MeoStyleHelper::blend(restingSurface, content, layer),
                                                MeoStyleHelper::blend(outline, primary, checkedAmount), stroke);
            if (checkedAmount > 0) {
                painter->save(); painter->setOpacity(painter->opacity() * checkedAmount);
                const QRectF dot = indicator.adjusted(5.0, 5.0, -5.0, -5.0);
                MeoStyleHelper::drawRoundedSurface(painter, dot, dot.width() / 2.0, primary);
                painter->restore();
            }
        } else {
            QColor indicatorSurface = MeoStyleHelper::blend(restingSurface, primary, selected);
            indicatorSurface = MeoStyleHelper::blend(indicatorSurface,
                MeoStyleHelper::blend(content, option->palette.color(group, QPalette::HighlightedText), selected), layer);
            MeoStyleHelper::drawRoundedSurface(painter, indicator, Meo::DesignTokens::shapeExtraSmall(),
                                                indicatorSurface,
                                                MeoStyleHelper::blend(outline, primary, selected), stroke);
            if (checkedAmount > 0) {
                painter->save(); painter->setOpacity(painter->opacity() * checkedAmount);
                MeoStyleHelper::drawCheckMark(painter, indicator,
                                               option->palette.color(group, QPalette::HighlightedText));
                painter->restore();
            }
            if (partialAmount > 0) {
                painter->save(); painter->setOpacity(painter->opacity() * partialAmount);
                painter->fillRect(indicator.adjusted(4.0, indicator.height() / 2.0 - 1.0,
                                                     -4.0, -indicator.height() / 2.0 + 1.0),
                                  option->palette.color(group, QPalette::HighlightedText));
                painter->restore();
            }
        }
        if (layer > 0) {
            QColor interactionRing = primary;
            interactionRing.setAlphaF(qMin(qreal(0.60), layer * 5.0));
            MeoStyleHelper::drawFocusRing(painter, option->rect.adjusted(-1.0, -1.0, 1.0, 1.0),
                                           controlRadius(), interactionRing);
        }
        if (focusAmount > 0) {
            painter->save(); painter->setOpacity(painter->opacity() * focusAmount);
            MeoStyleHelper::drawFocusRing(painter, option->rect.adjusted(-2.0, -2.0, 2.0, 2.0),
                                           controlRadius(), primary);
            painter->restore();
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
                QStyleOptionMenuItem section(*menuItem);
                section.state &= ~(State_Selected | State_Sunken | State_MouseOver | State_HasFocus);
                QProxyStyle::drawControl(element, &section, painter, widget);
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

        // Breeze remains responsible for icon/check/submenu/mnemonic geometry.
        // Strip only interaction state so its own selected rectangle does not
        // paint over the Meo action card.
        QStyleOptionMenuItem content(*menuItem);
        content.state &= ~(State_Selected | State_Sunken | State_MouseOver | State_HasFocus);
        QProxyStyle::drawControl(element, &content, painter, widget);
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

        QStyleOptionMenuItem content(*menuItem);
        content.state &= ~(State_Selected | State_Sunken | State_MouseOver | State_HasFocus);
        QProxyStyle::drawControl(element, &content, painter, widget);
        return;
    }

    if (element == CE_TabBarTab) {
        drawControl(CE_TabBarTabShape, option, painter, widget);
        drawControl(CE_TabBarTabLabel, option, painter, widget);
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

    if (element == CE_ProgressBar || element == CE_ProgressBarGroove
        || element == CE_ProgressBarContents || element == CE_ProgressBarLabel) {
        if (const auto *bar = qstyleoption_cast<const QStyleOptionProgressBar *>(option)) {
            // MeoProgressBar: a 4dp primary segment, a 4dp gap, then the
            // secondaryContainer track, ending in a 4dp primary stop.
            const auto layout = MeoProgress::layout(*bar);
            QStyleOptionProgressBar thin(*bar);
            thin.rect = MeoProgress::thinBar(*bar, layout.bar);
            const bool horizontal = MeoProgress::horizontal(*bar);
            const bool indeterminate = bar->minimum == 0 && bar->maximum == 0;
            const qreal phase = indeterminate ? m_animation->progressPhase(widget) : 0.0;
            const auto active = MeoProgress::activeRects(thin, phase);
            const QColor surface = bar->palette.color(group, QPalette::Window);
            const QColor content = bar->palette.color(group, QPalette::WindowText);
            const QColor primary = primaryColor(bar->palette, group);
            const QColor activeColor = enabled ? primary : MeoStyleHelper::blend(surface, content, 0.38);
            const QColor trackColor = enabled ? MeoStyleHelper::secondaryContainer(bar->palette, group, primary)
                                              : MeoStyleHelper::blend(surface, content, 0.12);
            const QRectF lane(thin.rect);
            const qreal radius = Meo::DesignTokens::progressTrackThickness() / 2.0;
            painter->save();
            painter->setRenderHint(QPainter::Antialiasing);
            painter->setPen(Qt::NoPen);

            if (element == CE_ProgressBar || element == CE_ProgressBarGroove) {
                // The track is the lane minus each active segment widened by the gap.
                QList<QPair<qreal, qreal>> pieces{{horizontal ? lane.left() : lane.top(),
                                                   horizontal ? lane.right() : lane.bottom()}};
                for (const auto &rect : active) {
                    if (rect.isEmpty()) continue;
                    const qreal length = horizontal ? rect.width() : rect.height();
                    const qreal gap = qMin(length, Meo::DesignTokens::progressTrackActiveGap());
                    const qreal cutFrom = (horizontal ? rect.left() : rect.top()) - gap;
                    const qreal cutTo = (horizontal ? rect.right() : rect.bottom()) + gap;
                    QList<QPair<qreal, qreal>> next;
                    for (const auto &piece : pieces) {
                        if (cutFrom > piece.first) next.append({piece.first, qMin(piece.second, cutFrom)});
                        if (cutTo < piece.second) next.append({qMax(piece.first, cutTo), piece.second});
                    }
                    pieces = next;
                }
                painter->setBrush(trackColor);
                for (const auto &piece : pieces) {
                    painter->drawPath(MeoTrack::segment(lane, horizontal, piece.first, piece.second, radius, radius));
                }
                // End stop at the far end of the fill direction.
                const qint64 range = qint64(bar->maximum) - bar->minimum;
                if (!indeterminate && range > 0 && bar->progress < bar->maximum) {
                    const QRectF end = MeoProgress::segment(thin, 0.999, 1.0);
                    const qreal stop = Meo::DesignTokens::progressStopSize() / 2.0;
                    const bool atOrigin = horizontal ? end.center().x() < lane.center().x()
                                                     : end.center().y() < lane.center().y();
                    const QPointF centerPoint = horizontal
                        ? QPointF(atOrigin ? lane.left() + stop : lane.right() - stop, lane.center().y())
                        : QPointF(lane.center().x(), atOrigin ? lane.top() + stop : lane.bottom() - stop);
                    painter->setBrush(activeColor);
                    painter->drawEllipse(centerPoint, stop, stop);
                }
            }
            if (element == CE_ProgressBar || element == CE_ProgressBarContents) {
                painter->setBrush(activeColor);
                for (const auto &rect : active) {
                    if (!rect.isEmpty()) painter->drawRoundedRect(rect, radius, radius);
                }
            }
            if ((element == CE_ProgressBar || element == CE_ProgressBarLabel) && !layout.label.isEmpty()) {
                QPalette palette = bar->palette; palette.setCurrentColorGroup(group);
                drawItemText(painter, layout.label,
                             int((bar->direction == Qt::RightToLeft ? Qt::AlignLeft : Qt::AlignRight)
                                 | Qt::AlignVCenter | Qt::TextSingleLine),
                             palette, enabled, bar->text, QPalette::WindowText);
            }
            painter->restore();
            return;
        }
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

    if (control == CC_SpinBox) {
        if (const auto *spin = qstyleoption_cast<const QStyleOptionSpinBox *>(option)) {
            if (spin->frame && spin->subControls.testFlag(SC_SpinBoxFrame)) drawPrimitive(PE_PanelLineEdit, spin, painter, widget);
            for (const auto part : {SC_SpinBoxUp, SC_SpinBoxDown}) {
                if (!spin->subControls.testFlag(part)) continue;
                const QRect rect = subControlRect(control, spin, part, widget);
                if (rect.isEmpty()) continue;
                const bool stepEnabled = enabled && spin->stepEnabled.testFlag(part == SC_SpinBoxUp
                    ? QAbstractSpinBox::StepUpEnabled : QAbstractSpinBox::StepDownEnabled);
                const bool active = spin->activeSubControls.testFlag(part);
                const auto buttonGroup = stepEnabled ? group : QPalette::Disabled;
                if (stepEnabled && active && (hover || pressed)) {
                    MeoStyleHelper::drawRoundedSurface(painter, rect.adjusted(2, 2, -2, -2), Meo::DesignTokens::shapeExtraSmall(),
                        MeoStyleHelper::stateLayer(spin->palette, buttonGroup, QPalette::AlternateBase, QPalette::Text, hover, pressed));
                }
                const int extent = qMin(rect.height(), qRound(Meo::DesignTokens::iconSizeS()));
                const QRect glyph(rect.center().x() - extent / 2, rect.center().y() - extent / 2, extent, extent);
                const QColor foreground = spin->palette.color(buttonGroup, QPalette::Text);
                if (spin->buttonSymbols == QAbstractSpinBox::PlusMinus) {
                    painter->save(); painter->setRenderHint(QPainter::Antialiasing);
                    painter->setPen(QPen(foreground, Meo::DesignTokens::space2(), Qt::SolidLine, Qt::RoundCap));
                    const QPointF center = QRectF(glyph).center();
                    const qreal half = Meo::DesignTokens::space4();
                    painter->drawLine(center + QPointF(-half, 0), center + QPointF(half, 0));
                    if (part == SC_SpinBoxUp) painter->drawLine(center + QPointF(0, -half), center + QPointF(0, half));
                    painter->restore();
                } else MeoStyleHelper::drawChevron(painter, glyph, foreground, part == SC_SpinBoxUp ? Qt::UpArrow : Qt::DownArrow);
            }
            return;
        }
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
                painter->setPen(QPen(MeoStyleHelper::outlineVariant(toolButton->palette, group), 1.0));
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

        // MeoSlider: a 16dp split track that breaks 6dp either side of a
        // 4x44dp bar thumb, with a contrasting stop at the trailing end.
        const bool horizontal = slider->orientation == Qt::Horizontal;
        const QRect grooveRect = subControlRect(CC_Slider, slider, SC_SliderGroove, widget);
        const QRect handleRect = subControlRect(CC_Slider, slider, SC_SliderHandle, widget);
        const qreal halfHit = (horizontal ? handleRect.width() : handleRect.height()) / 2.0;
        const QRectF track = centeredTrack(grooveRect, slider->orientation, Meo::DesignTokens::sliderTrackHeightXS())
            .adjusted(horizontal ? halfHit - Meo::DesignTokens::sliderTrackCornerRadiusXS() : 0,
                      horizontal ? 0 : halfHit - Meo::DesignTokens::sliderTrackCornerRadiusXS(),
                      horizontal ? Meo::DesignTokens::sliderTrackCornerRadiusXS() - halfHit : 0,
                      horizontal ? 0 : Meo::DesignTokens::sliderTrackCornerRadiusXS() - halfHit);
        const qreal lo = horizontal ? track.left() : track.top();
        const qreal hi = horizontal ? track.right() : track.bottom();
        const QPointF handleCenter = QRectF(handleRect).center();
        const qreal center = qBound(lo, horizontal ? handleCenter.x() : handleCenter.y(), hi);
        // Qt maps the minimum to the origin unless upsideDown; the active
        // (filled) side is always the minimum side.
        const bool activeAtOrigin = !slider->upsideDown;

        const QColor surface = option->palette.color(group, QPalette::Window);
        const QColor content = option->palette.color(group, QPalette::WindowText);
        const QColor primary = primaryColor(option->palette, group);
        const QColor activeColor = enabled ? primary : MeoStyleHelper::blend(surface, content, 0.38);
        const QColor inactiveColor = enabled ? MeoStyleHelper::secondaryContainer(option->palette, group, primary)
                                             : MeoStyleHelper::blend(surface, content, 0.12);

        const qreal before = center - Meo::DesignTokens::sliderThumbGap();
        const qreal after = center + Meo::DesignTokens::sliderThumbGap();
        const qreal stopRadius = Meo::DesignTokens::sliderStopSize() / 2.0;
        const auto dotAt = [&](qreal axis) {
            return horizontal ? QPointF(axis, track.center().y()) : QPointF(track.center().x(), axis);
        };
        const bool ticks = option->subControls.testFlag(SC_SliderTickmarks)
                           && slider->tickPosition != QSlider::NoTicks;
        if (option->subControls.testFlag(SC_SliderGroove)) {
            painter->save(); painter->setRenderHint(QPainter::Antialiasing); painter->setPen(Qt::NoPen);
            const QColor originColor = activeAtOrigin ? activeColor : inactiveColor;
            const QColor farColor = activeAtOrigin ? inactiveColor : activeColor;
            painter->setBrush(originColor);
            painter->drawPath(MeoTrack::segment(track, horizontal, lo, before,
                                                Meo::DesignTokens::sliderTrackCornerRadiusXS(), Meo::DesignTokens::sliderTrackInsideCornerRadius()));
            painter->setBrush(farColor);
            painter->drawPath(MeoTrack::segment(track, horizontal, after, hi,
                                                Meo::DesignTokens::sliderTrackInsideCornerRadius(), Meo::DesignTokens::sliderTrackCornerRadiusXS()));
            if (slider->tickPosition == QSlider::NoTicks) {
                // Trailing end stop on the remaining (inactive) side.
                const qreal stopAxis = activeAtOrigin ? hi - Meo::DesignTokens::sliderTrackCornerRadiusXS()
                                                      : lo + Meo::DesignTokens::sliderTrackCornerRadiusXS();
                const bool covered = activeAtOrigin ? stopAxis <= after : stopAxis >= before;
                if (!covered) {
                    painter->setBrush(activeColor);
                    painter->drawEllipse(dotAt(stopAxis), stopRadius, stopRadius);
                }
            }
            painter->restore();
        }
        // Stops (tick marks) sit on the track: light on the filled side,
        // primary on the remaining side.
        if (ticks) {
            painter->save(); painter->setRenderHint(QPainter::Antialiasing); painter->setPen(Qt::NoPen);
            {
                const qint64 range = qMax<qint64>(0, qint64(slider->maximum) - slider->minimum);
                qint64 interval = slider->tickInterval > 0 ? slider->tickInterval : qMax(1, slider->singleStep);
                const qreal travel = hi - lo - 2 * Meo::DesignTokens::sliderTrackCornerRadiusXS();
                const int maximumTicks = qMax(1, int(travel / Meo::DesignTokens::space8()));
                interval = qMax(interval, (range + maximumTicks - 1) / maximumTicks);
                for (qint64 value = slider->minimum; value <= slider->maximum && interval > 0; value += interval) {
                    const int pos = sliderPositionFromValue(slider->minimum, slider->maximum, int(value),
                                                            qMax(0, int(travel)), slider->upsideDown);
                    const qreal axis = lo + Meo::DesignTokens::sliderTrackCornerRadiusXS() + pos;
                    if (qAbs(axis - center) < Meo::DesignTokens::sliderThumbGap() + stopRadius) continue;
                    const bool onOriginSide = axis < center;
                    painter->setBrush(onOriginSide == activeAtOrigin ? inactiveColor : activeColor);
                    painter->drawEllipse(dotAt(axis), stopRadius, stopRadius);
                }
            }
            painter->restore();
        }

        if (option->subControls.testFlag(SC_SliderHandle)) {
            const qreal response = animatedValue(widget, QStringLiteral("slider.response"), enabled && pressed ? 1.0 : 0.0, true);
            const qreal focusAmount = animatedValue(widget, QStringLiteral("slider.focus"), enabled && focus ? 1.0 : 0.0);
            const qreal barWidth = Meo::DesignTokens::sliderThumbWidth()
                - (Meo::DesignTokens::sliderThumbWidth() - Meo::DesignTokens::sliderThumbPressedWidth()) * response;
            const qreal barLength = qMin<qreal>(Meo::DesignTokens::sliderThumbHeightXS(),
                                                horizontal ? slider->rect.height() : slider->rect.width());
            const QRectF thumb = horizontal
                ? QRectF(center - barWidth / 2.0, track.center().y() - barLength / 2.0, barWidth, barLength)
                : QRectF(track.center().x() - barLength / 2.0, center - barWidth / 2.0, barLength, barWidth);
            MeoStyleHelper::drawRoundedSurface(painter, thumb, barWidth / 2.0, activeColor);
            if (focusAmount > 0) {
                painter->save(); painter->setOpacity(painter->opacity() * focusAmount);
                MeoStyleHelper::drawFocusRing(painter, thumb.adjusted(-3.0, -3.0, 3.0, 3.0),
                                               barWidth / 2.0 + 3.0, primary);
                painter->restore();
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
        if (option->subControls.testFlag(SC_ScrollBarGroove) && !grooveRect.isEmpty()) {
            const QRectF track = centeredTrack(grooveRect, scrollBar->orientation,
                                                Meo::DesignTokens::space4());
            // MeoScrollBar track: outlineVariant at 35%.
            QColor groove = MeoStyleHelper::outlineVariant(option->palette, group);
            groove.setAlphaF(0.35);
            MeoStyleHelper::drawRoundedSurface(painter, track, Meo::DesignTokens::space2(), groove);
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

        if (option->subControls.testFlag(SC_ScrollBarSlider) && !sliderRect.isEmpty()) {
            const bool sliderActive = option->activeSubControls.testFlag(SC_ScrollBarSlider);
            // MeoScrollBar: outline at rest, onSurfaceVariant on hover,
            // onSurface while dragged.
            QColor thumb = pressed && sliderActive ? option->palette.color(group, QPalette::WindowText)
                         : (sliderActive || hover) ? MeoStyleHelper::onSurfaceVariant(option->palette, group)
                                                   : MeoStyleHelper::outline(option->palette, group);
            if (!enabled) thumb.setAlphaF(0.38);
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
