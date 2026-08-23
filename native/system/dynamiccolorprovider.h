#pragma once

#include <QColor>
#include <QObject>
#include <QVariantMap>

class DynamicColorProvider final : public QObject
{
    Q_OBJECT

public:
    explicit DynamicColorProvider(QObject *parent = nullptr);

    // QML bridge for the same Material Color Utilities scheme used by the KDE
    // .colors generator. This keeps shell controls and KDE widgets in one
    // color system rather than deriving roles with QML RGB interpolation.
    Q_INVOKABLE QVariantMap schemeFor(const QColor &seed, bool dark) const;
    // Diagnostic source metadata written atomically with the active Meo
    // scheme.  It lets every MeoUI client explain whether the shared HCT table
    // came from KDE's accent, the desktop wallpaper, or an explicit color.
    Q_INVOKABLE QString sourceId() const;
};
