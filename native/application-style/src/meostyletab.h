#pragma once

#include <QtGui/QTransform>
#include <QtWidgets/QStyleOptionTab>
#include <QtWidgets/QTabBar>
#include <meodesigntokens.h>

// One horizontal coordinate system for painting, close-button placement and
// content reservation. Vertical tabs map it into the actual widget rectangle.
namespace MeoTab {
inline bool vertical(QTabBar::Shape shape)
{
    return shape == QTabBar::RoundedWest || shape == QTabBar::TriangularWest
        || shape == QTabBar::RoundedEast || shape == QTabBar::TriangularEast;
}
inline bool west(QTabBar::Shape shape)
{
    return shape == QTabBar::RoundedWest || shape == QTabBar::TriangularWest;
}
struct Layout {
    QRect bounds;
    QRect content;
    QRect leftButton;
    QRect rightButton;
    QTransform transform;
    QRect physical(const QRect &rect) const { return rect.isEmpty() ? QRect() : transform.mapRect(QRectF(rect)).toAlignedRect(); }
};
inline Layout layout(const QStyleOptionTab &tab)
{
    Layout result;
    const bool rotated = vertical(tab.shape);
    result.bounds = QRect(QPoint(), rotated ? tab.rect.size().transposed() : tab.rect.size());
    if (rotated) {
        result.transform.translate(west(tab.shape) ? tab.rect.left() : tab.rect.right() + 1,
                                   west(tab.shape) ? tab.rect.bottom() + 1 : tab.rect.top());
        result.transform.rotate(west(tab.shape) ? -90 : 90);
    } else result.transform.translate(tab.rect.left(), tab.rect.top());
    const int inset = qRound(Meo::DesignTokens::space12());
    const int gap = qRound(Meo::DesignTokens::space8());
    result.content = result.bounds.adjusted(inset, qRound(Meo::DesignTokens::space4()),
                                           -inset, -qRound(Meo::DesignTokens::space4()));
    auto reserve = [&](QSize size, bool leading) {
        if (size.isEmpty()) return QRect();
        if (rotated) size.transpose();
        const QRect logical(leading ? result.content.left() : result.content.right() - size.width() + 1,
                            result.bounds.center().y() - size.height() / 2, size.width(), size.height());
        if (leading) result.content.adjust(size.width() + gap, 0, 0, 0);
        else result.content.adjust(0, 0, -size.width() - gap, 0);
        return QStyle::visualRect(tab.direction, result.bounds, logical);
    };
    result.leftButton = reserve(tab.leftButtonSize, true);
    result.rightButton = reserve(tab.rightButtonSize, false);
    result.content = QStyle::visualRect(tab.direction, result.bounds, result.content);
    return result;
}
} // namespace MeoTab
