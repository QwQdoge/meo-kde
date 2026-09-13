#include "weathercache.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QTest>

class WeatherCacheTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QDir().mkpath(QFileInfo(WeatherCache::cachePath()).absolutePath());
    }

    void cleanup()
    {
        QFile::remove(WeatherCache::cachePath());
    }

    void readsFreshBoundedCache()
    {
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
    static void writeCache(const QJsonObject &object)
    {
        QFile file(WeatherCache::cachePath());
        QVERIFY2(file.open(QIODevice::WriteOnly | QIODevice::Truncate), "Unable to write weather cache test fixture");
        file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    }
};

QTEST_GUILESS_MAIN(WeatherCacheTest)

#include "weathercache-test.moc"
