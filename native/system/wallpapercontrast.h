#pragma once

#include <KConfigWatcher>
#include <QFileSystemWatcher>
#include <QHash>
#include <QImage>
#include <QObject>
#include <QRectF>
#include <QSizeF>
#include <QString>

/**
 * Foreground-contrast advice derived from the wallpaper pixels that actually
 * sit behind a shell surface.
 *
 * Only the configured local image wallpaper is read. It is decoded once into a
 * small cached thumbnail and re-read only when the wallpaper path or file
 * changes; region queries are answered from that thumbnail and a per-region
 * cache. Nothing captures the screen and nothing runs per frame. When no local
 * image wallpaper exists the answer is "unknown" and callers must keep their
 * theme-derived foreground rather than guessing.
 */
class WallpaperContrast final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "WallpaperContrast")
    Q_CLASSINFO("QML.Singleton", "true")

public:
    explicit WallpaperContrast(QObject *parent = nullptr);

    // Relative luminance (0..1, WCAG definition) of the wallpaper behind
    // `region`, expressed in the pixel space of a screen of `screenSize`
    // using the same "fill, preserve aspect, crop" mapping as the image
    // wallpaper plugin. Returns -1 when no usable wallpaper is available.
    Q_INVOKABLE qreal luminance(qreal x, qreal y, qreal width, qreal height,
                                qreal screenWidth, qreal screenHeight,
                                const QString &imagePath = QString());
    // True when dark glyphs/text contrast better with that region than white.
    // Falls back to `fallback` when the luminance is unknown.
    Q_INVOKABLE bool prefersDarkForeground(qreal x, qreal y, qreal width, qreal height,
                                           qreal screenWidth, qreal screenHeight,
                                           bool fallback, const QString &imagePath = QString());
    // Wallpaper shown by the screen locker, falling back to the desktop one.
    Q_INVOKABLE QString lockScreenWallpaperPath() const;
    Q_INVOKABLE QString desktopWallpaperPath() const;

    // Region luminance on an already decoded image; exposed for tests.
    static qreal regionLuminance(const QImage &image, const QRectF &region,
                                 const QSizeF &screenSize);
    // Black text wins over white once the luminance crosses this point.
    static constexpr qreal kDarkForegroundThreshold = 0.25;

Q_SIGNALS:
    // The wallpaper changed; consumers should re-query their regions.
    void changed();

private:
    const QImage &thumbnail(const QString &path);
    void invalidate();

    KConfigWatcher::Ptr m_desktopWatcher;
    KConfigWatcher::Ptr m_lockWatcher;
    QFileSystemWatcher m_fileWatcher;
    QString m_cachedPath;
    qint64 m_cachedStamp = -1;
    QImage m_thumbnail;
    QHash<QString, qreal> m_regionCache;
};
