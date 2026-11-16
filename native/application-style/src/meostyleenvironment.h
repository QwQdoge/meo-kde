#pragma once

#include <QtCore/QHash>
#include <QtCore/QString>
#include <QtGui/QColor>
#include <QtGui/QPalette>

// The Meo desktop settings MeoStyle follows at runtime:
// - kdeglobals [MeoMaterial]: the exact Material roles meo-dynamic-colors
//   generates for MeoUI, so KDE applications paint with the same colours;
// - meo-shellrc [Appearance] CornerScale: the user's corner roundness, which
//   MeoUI applies through MeoTheme.cornerScale.
// Both files are watched; open widgets repaint when either changes.
namespace MeoStyleEnvironment {

// A Material role for this palette, or an invalid colour when the stored
// roles do not describe it (another scheme, an application palette, or the
// disabled group). Callers then derive the role from the palette instead.
QColor role(const QString &name, const QPalette &palette, QPalette::ColorGroup group);

// 0.0-1.5, 1.0 when unset; mirrors ShellAppearance::cornerScale.
qreal cornerScale();

} // namespace MeoStyleEnvironment
