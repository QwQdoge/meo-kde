#include "dynamiccolorsource.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QImageReader>
#include <QUrl>

#include <algorithm>

namespace {
constexpr auto accentMode = "accent";
constexpr auto wallpaperMode = "wallpaper";
constexpr auto manualMode = "manual";
constexpr auto defaultSeed = 0x6750a4;

QString normalizedMode(const QString &mode)
{
    return mode.trimmed().toLower();
}

QString localPath(const QString &configured, QString *error)
{
    const QString candidate = configured.trimmed();
    if (candidate.isEmpty()) {
        if (error) {
            *error = QStringLiteral("The wallpaper configuration has no image path.");
        }
        return {};
    }

    const QUrl url(candidate);
    if (url.isValid() && !url.scheme().isEmpty()) {
        if (!url.isLocalFile()) {
            if (error) {
                *error = QStringLiteral("The configured wallpaper is not a local image file.");
            }
            return {};
        }
        return url.toLocalFile();
    }

    return candidate;
}

struct Bucket
{
    quint64 weight = 0;
    quint64 red = 0;
    quint64 green = 0;
    quint64 blue = 0;
};
}

QStringList DynamicColorSource::supportedModeIds()
{
    return {QString::fromLatin1(accentMode), QString::fromLatin1(wallpaperMode),
            QString::fromLatin1(manualMode)};
}

bool DynamicColorSource::isSupportedMode(const QString &mode)
{
    return supportedModeIds().contains(normalizedMode(mode));
}

QString DynamicColorSource::configuredMode()
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("meo-dynamic-colorsrc"));
    const QString mode = normalizedMode(
        KConfigGroup(config, QStringLiteral("Source")).readEntry("Mode", QString::fromLatin1(accentMode)));
    return isSupportedMode(mode) ? mode : QString::fromLatin1(accentMode);
}

QColor DynamicColorSource::configuredManualColor()
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("meo-dynamic-colorsrc"));
    return QColor(KConfigGroup(config, QStringLiteral("Source")).readEntry("ManualColor", QString()));
}

bool DynamicColorSource::persist(const QString &mode, const QColor &manualColor, QString *error)
{
    const QString normalized = normalizedMode(mode);
    if (!isSupportedMode(normalized)) {
        if (error) {
            *error = QStringLiteral("Unsupported dynamic color source: %1").arg(mode);
        }
        return false;
    }
    if (normalized == QLatin1String(manualMode) && !manualColor.isValid()) {
        if (error) {
            *error = QStringLiteral("Manual dynamic color needs a valid #RRGGBB color.");
        }
        return false;
    }

    const auto config = KSharedConfig::openConfig(QStringLiteral("meo-dynamic-colorsrc"));
    KConfigGroup source(config, QStringLiteral("Source"));
    source.writeEntry("Mode", normalized);
    if (manualColor.isValid()) {
        source.writeEntry("ManualColor", manualColor.name(QColor::HexRgb));
    }
    if (!config->sync()) {
        if (error) {
            *error = QStringLiteral("Cannot save the dynamic color source preference.");
        }
        return false;
    }
    return true;
}

QString DynamicColorSource::configuredWallpaperPath(QString *error)
{
    if (error) {
        error->clear();
    }
    const auto config = KSharedConfig::openConfig(QStringLiteral("plasma-org.kde.plasma.desktop-appletsrc"));
    const KConfigGroup containments(config, QStringLiteral("Containments"));
    QStringList containmentIds = containments.groupList();
    std::sort(containmentIds.begin(), containmentIds.end());

    for (const QString &id : containmentIds) {
        const KConfigGroup containment(&containments, id);
        if (containment.readEntry("wallpaperplugin", QString()) != QLatin1String("org.kde.image")) {
            continue;
        }
        // Plasma's KConfig group is intentionally absolute beneath a
        // containment (`[/Wallpaper/org.kde.image/General]`); omitting the
        // leading slash would read a different, non-Plasma group.
        const KConfigGroup wallpaperGroup(&containment,
                                           QStringLiteral("/Wallpaper/org.kde.image/General"));
        const QString image = wallpaperGroup.readEntry("Image", QString());
        QString pathError;
        const QString path = localPath(image, &pathError);
        if (!path.isEmpty()) {
            if (QFileInfo(path).isFile()) {
                return path;
            }
            pathError = QStringLiteral("The configured wallpaper image no longer exists.");
        }
        if (error && error->isEmpty() && !pathError.isEmpty()) {
            *error = pathError;
        }
    }

    if (error && error->isEmpty()) {
        *error = QStringLiteral("No local image wallpaper is configured for this Plasma desktop.");
    }
    return {};
}

QColor DynamicColorSource::seedFromWallpaper(const QString &path, QString *error)
{
    const QFileInfo file(path);
    if (!file.isFile()) {
        if (error) {
            *error = QStringLiteral("Wallpaper image is unavailable: %1").arg(path);
        }
        return {};
    }

    QImageReader reader(file.absoluteFilePath());
    reader.setAutoTransform(true);
    const QSize originalSize = reader.size();
    if (originalSize.isValid()) {
        reader.setScaledSize(originalSize.scaled(128, 128, Qt::KeepAspectRatio));
    }
    const QImage image = reader.read().convertToFormat(QImage::Format_RGBA8888);
    if (image.isNull()) {
        if (error) {
            *error = QStringLiteral("Cannot read wallpaper image: %1").arg(reader.errorString());
        }
        return {};
    }

    // The sample is intentionally small and never follows a directory tree.
    // Quantized buckets keep detailed photographic noise from becoming a
    // random seed while preferring colors with usable chroma and exposure.
    QHash<int, Bucket> buckets;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = image.constScanLine(y);
        for (int x = 0; x < image.width(); ++x) {
            const auto *pixel = line + x * 4;
            const int red = pixel[0];
            const int green = pixel[1];
            const int blue = pixel[2];
            const int alpha = pixel[3];
            if (alpha < 64) {
                continue;
            }

            const int high = std::max({red, green, blue});
            const int low = std::min({red, green, blue});
            const qreal chroma = static_cast<qreal>(high - low) / 255.0;
            const qreal exposure = static_cast<qreal>(high + low) / 510.0;
            const qreal exposureWeight = 1.0 - 0.70 * qAbs(exposure - 0.5) * 2.0;
            const quint64 weight = std::max<quint64>(1,
                static_cast<quint64>((0.20 + chroma * 1.80)
                                      * std::max(0.20, exposureWeight)
                                      * static_cast<qreal>(alpha) / 255.0 * 1000.0));
            const int key = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4);
            auto &bucket = buckets[key];
            bucket.weight += weight;
            bucket.red += weight * red;
            bucket.green += weight * green;
            bucket.blue += weight * blue;
        }
    }

    if (buckets.isEmpty()) {
        if (error) {
            *error = QStringLiteral("The wallpaper does not contain visible pixels to sample.");
        }
        return {};
    }

    const Bucket *winner = nullptr;
    for (auto it = buckets.cbegin(); it != buckets.cend(); ++it) {
        if (!winner || it->weight > winner->weight) {
            winner = &it.value();
        }
    }
    if (!winner || winner->weight == 0) {
        if (error) {
            *error = QStringLiteral("The wallpaper color sample is invalid.");
        }
        return {};
    }
    return QColor::fromRgb(static_cast<int>(winner->red / winner->weight),
                            static_cast<int>(winner->green / winner->weight),
                            static_cast<int>(winner->blue / winner->weight));
}

bool DynamicColorSource::resolve(const QString &requestedMode, const QColor &kdeAccent,
                                 const QColor &manualColor, const QString &wallpaperOverride,
                                 QColor *seed, QString *resolvedMode,
                                 QString *resolvedWallpaperPath, QString *error)
{
    if (!seed || !resolvedMode) {
        if (error) {
            *error = QStringLiteral("Dynamic color source needs output storage.");
        }
        return false;
    }

    const QString mode = requestedMode.trimmed().isEmpty()
        ? configuredMode() : normalizedMode(requestedMode);
    if (!isSupportedMode(mode)) {
        if (error) {
            *error = QStringLiteral("Dynamic color source must be accent, wallpaper, or manual.");
        }
        return false;
    }

    if (mode == QLatin1String(accentMode)) {
        *seed = kdeAccent.isValid() ? kdeAccent : QColor::fromRgb(defaultSeed);
    } else if (mode == QLatin1String(manualMode)) {
        const QColor chosen = manualColor.isValid() ? manualColor : configuredManualColor();
        if (!chosen.isValid()) {
            if (error) {
                *error = QStringLiteral("Choose a valid manual dynamic color first.");
            }
            return false;
        }
        *seed = chosen;
    } else {
        const QString path = wallpaperOverride.trimmed().isEmpty()
            ? configuredWallpaperPath(error) : localPath(wallpaperOverride, error);
        if (path.isEmpty()) {
            return false;
        }
        *seed = seedFromWallpaper(path, error);
        if (!seed->isValid()) {
            return false;
        }
        if (resolvedWallpaperPath) {
            *resolvedWallpaperPath = path;
        }
    }

    *resolvedMode = mode;
    return true;
}
