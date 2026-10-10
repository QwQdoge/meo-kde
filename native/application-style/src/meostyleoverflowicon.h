#pragma once

#include "meostylehelper.h"
#include <QtCore/QPointer>
#include <QtGui/QIconEngine>
#include <QtGui/QPainter>
#include <QtGui/QPixmap>
#include <QtWidgets/QWidget>
#include <meodesigntokens.h>

// Qt's toolbar retains the icon across palette changes. Render against its
// current palette/direction rather than caching a light/dark bitmap.
class MeoOverflowIcon final : public QIconEngine
{
public:
    MeoOverflowIcon(bool vertical, const QWidget *widget, const QPalette &palette, Qt::LayoutDirection direction)
        : m_vertical(vertical), m_widget(const_cast<QWidget *>(widget)), m_palette(palette), m_direction(direction) {}
    QIconEngine *clone() const override { return new MeoOverflowIcon(m_vertical, m_widget, m_palette, m_direction); }
    void paint(QPainter *painter, const QRect &rect, QIcon::Mode mode, QIcon::State) override {
        if (rect.isEmpty()) return;
        const QPalette palette = m_widget ? m_widget->palette() : m_palette;
        const auto direction = m_widget ? m_widget->layoutDirection() : m_direction;
        const QColor color = palette.color(mode == QIcon::Disabled ? QPalette::Disabled : QPalette::Active, QPalette::WindowText);
        const qreal extent = Meo::DesignTokens::iconSizeS();
        const qreal side = qMin(rect.width(), rect.height());
        painter->save();
        painter->translate(QRectF(rect).center().x() - side / 2.0, QRectF(rect).center().y() - side / 2.0);
        painter->scale(side / extent, side / extent);
        const auto arrow = m_vertical ? Qt::DownArrow : direction == Qt::RightToLeft ? Qt::LeftArrow : Qt::RightArrow;
        for (int sign : {-1, 1}) {
            QRectF glyph(0, 0, extent, extent);
            glyph.translate(m_vertical ? 0 : sign * Meo::DesignTokens::space2(), m_vertical ? sign * Meo::DesignTokens::space2() : 0);
            MeoStyleHelper::drawChevron(painter, glyph, color, arrow);
        }
        painter->restore();
    }
    QPixmap pixmap(const QSize &size, QIcon::Mode mode, QIcon::State state) override {
        QPixmap result(size); result.fill(Qt::transparent);
        QPainter painter(&result); paint(&painter, QRect(QPoint(), size), mode, state);
        return result;
    }
private:
    bool m_vertical;
    QPointer<QWidget> m_widget;
    QPalette m_palette;
    Qt::LayoutDirection m_direction;
};
