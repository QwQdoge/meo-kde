#pragma once

#include <QtCore/QRectF>
#include <QtGui/QColor>
#include <QtGui/QPalette>

class QPainter;

namespace MeoStyleHelper {

QColor blend(const QColor &base, const QColor &overlay, qreal opacity);
QColor stateLayer(const QPalette &palette, QPalette::ColorGroup group, bool hover, bool pressed);
QColor stateLayer(const QPalette &palette, QPalette::ColorGroup group,
                  QPalette::ColorRole surfaceRole, QPalette::ColorRole contentRole,
                  bool hover, bool pressed, bool focused = false);
void drawRoundedSurface(QPainter *painter, const QRectF &rect, qreal radius,
                        const QColor &fill, const QColor &outline = {}, qreal outlineWidth = 1.0);

// Material roles that QPalette has no slot for. They are derived from the live
// palette (never cached) and calibrated against the Meo light/dark schemes'
// [MeoMaterial] values, so KDE's computed Mid/Midlight greys are not used.
QColor onSurfaceVariant(const QPalette &palette, QPalette::ColorGroup group);
QColor outline(const QPalette &palette, QPalette::ColorGroup group);
QColor outlineVariant(const QPalette &palette, QPalette::ColorGroup group);
QColor secondaryContainer(const QPalette &palette, QPalette::ColorGroup group, const QColor &primary);
void drawFocusRing(QPainter *painter, const QRectF &rect, qreal radius, const QColor &color);
void drawCheckMark(QPainter *painter, const QRectF &rect, const QColor &color);
void drawChevron(QPainter *painter, const QRectF &rect, const QColor &color, Qt::ArrowType direction);

} // namespace MeoStyleHelper
