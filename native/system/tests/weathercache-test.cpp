#include "weathercache.h"

#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTest>
#include <QTemporaryDir>

class WeatherCacheTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY2(m_stateHome.isValid(), "Unable to create isolated XDG state home");
        qputenv("XDG_STATE_HOME", m_stateHome.path().toUtf8());
        QDir().mkpath(QFileInfo(WeatherCache::cachePath()).absolutePath());
        KLocalizedString::setApplicationDomain("meo-desktop");
        KLocalizedString::addDomainLocaleDir(
            "meo-desktop",
            QStringLiteral(MEO_I18N_LOCALE_DIR)
        );
        KLocalizedString::setLanguages({QStringLiteral("en")});
    }

    void cleanupTestCase()
    {
        qunsetenv("XDG_STATE_HOME");
    }

    void cleanup()
    {
        QFile::remove(WeatherCache::cachePath());
    }

    void usesSharedXdgStatePath()
    {
        QCOMPARE(WeatherCache::cachePath(),
                 QDir(m_stateHome.path()).filePath(QStringLiteral("meo/weather/lockscreen.json")));
    }

    void readsFreshBoundedCache()
    {
        KLocalizedString::setLanguages({QStringLiteral("en")});
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("location"), QStringLiteral("Singapore")},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
            {QStringLiteral("iconName"), QStringLiteral("weather-partly-cloudy")},
        });

        WeatherCache cache;
        QVERIFY(cache.available());
        QVERIFY(!cache.stale());
        QCOMPARE(cache.temperatureText(), QStringLiteral("28°C"));
        QCOMPARE(cache.condition(), QStringLiteral("Partly cloudy"));
        QCOMPARE(cache.location(), QStringLiteral("Singapore"));
    }

    void readsBoundedHourlyForecast()
    {
        KLocalizedString::setLanguages({QStringLiteral("en")});
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
            {QStringLiteral("weatherCode"), 3},
            {QStringLiteral("forecast"), QJsonArray{
                QJsonObject{{QStringLiteral("time"), QStringLiteral("2026-09-25T10:00")},
                            {QStringLiteral("temperature"), 29.0},
                            {QStringLiteral("weatherCode"), 2}},
                QJsonObject{{QStringLiteral("time"), QStringLiteral("2026-09-25T11:00")},
                            {QStringLiteral("temperature"), 30.5},
                            {QStringLiteral("weatherCode"), 61}},
            }},
        });

        WeatherCache cache;
        QVERIFY(cache.available());
        QCOMPARE(cache.forecast().size(), 2);
        const QVariantMap first = cache.forecast().at(0).toMap();
        QCOMPARE(first.value(QStringLiteral("time")).toString(), QStringLiteral("10:00"));
        QCOMPARE(first.value(QStringLiteral("temperatureText")).toString(), QStringLiteral("29°C"));
        QCOMPARE(first.value(QStringLiteral("iconName")).toString(), QStringLiteral("weather-partly-cloudy"));
        const QVariantMap second = cache.forecast().at(1).toMap();
        QCOMPARE(second.value(QStringLiteral("temperatureText")).toString(), QStringLiteral("30.5°C"));
        QCOMPARE(second.value(QStringLiteral("iconName")).toString(), QStringLiteral("weather-showers"));
    }

    void keepsLegacyConditionWhenTheCacheHasNoStableCode()
    {
        KLocalizedString::setLanguages({QStringLiteral("zh_CN")});
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
        });

        WeatherCache cache;
        QVERIFY(cache.available());
        QCOMPARE(cache.condition(), QStringLiteral("Partly cloudy"));
    }

    void localizesConditionFromStableWeatherCode()
    {
        KLocalizedString::setLanguages({QStringLiteral("zh_CN")});
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
            {QStringLiteral("weatherCode"), 3},
        });

        WeatherCache cache;
        QVERIFY(cache.available());
        QCOMPARE(cache.condition(), QStringLiteral("局部多云"));
    }

    void keepsEnglishFallbackForStableWeatherCode()
    {
        KLocalizedString::setLanguages({QStringLiteral("en")});
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
            {QStringLiteral("weatherCode"), 3},
        });

        WeatherCache cache;
        QVERIFY(cache.available());
        QCOMPARE(cache.condition(), QStringLiteral("Partly cloudy"));
    }

    void localizesCacheReadErrors()
    {
        KLocalizedString::setLanguages({QStringLiteral("zh_CN")});
        writeCache({
            {QStringLiteral("schemaVersion"), 2},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Partly cloudy")},
        });

        WeatherCache cache;
        QVERIFY(!cache.available());
        QCOMPARE(cache.lastError(), QStringLiteral("天气缓存版本不受支持。"));
    }

    void hidesStaleCache()
    {
        writeCache({
            {QStringLiteral("schemaVersion"), 1},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().addSecs(-7 * 60 * 60).toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Cloudy")},
        });

        WeatherCache cache;
        QVERIFY(!cache.available());
        QVERIFY(cache.stale());
    }

    void rejectsUnsupportedSchema()
    {
        writeCache({
            {QStringLiteral("schemaVersion"), 2},
            {QStringLiteral("updatedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
            {QStringLiteral("temperature"), 28.0},
            {QStringLiteral("unit"), QStringLiteral("C")},
            {QStringLiteral("condition"), QStringLiteral("Cloudy")},
        });

        WeatherCache cache;
        QVERIFY(!cache.available());
        QVERIFY(!cache.lastError().isEmpty());
    }

private:
    QTemporaryDir m_stateHome;

    static void writeCache(const QJsonObject &object)
    {
        QFile file(WeatherCache::cachePath());
        QVERIFY2(file.open(QIODevice::WriteOnly | QIODevice::Truncate), "Unable to write weather cache test fixture");
        file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    }
};

QTEST_GUILESS_MAIN(WeatherCacheTest)

#include "weathercache-test.moc"
