#include "weathercache.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

#include <cmath>
#include <limits>

namespace
{
constexpr qint64 kMaximumCacheBytes = 64 * 1024;
constexpr qint64 kMaximumCacheAgeSeconds = 6 * 60 * 60;

QString boundedText(const QString &value, qsizetype maximumLength)
{
    QString result = value;
    result.remove(QRegularExpression(QStringLiteral("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F\\u202A-\\u202E\\u2066-\\u2069]")));
    return result.left(maximumLength).trimmed();
}

QString safeIconName(const QString &value)
{
    const QString candidate = boundedText(value, 128);
    static const QRegularExpression validIconName(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+\\-]*$"));
    return validIconName.match(candidate).hasMatch() ? candidate : QStringLiteral("weather-clear");
}
}

WeatherCache::WeatherCache(QObject *parent)
    : QObject(parent)
{
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
        QTimer::singleShot(0, this, &WeatherCache::reload);
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        QTimer::singleShot(0, this, &WeatherCache::reload);
    });

    auto *freshnessTimer = new QTimer(this);
    freshnessTimer->setInterval(60 * 1000);
    connect(freshnessTimer, &QTimer::timeout, this, &WeatherCache::reload);
    freshnessTimer->start();
    reload();
}

bool WeatherCache::available() const { return m_available; }
bool WeatherCache::stale() const { return m_stale; }
QString WeatherCache::temperatureText() const { return m_temperatureText; }
QString WeatherCache::condition() const { return m_condition; }
QString WeatherCache::iconName() const { return m_iconName; }
QString WeatherCache::location() const { return m_location; }
QDateTime WeatherCache::updatedAt() const { return m_updatedAt; }
QString WeatherCache::lastError() const { return m_lastError; }

QString WeatherCache::cachePath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::StateLocation))
            .filePath(QStringLiteral("meo/weather/lockscreen.json"));
}

void WeatherCache::refresh()
{
    reload();
}

void WeatherCache::reload()
{
    const QString path = cachePath();
    updateWatchPaths();
    const QFileInfo info(path);
    if (!info.exists()) {
        clearWeather();
        return;
    }
    if (!info.isFile() || info.size() < 0 || info.size() > kMaximumCacheBytes) {
        clearWeather(tr("Weather cache is unavailable."));
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        clearWeather(tr("Weather cache is unavailable."));
        return;
    }
    const QByteArray bytes = file.read(kMaximumCacheBytes + 1);
    if (bytes.size() > kMaximumCacheBytes) {
        clearWeather(tr("Weather cache is unavailable."));
        return;
    }
    const QJsonDocument document = QJsonDocument::fromJson(bytes);
    if (!document.isObject()) {
        clearWeather(tr("Weather cache is invalid."));
        return;
    }
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("schemaVersion")).toInt() != 1) {
        clearWeather(tr("Weather cache has an unsupported version."));
        return;
    }

    QDateTime updatedAt = QDateTime::fromString(object.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
    if (!updatedAt.isValid()) {
        updatedAt = QDateTime::fromString(object.value(QStringLiteral("updatedAt")).toString(), Qt::ISODate);
    }
    updatedAt = updatedAt.toUTC();
    const double temperature = object.value(QStringLiteral("temperature")).toDouble(std::numeric_limits<double>::quiet_NaN());
    const QString unit = object.value(QStringLiteral("unit")).toString().toUpper();
    const QString condition = boundedText(object.value(QStringLiteral("condition")).toString(), 96);
    if (!updatedAt.isValid() || updatedAt > QDateTime::currentDateTimeUtc().addSecs(5 * 60)
        || !std::isfinite(temperature) || temperature < -100 || temperature > 100
        || (unit != QLatin1String("C") && unit != QLatin1String("F")) || condition.isEmpty()) {
        clearWeather(tr("Weather cache is invalid."));
        return;
    }

    const bool stale = updatedAt.secsTo(QDateTime::currentDateTimeUtc()) > kMaximumCacheAgeSeconds;
    const QString temperatureText = QString::number(temperature, 'f', std::abs(temperature - std::round(temperature)) < 0.05 ? 0 : 1)
            + QChar(0x00B0) + unit;
    const QString location = boundedText(object.value(QStringLiteral("location")).toString(), 64);
    const QString iconName = safeIconName(object.value(QStringLiteral("iconName")).toString());
    const bool available = !stale;
    if (m_available == available && m_stale == stale && m_temperatureText == temperatureText
        && m_condition == condition && m_iconName == iconName && m_location == location
        && m_updatedAt == updatedAt) {
        setError({});
        return;
    }
    m_available = available;
    m_stale = stale;
    m_temperatureText = temperatureText;
    m_condition = condition;
    m_iconName = iconName;
    m_location = location;
    m_updatedAt = updatedAt;
    setError({});
    Q_EMIT weatherChanged();
}

void WeatherCache::updateWatchPaths()
{
    const QFileInfo info(cachePath());
    const QString directory = info.absolutePath();
    if (QFileInfo::exists(directory) && !m_watcher.directories().contains(directory)) {
        m_watcher.addPath(directory);
    }
    if (info.exists() && !m_watcher.files().contains(info.absoluteFilePath())) {
        m_watcher.addPath(info.absoluteFilePath());
    }
}

void WeatherCache::clearWeather(const QString &error)
{
    const bool changed = m_available || m_stale || !m_temperatureText.isEmpty() || !m_condition.isEmpty()
            || !m_iconName.isEmpty() || !m_location.isEmpty() || m_updatedAt.isValid();
    m_available = false;
    m_stale = false;
    m_temperatureText.clear();
    m_condition.clear();
    m_iconName.clear();
    m_location.clear();
    m_updatedAt = {};
    setError(error);
    if (changed) {
        Q_EMIT weatherChanged();
    }
}

void WeatherCache::setError(const QString &error)
{
    if (m_lastError == error) {
        return;
    }
    m_lastError = error;
    Q_EMIT errorChanged();
}
