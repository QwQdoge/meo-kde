#include "weathercache.h"

#include <KLocalizedString>

#include <QDir>
#include <QFile>
#include <QFileInfo>
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
