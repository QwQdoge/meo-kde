#pragma once

#include <QtWidgets/QStyleOptionHeader>
#include <meodesigntokens.h>

namespace MeoHeader {
inline int iconExtent() { return qRound(Meo::DesignTokens::iconSizeS()); }
inline int gap() { return qRound(Meo::DesignTokens::space8()); }
inline int inset() { return qRound(Meo::DesignTokens::space12()); }
inline QRect labelRect(const QStyleOptionHeader &header)
{
    QRect logical = header.rect.adjusted(inset(), qRound(Meo::DesignTokens::space4()),
                                          -inset(), -qRound(Meo::DesignTokens::space4()));
    if (header.sortIndicator != QStyleOptionHeader::None) logical.adjust(0, 0, -iconExtent() - gap(), 0);
    return QStyle::visualRect(header.direction, header.rect, logical);
}
inline QRect arrowRect(const QStyleOptionHeader &header)
{
    if (header.sortIndicator == QStyleOptionHeader::None) return {};
    const int extent = qMin(iconExtent(), qMax(0, header.rect.height()));
    const QRect logical(header.rect.right() - inset() - extent + 1,
                        header.rect.center().y() - extent / 2, extent, extent);
    return QStyle::visualRect(header.direction, header.rect, logical);
}
inline QSize sizeHint(const QStyleOptionHeader &header)
{
    const QSize text = header.fontMetrics.size(Qt::TextSingleLine, header.text);
    const int icon = header.icon.isNull() ? 0 : iconExtent();
    const int arrow = header.sortIndicator == QStyleOptionHeader::None ? 0 : iconExtent() + gap();
    return QSize(text.width() + icon + (icon && !header.text.isEmpty() ? gap() : 0) + arrow + 2 * inset(),
                 qMax(qRound(Meo::DesignTokens::controlHeight()), qMax(text.height(), icon) + 2 * qRound(Meo::DesignTokens::space4())));
}
} // namespace MeoHeader
