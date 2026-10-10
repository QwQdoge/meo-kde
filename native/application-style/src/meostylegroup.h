#pragma once

#include <QtWidgets/QStyleOptionGroupBox>
#include <meodesigntokens.h>

namespace MeoGroup {
inline int padding() { return qRound(Meo::DesignTokens::space16()); }
inline int gap() { return qRound(Meo::DesignTokens::space12()); }
inline bool checkable(const QStyleOptionGroupBox &group) { return group.subControls.testFlag(QStyle::SC_GroupBoxCheckBox); }
inline bool hasTitle(const QStyleOptionGroupBox &group) { return checkable(group) || !group.text.isEmpty(); }
inline int titleHeight(const QStyleOptionGroupBox &group)
{
    return hasTitle(group) ? qMax(qRound(Meo::DesignTokens::space24()), group.fontMetrics.height()) : 0;
}
struct Layout { QRect frame; QRect contents; QRect label; QRect check; };
inline Layout layout(const QStyleOptionGroupBox &group)
{
    Layout result;
    result.frame = group.rect;
    const int top = padding() + titleHeight(group) + (hasTitle(group) ? gap() : 0);
    result.contents = QRect(group.rect.left() + padding(), group.rect.top() + top,
        qMax(0, group.rect.width() - 2 * padding()), qMax(0, group.rect.height() - top - padding()));
    if (!hasTitle(group)) return result;
    const int extent = qRound(Meo::DesignTokens::iconSizeS());
    const int checkWidth = checkable(group) ? extent + (group.text.isEmpty() ? 0 : qRound(Meo::DesignTokens::space8())) : 0;
    const int textWidth = group.fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, group.text).width();
    const QRect available(group.rect.left() + padding(), group.rect.top() + padding(),
                          qMax(0, group.rect.width() - 2 * padding()), titleHeight(group));
    const QRect title = QStyle::alignedRect(Qt::LeftToRight, group.textAlignment | Qt::AlignVCenter,
        QSize(qMin(available.width(), textWidth + checkWidth), available.height()), available);
    if (checkable(group)) {
        result.check = QStyle::visualRect(group.direction, group.rect,
            QRect(title.left(), title.center().y() - extent / 2, extent, extent));
    }
    if (!group.text.isEmpty()) {
        result.label = QStyle::visualRect(group.direction, group.rect,
            QRect(title.left() + checkWidth, title.top(), qMax(0, title.width() - checkWidth), title.height()));
    }
    return result;
}
inline QSize sizeHint(const QStyleOptionGroupBox &group, const QSize &contents)
{
    const int check = checkable(group) ? qRound(Meo::DesignTokens::iconSizeS() + Meo::DesignTokens::space8()) : 0;
    const int titleWidth = group.fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, group.text).width() + check;
    return QSize(qMax(contents.width(), titleWidth) + 2 * padding(),
        qMax(contents.height(), titleHeight(group)) + 2 * padding() + (hasTitle(group) ? gap() : 0));
}
} // namespace MeoGroup
