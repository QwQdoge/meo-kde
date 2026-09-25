/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Per-user Open-Meteo refresher.  The locker never links this executable:
    it only reads the bounded cache through WeatherCache.
*/

#include "weathercache.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QSettings>
#include <QTimer>
#include <QUrlQuery>

#include <cmath>
#include <limits>

namespace
{
constexpr auto kGeocodingEndpoint = "https://geocoding-api.open-meteo.com/v1/search";
constexpr auto kForecastEndpoint = "https://api.open-meteo.com/v1/forecast";
constexpr auto kNetworkTimeoutMs = 10 * 1000;
constexpr auto kMaximumResponseBytes = 256 * 1024;

QJsonObject getJson(QNetworkAccessManager &network, QUrl url, QString *error)
{
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("MeoWeather/1"));
    auto *reply = network.get(request);
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timeout, &QTimer::timeout, reply, [reply] { reply->abort(); });
    QObject::connect(reply, &QNetworkReply::downloadProgress, reply, [reply](qint64 received, qint64) {
        if (received > kMaximumResponseBytes) {
            reply->abort();
        }
    });
    timeout.start(kNetworkTimeoutMs);
    loop.exec();
    const QByteArray payload = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        *error = reply->errorString();
        reply->deleteLater();
        return {};
    }
    reply->deleteLater();
    if (payload.size() > kMaximumResponseBytes) {
        *error = QStringLiteral("Weather response is too large.");
        return {};
    }
    const auto document = QJsonDocument::fromJson(payload);
    if (!document.isObject()) {
        *error = QStringLiteral("Weather service returned invalid data.");
        return {};
    }
    return document.object();
}

QString conditionForCode(int code)
{
    if (code == 0) return QStringLiteral("Clear sky");
    if (code <= 3) return QStringLiteral("Partly cloudy");
    if (code == 45 || code == 48) return QStringLiteral("Foggy");
    if (code <= 57) return QStringLiteral("Drizzle");
    if (code <= 67) return QStringLiteral("Rain");
    if (code <= 77) return QStringLiteral("Snow");
    if (code <= 82) return QStringLiteral("Rain showers");
    if (code <= 86) return QStringLiteral("Snow showers");
    if (code <= 99) return QStringLiteral("Thunderstorm");
    return QStringLiteral("Weather unavailable");
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

bool writeCache(const QJsonObject &cache, QString *error)
{
    const QString path = WeatherCache::cachePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly)) {
        *error = output.errorString();
        return false;
    }
    output.write(QJsonDocument(cache).toJson(QJsonDocument::Compact));
    if (!output.commit()) {
        *error = output.errorString();
        return false;
    }
    return true;
}
}

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    application.setOrganizationName(QStringLiteral("MeoArch"));
    application.setApplicationName(QStringLiteral("meo-weather-refresh"));

    QCommandLineParser parser;
    parser.addHelpOption();
    const QCommandLineOption cityOption(QStringLiteral("city"),
                                        QStringLiteral("Store a city and refresh its weather."),
                                        QStringLiteral("city"));
    parser.addOption(cityOption);
    parser.process(application);

    QSettings preferences(QStringLiteral("MeoArch"), QStringLiteral("MeoWeather"));
    if (parser.isSet(cityOption)) {
        const QString city = parser.value(cityOption).trimmed().left(96);
        if (city.isEmpty()) {
            qCritical("A non-empty city is required.");
            return 2;
        }
        preferences.setValue(QStringLiteral("Weather/city"), city);
        preferences.sync();
    }
    const QString city = preferences.value(QStringLiteral("Weather/city")).toString().trimmed();
    if (city.isEmpty()) {
        qInfo("No weather city is configured; nothing to refresh.");
        return 0;
    }

    QNetworkAccessManager network;
    QUrl geocodingUrl(QString::fromLatin1(kGeocodingEndpoint));
    QUrlQuery geocodingQuery;
    geocodingQuery.addQueryItem(QStringLiteral("name"), city);
    geocodingQuery.addQueryItem(QStringLiteral("count"), QStringLiteral("1"));
    geocodingQuery.addQueryItem(QStringLiteral("language"), QStringLiteral("en"));
    geocodingQuery.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    geocodingUrl.setQuery(geocodingQuery);
    QString error;
    const auto geocoding = getJson(network, geocodingUrl, &error);
    const auto results = geocoding.value(QStringLiteral("results")).toArray();
    if (results.isEmpty() || !results.first().isObject()) {
        qCritical().noquote() << (error.isEmpty() ? QStringLiteral("City was not found.") : error);
        return 1;
    }
    const auto place = results.first().toObject();
    const double latitude = place.value(QStringLiteral("latitude")).toDouble(std::numeric_limits<double>::quiet_NaN());
    const double longitude = place.value(QStringLiteral("longitude")).toDouble(std::numeric_limits<double>::quiet_NaN());
    if (!std::isfinite(latitude) || !std::isfinite(longitude)) {
        qCritical("Weather location is invalid.");
        return 1;
    }

    QUrl forecastUrl(QString::fromLatin1(kForecastEndpoint));
    QUrlQuery forecastQuery;
    forecastQuery.addQueryItem(QStringLiteral("latitude"), QString::number(latitude, 'f', 4));
    forecastQuery.addQueryItem(QStringLiteral("longitude"), QString::number(longitude, 'f', 4));
    forecastQuery.addQueryItem(QStringLiteral("current"), QStringLiteral("temperature_2m,weather_code"));
    forecastQuery.addQueryItem(QStringLiteral("hourly"), QStringLiteral("temperature_2m,weather_code"));
    forecastQuery.addQueryItem(QStringLiteral("forecast_hours"), QStringLiteral("6"));
    forecastQuery.addQueryItem(QStringLiteral("temperature_unit"), QStringLiteral("celsius"));
    forecastQuery.addQueryItem(QStringLiteral("timezone"), QStringLiteral("auto"));
    forecastUrl.setQuery(forecastQuery);
    const auto forecast = getJson(network, forecastUrl, &error);
    const auto current = forecast.value(QStringLiteral("current")).toObject();
    if (current.isEmpty() || !current.contains(QStringLiteral("temperature_2m"))) {
        qCritical().noquote() << (error.isEmpty() ? QStringLiteral("Weather forecast is unavailable.") : error);
        return 1;
    }

    const int code = current.value(QStringLiteral("weather_code")).toInt(-1);
    const QString location = place.value(QStringLiteral("name")).toString().left(64);

    QJsonArray cachedForecast;
    const QJsonObject hourly = forecast.value(QStringLiteral("hourly")).toObject();
    const QJsonArray hourlyTimes = hourly.value(QStringLiteral("time")).toArray();
    const QJsonArray hourlyTemperatures = hourly.value(QStringLiteral("temperature_2m")).toArray();
    const QJsonArray hourlyCodes = hourly.value(QStringLiteral("weather_code")).toArray();
    const qsizetype forecastCount =
        std::min<qsizetype>({6, hourlyTimes.size(), hourlyTemperatures.size(), hourlyCodes.size()});
    for (qsizetype index = 0; index < forecastCount; ++index) {
        const QString time = hourlyTimes.at(index).toString().left(32);
        const double temperature =
            hourlyTemperatures.at(index).toDouble(std::numeric_limits<double>::quiet_NaN());
        const int weatherCode = hourlyCodes.at(index).toInt(-1);
        if (time.size() < 16 || !std::isfinite(temperature)
            || temperature < -100 || temperature > 100
            || weatherCode < 0 || weatherCode > 99) {
            continue;
        }
        cachedForecast.push_back(QJsonObject{
            {QStringLiteral("time"), time},
            {QStringLiteral("temperature"), temperature},
            {QStringLiteral("weatherCode"), weatherCode},
        });
    }

    const QJsonObject cache{{QStringLiteral("schemaVersion"), 1},
                            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
                            {QStringLiteral("location"), location},
                            {QStringLiteral("temperature"), current.value(QStringLiteral("temperature_2m")).toDouble()},
                            {QStringLiteral("unit"), QStringLiteral("C")},
                            {QStringLiteral("condition"), conditionForCode(code)},
                            {QStringLiteral("weatherCode"), code},
                            {QStringLiteral("iconName"), iconForCode(code)},
                            {QStringLiteral("forecast"), cachedForecast}};
    if (!writeCache(cache, &error)) {
        qCritical().noquote() << error;
        return 1;
    }
    return 0;
}
