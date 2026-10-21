#include "wallpapercontrast.h"

#include "dynamiccolorsource.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QFileInfo>
#include <QUrl>

#include <algorithm>
#include <cmath>

namespace {
constexpr int kThumbnailWidth = 320;
constexpr int kMaxSamplesPerAxis = 48;

qreal linearChannel(int value)
{
    const qreal c = value / 255.0;
    return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4);
}

QString localImagePath(const QString &configured)
{
    if (configured.isEmpty()) {
        return {};
    }
    const QUrl url(configured);
    const QString path = url.isLocalFile() ? url.toLocalFile()
                                           : (url.scheme().isEmpty() ? configured : QString());
    return QFileInfo(path).isFile() ? path : QString();
}
}

WallpaperContrast::WallpaperContrast(QObject *parent)
    : QObject(parent)
    , m_desktopWatcher(KConfigWatcher::create(
          KSharedConfig::openConfig(DynamicColorSource::plasmaAppletConfigNames().first())))
    , m_lockWatcher(KConfigWatcher::create(
          KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"))))
{
    connect(m_desktopWatcher.data(), &KConfigWatcher::configChanged, this, [this]() {
        invalidate();
    });
    connect(m_lockWatcher.data(), &KConfigWatcher::configChanged, this, [this]() {
        invalidate();
    });
    connect(&m_fileWatcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        invalidate();
    });
}

QString WallpaperContrast::desktopWallpaperPath() const
{
    return DynamicColorSource::configuredWallpaperPath();
}

QString WallpaperContrast::lockScreenWallpaperPath() const
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
    const KConfigGroup greeter(config, QStringLiteral("Greeter"));
    const KConfigGroup wallpaper(&greeter, QStringLiteral("Wallpaper"));
    const KConfigGroup plugin(&wallpaper, QStringLiteral("org.kde.image"));
    const KConfigGroup group(&plugin, QStringLiteral("General"));
    const QString configured = localImagePath(group.readEntry("Image", QString()));
    return configured.isEmpty() ? desktopWallpaperPath() : configured;
}

void WallpaperContrast::invalidate()
{
    m_cachedPath.clear();
    m_cachedStamp = -1;
    m_thumbnail = QImage();
    m_regionCache.clear();
    Q_EMIT changed();
}

const QImage &WallpaperContrast::thumbnail(const QString &path)
{
    const QFileInfo info(path);
    const qint64 stamp = info.exists() ? info.lastModified().toMSecsSinceEpoch() : -1;
    if (path != m_cachedPath || stamp != m_cachedStamp) {
        m_cachedPath = path;
        m_cachedStamp = stamp;
        m_regionCache.clear();
        m_thumbnail = QImage();
        if (!m_fileWatcher.files().isEmpty()) {
            m_fileWatcher.removePaths(m_fileWatcher.files());
        }
        QImage image(path);
        if (!image.isNull()) {
            m_thumbnail = image.width() > kThumbnailWidth
                ? image.scaledToWidth(kThumbnailWidth, Qt::SmoothTransformation)
                : image;
            m_thumbnail = m_thumbnail.convertToFormat(QImage::Format_RGB32);
            m_fileWatcher.addPath(path);
        }
    }
    return m_thumbnail;
}

qreal WallpaperContrast::regionLuminance(const QImage &image, const QRectF &region,
                                         const QSizeF &screenSize)
{
    if (image.isNull() || screenSize.width() <= 0 || screenSize.height() <= 0
        || region.width() <= 0 || region.height() <= 0) {
        return -1;
    }
    // Fill + preserve aspect: the image is scaled until it covers the screen
    // and the overflow is cropped equally on both sides.
    const qreal imageAspect = qreal(image.width()) / image.height();
    const qreal screenAspect = screenSize.width() / screenSize.height();
    qreal visibleW = 1.0;
    qreal visibleH = 1.0;
    if (imageAspect > screenAspect) {
        visibleW = screenAspect / imageAspect;
    } else {
        visibleH = imageAspect / screenAspect;
    }
    const qreal offsetX = (1.0 - visibleW) / 2.0;
    const qreal offsetY = (1.0 - visibleH) / 2.0;

    const QRectF bounded = region.intersected(QRectF(QPointF(0, 0), screenSize));
    if (bounded.isEmpty()) {
        return -1;
    }
    const qreal u0 = offsetX + bounded.left() / screenSize.width() * visibleW;
    const qreal u1 = offsetX + bounded.right() / screenSize.width() * visibleW;
    const qreal v0 = offsetY + bounded.top() / screenSize.height() * visibleH;
    const qreal v1 = offsetY + bounded.bottom() / screenSize.height() * visibleH;

    const int x0 = std::clamp(int(std::floor(u0 * image.width())), 0, image.width() - 1);
    const int x1 = std::clamp(int(std::ceil(u1 * image.width())), x0 + 1, image.width());
    const int y0 = std::clamp(int(std::floor(v0 * image.height())), 0, image.height() - 1);
    const int y1 = std::clamp(int(std::ceil(v1 * image.height())), y0 + 1, image.height());
    const int stepX = std::max(1, (x1 - x0) / kMaxSamplesPerAxis);
    const int stepY = std::max(1, (y1 - y0) / kMaxSamplesPerAxis);

    qreal sum = 0;
    int count = 0;
    for (int y = y0; y < y1; y += stepY) {
        const QRgb *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = x0; x < x1; x += stepX) {
            const QRgb px = line[x];
            sum += 0.2126 * linearChannel(qRed(px)) + 0.7152 * linearChannel(qGreen(px))
                + 0.0722 * linearChannel(qBlue(px));
            ++count;
        }
    }
    return count > 0 ? sum / count : -1;
}

qreal WallpaperContrast::luminance(qreal x, qreal y, qreal width, qreal height,
                                   qreal screenWidth, qreal screenHeight,
                                   const QString &imagePath)
{
    const QString path = imagePath.isEmpty() ? desktopWallpaperPath() : localImagePath(imagePath);
    if (path.isEmpty()) {
        return -1;
    }
    const QImage &image = thumbnail(path);
    if (image.isNull()) {
        return -1;
    }
    const QString key = QStringLiteral("%1,%2,%3,%4|%5x%6")
                            .arg(qRound(x)).arg(qRound(y)).arg(qRound(width)).arg(qRound(height))
                            .arg(qRound(screenWidth)).arg(qRound(screenHeight));
    const auto cached = m_regionCache.constFind(key);
    if (cached != m_regionCache.constEnd()) {
        return cached.value();
    }
    const qreal value = regionLuminance(image, QRectF(x, y, width, height),
                                        QSizeF(screenWidth, screenHeight));
    m_regionCache.insert(key, value);
    return value;
}

bool WallpaperContrast::prefersDarkForeground(qreal x, qreal y, qreal width, qreal height,
                                              qreal screenWidth, qreal screenHeight,
                                              bool fallback, const QString &imagePath)
{
    const qreal value = luminance(x, y, width, height, screenWidth, screenHeight, imagePath);
    return value < 0 ? fallback : value > kDarkForegroundThreshold;
}
