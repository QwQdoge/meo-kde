#pragma once

#include <QtGui/QTextLayout>
#include <QtWidgets/QStyleOptionViewItem>
#include <meodesigntokens.h>

namespace MeoItem {
inline int inset() { return qRound(Meo::DesignTokens::space12()); }
inline int verticalInset() { return qRound(Meo::DesignTokens::space4()); }
inline int gap() { return qRound(Meo::DesignTokens::space8()); }
inline int checkExtent() { return qRound(Meo::DesignTokens::iconSizeS()); }
inline bool hasCheck(const QStyleOptionViewItem &item) { return item.features.testFlag(QStyleOptionViewItem::HasCheckIndicator); }
inline QSize decorationSize(const QStyleOptionViewItem &item)
{
    if (!item.features.testFlag(QStyleOptionViewItem::HasDecoration)) return QSize(0, 0);
    return item.decorationSize.isValid() ? item.decorationSize : QSize(checkExtent(), checkExtent());
}
inline QString text(const QStyleOptionViewItem &item)
{
    QString result = item.features.testFlag(QStyleOptionViewItem::HasDisplay) ? item.text : QString();
    result.replace(QLatin1Char('\n'), QChar::LineSeparator);
    return result;
}
inline void prepareText(QTextLayout &layout, const QStyleOptionViewItem &item, int width)
{
    QTextOption option;
    option.setTextDirection(item.direction);
    option.setAlignment(QStyle::visualAlignment(item.direction, item.displayAlignment) & Qt::AlignHorizontal_Mask);
    option.setWrapMode(item.features.testFlag(QStyleOptionViewItem::WrapText)
        ? QTextOption::WrapAtWordBoundaryOrAnywhere : QTextOption::NoWrap);
    layout.setTextOption(option);
    layout.beginLayout();
    qreal y = 0;
    while (true) {
        QTextLine line = layout.createLine();
        if (!line.isValid()) break;
        line.setLineWidth(qMax(1, width));
        line.setPosition(QPointF(0, y));
        y += line.height();
    }
    layout.endLayout();
}
struct Layout { QRect check; QRect decoration; QRect text; };
inline Layout layout(const QStyleOptionViewItem &item)
{
    Layout result;
    QRect remaining = item.rect.adjusted(inset(), verticalInset(), -inset(), -verticalInset());
    if (remaining.isEmpty()) return result;
    if (hasCheck(item)) {
        const int extent = qMin(checkExtent(), qMin(remaining.width(), remaining.height()));
        result.check = QRect(remaining.left(), remaining.center().y() - extent / 2, extent, extent);
        remaining.adjust(extent + gap(), 0, 0, 0);
    }
    const QSize icon = decorationSize(item).boundedTo(remaining.size().expandedTo(QSize(0, 0)));
    if (!icon.isEmpty()) {
        QRect area = remaining;
        switch (item.decorationPosition) {
        case QStyleOptionViewItem::Top:
            area.setHeight(icon.height()); remaining.adjust(0, icon.height() + gap(), 0, 0); break;
        case QStyleOptionViewItem::Bottom:
            area.setTop(area.bottom() - icon.height() + 1); remaining.adjust(0, 0, 0, -icon.height() - gap()); break;
        case QStyleOptionViewItem::Right:
            area.setLeft(area.right() - icon.width() + 1); remaining.adjust(0, 0, -icon.width() - gap(), 0); break;
        case QStyleOptionViewItem::Left:
        default:
            area.setWidth(icon.width()); remaining.adjust(icon.width() + gap(), 0, 0, 0); break;
        }
        result.decoration = QStyle::alignedRect(Qt::LeftToRight, item.decorationAlignment, icon, area);
    }
    result.text = remaining.isEmpty() ? QRect() : remaining;
    result.check = QStyle::visualRect(item.direction, item.rect, result.check);
    result.decoration = QStyle::visualRect(item.direction, item.rect, result.decoration);
    result.text = QStyle::visualRect(item.direction, item.rect, result.text);
    return result;
}
inline QSize sizeHint(const QStyleOptionViewItem &item)
{
    const QSize icon = decorationSize(item);
    const bool stacked = item.decorationPosition == QStyleOptionViewItem::Top || item.decorationPosition == QStyleOptionViewItem::Bottom;
    const int checkWidth = hasCheck(item) ? checkExtent() + gap() : 0;
    int available = item.rect.width() - 2 * inset() - checkWidth;
    if (!stacked && !icon.isEmpty()) available -= icon.width() + gap();
    if (!item.features.testFlag(QStyleOptionViewItem::WrapText) || available <= 0) available = 1000000;
    QTextLayout lines(text(item), item.font);
    prepareText(lines, item, available);
    int width = 0;
    for (int i = 0; i < lines.lineCount(); ++i) width = qMax(width, qCeil(lines.lineAt(i).naturalTextWidth()));
    int height = qCeil(lines.boundingRect().height());
    if (!icon.isEmpty()) {
        if (stacked) { width = qMax(width, icon.width()); height += icon.height() + gap(); }
        else { width += icon.width() + gap(); height = qMax(height, icon.height()); }
    }
    if (hasCheck(item)) height = qMax(height, checkExtent());
    return QSize(width + checkWidth + 2 * inset(), qMax(qRound(Meo::DesignTokens::controlHeight()), height + 2 * verticalInset()));
}
} // namespace MeoItem
