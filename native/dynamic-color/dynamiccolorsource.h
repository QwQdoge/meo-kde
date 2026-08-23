#pragma once

#include <QColor>
#include <QString>
#include <QStringList>

/**
 * Resolves the single seed used by Meo's native Material generator.
 *
 * This intentionally owns only source selection and image sampling.  It never
 * derives a palette itself: the resulting seed always flows through
 * DynamicColors and Material Color Utilities/HCT before it reaches KDE or
 * MeoUI.
 */
class DynamicColorSource final
{
public:
    static QStringList supportedModeIds();
    static bool isSupportedMode(const QString &mode);

    /// Returns the remembered source mode, or the backwards-compatible KDE
    /// accent mode when the user has not made an explicit source choice.
    static QString configuredMode();
    static QColor configuredManualColor();
    static bool persist(const QString &mode, const QColor &manualColor, QString *error = nullptr);

    /// Finds the first local image wallpaper configured for a desktop
    /// containment.  Non-local wallpaper plugins and slideshow descriptors are
    /// intentionally not treated as image files.
    static QString configuredWallpaperPath(QString *error = nullptr);
    /// Samples a bounded image representation and returns one stable seed.
    static QColor seedFromWallpaper(const QString &path, QString *error = nullptr);

    /**
     * Resolves a request into a concrete source id and seed.  Empty
     * `requestedMode` means the persisted choice.  A manual color is used only
     * in manual mode, and `wallpaperOverride` is accepted only in wallpaper
     * mode.  There is deliberately no silent fallback between sources.
     */
    static bool resolve(const QString &requestedMode, const QColor &kdeAccent,
                        const QColor &manualColor, const QString &wallpaperOverride,
                        QColor *seed, QString *resolvedMode,
                        QString *resolvedWallpaperPath = nullptr,
                        QString *error = nullptr);
};
