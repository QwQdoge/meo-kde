#include "weathercache.h"

#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
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
    static const QRegularExpression unsafeTextCharacters(
        QStringLiteral("[\\x{0000}-\\x{0008}\\x{000B}\\x{000C}\\x{000E}-\\x{001F}\\x{007F}\\x{202A}-\\x{202E}\\x{2066}-\\x{2069}]")
    );
    result.remove(unsafeTextCharacters);
    return result.left(maximumLength).trimmed();
}

QString safeIconName(const QString &value)
{
    const QString candidate = boundedText(value, 128);
    static const QRegularExpression validIconName(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+\\-]*$"));
    return validIconName.match(candidate).hasMatch() ? candidate : QStringLiteral("weather-clear");
}

QString iconForCode(int code)
{
    if (code == 0) return QStringLiteral("weather-clear");
    if (code <= 3) return QStringLiteral("weather-partly-cloudy");
    if (code == 45 || code == 48) return QStringLiteral("weather-fog");
    if (code <= 67 || code <= 82) return QStringLiteral("weather-showers");
    if (code <= 86) return QStringLiteral("weather-snow");
    return QStringLiteral("weather-storm");
}

QString localizedConditionForCode(int code)
{
    if (code == 0) return i18nd("meo-desktop", "Clear sky");
    if (code <= 3) return i18nd("meo-desktop", "Partly cloudy");
    if (code == 45 || code == 48) return i18nd("meo-desktop", "Foggy");
    if (code <= 57) return i18nd("meo-desktop", "Drizzle");
    if (code <= 67) return i18nd("meo-desktop", "Rain");
    if (code <= 77) return i18nd("meo-desktop", "Snow");
    if (code <= 82) return i18nd("meo-desktop", "Rain showers");
    if (code <= 86) return i18nd("meo-desktop", "Snow showers");
    if (code <= 99) return i18nd("meo-desktop", "Thunderstorm");
    return i18nd("meo-desktop", "Weather unavailable");
}

bool stableWeatherCode(const QJsonValue &value, int *code)
{
    if (!value.isDouble()) {
        return false;
    }

    const double numericCode = value.toDouble();
    if (!std::isfinite(numericCode)
        || numericCode < std::numeric_limits<int>::min()
        || numericCode > std::numeric_limits<int>::max()
        || std::trunc(numericCode) != numericCode) {
        return false;
    }

    *code = static_cast<int>(numericCode);
    return true;
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
QVariantList WeatherCache::forecast() const { return m_forecast; }
QDateTime WeatherCache::updatedAt() const { return m_updatedAt; }
QString WeatherCache::lastError() const { return m_lastError; }

QString WeatherCache::cachePath()
{
    // StateLocation is application-specific on some Qt platforms.  The
    // refresher and kscreenlocker are separate applications, so use the XDG
    // state root explicitly to give both processes one private, per-user
    // cache.  This is intentionally independent of their application names.
    QString stateHome = qEnvironmentVariable("XDG_STATE_HOME");
    if (stateHome.isEmpty()) {
        stateHome = QDir::home().filePath(QStringLiteral(".local/state"));
    }
    return QDir(stateHome).filePath(QStringLiteral("meo/weather/lockscreen.json"));
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
        clearWeather(i18nd("meo-desktop", "Weather cache is unavailable."));
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        clearWeather(i18nd("meo-desktop", "Weather cache is unavailable."));
        return;
    }
    const QByteArray bytes = file.read(kMaximumCacheBytes + 1);
    if (bytes.size() > kMaximumCacheBytes) {
        clearWeather(i18nd("meo-desktop", "Weather cache is unavailable."));
        return;
    }
    const QJsonDocument document = QJsonDocument::fromJson(bytes);
    if (!document.isObject()) {
        clearWeather(i18nd("meo-desktop", "Weather cache is invalid."));
        return;
    }
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("schemaVersion")).toInt() != 1) {
        clearWeather(i18nd("meo-desktop", "Weather cache has an unsupported version."));
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
        clearWeather(i18nd("meo-desktop", "Weather cache is invalid."));
        return;
    }

    int weatherCode = 0;
    const QString displayedCondition = stableWeatherCode(
        object.value(QStringLiteral("weatherCode")),
        &weatherCode
    )
        ? localizedConditionForCode(weatherCode)
        : condition;

    const bool stale = updatedAt.secsTo(QDateTime::currentDateTimeUtc()) > kMaximumCacheAgeSeconds;
    const QString temperatureText = QString::number(temperature, 'f', std::abs(temperature - std::round(temperature)) < 0.05 ? 0 : 1)
            + QChar(0x00B0) + unit;
    const QString location = boundedText(object.value(QStringLiteral("location")).toString(), 64);
    const QString iconName = safeIconName(object.value(QStringLiteral("iconName")).toString());

    QVariantList forecastItems;
    const QJsonArray forecastArray = object.value(QStringLiteral("forecast")).toArray();
    forecastItems.reserve(std::min<qsizetype>(forecastArray.size(), 6));
    for (qsizetype index = 0; index < forecastArray.size() && index < 6; ++index) {
        if (!forecastArray.at(index).isObject()) {
            continue;
        }
        const QJsonObject entry = forecastArray.at(index).toObject();
        const QString time = boundedText(entry.value(QStringLiteral("time")).toString(), 32);
        const double forecastTemperature =
            entry.value(QStringLiteral("temperature")).toDouble(std::numeric_limits<double>::quiet_NaN());
        int forecastCode = 0;
        if (time.size() < 16 || !std::isfinite(forecastTemperature)
            || forecastTemperature < -100 || forecastTemperature > 100
            || !stableWeatherCode(entry.value(QStringLiteral("weatherCode")), &forecastCode)) {
            continue;
        }

        const QString hourLabel = time.mid(11, 5);
        forecastItems.push_back(QVariantMap{
            {QStringLiteral("time"), hourLabel},
            {QStringLiteral("temperatureText"),
             QString::number(forecastTemperature, 'f',
                             std::abs(forecastTemperature - std::round(forecastTemperature)) < 0.05 ? 0 : 1)
                 + QChar(0x00B0) + unit},
            {QStringLiteral("condition"), localizedConditionForCode(forecastCode)},
            {QStringLiteral("iconName"), iconForCode(forecastCode)},
        });
    }

    const bool available = !stale;
    if (m_available == available && m_stale == stale && m_temperatureText == temperatureText
        && m_condition == displayedCondition && m_iconName == iconName && m_location == location
        && m_forecast == forecastItems && m_updatedAt == updatedAt) {
        setError({});
        return;
    }
    m_available = available;
    m_stale = stale;
    m_temperatureText = temperatureText;
    m_condition = displayedCondition;
    m_iconName = iconName;
    m_location = location;
    m_forecast = forecastItems;
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
            || !m_iconName.isEmpty() || !m_location.isEmpty() || !m_forecast.isEmpty()
            || m_updatedAt.isValid();
    m_available = false;
    m_stale = false;
    m_temperatureText.clear();
    m_condition.clear();
    m_iconName.clear();
    m_location.clear();
    m_forecast.clear();
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
