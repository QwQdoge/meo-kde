#include "performancecontroller.h"

#include <QTest>

class PerformanceControllerTest : public QObject
{
    Q_OBJECT

private slots:
    void samplesRealSystemMetricsOnDemand()
    {
        PerformanceController controller;
        QVERIFY(controller.available());
        QVERIFY(!controller.monitoring());

        controller.subscribe(QStringLiteral("test"),
                             {QStringLiteral("cpu"),
                              QStringLiteral("memory"),
                              QStringLiteral("disk"),
                              QStringLiteral("system")});
        QVERIFY(controller.monitoring());
        QVERIFY(controller.activeModules().contains(QStringLiteral("cpu")));
        QVERIFY(controller.refreshInterval() >= 500);

        controller.refreshNow();

        QVERIFY(controller.cpuUsage() >= 0.0);
        QVERIFY(controller.cpuUsage() <= 100.0);
        QVERIFY(controller.logicalCores() >= 1);
        QVERIFY(controller.memoryTotalBytes() > 0);
        QVERIFY(controller.memoryUsedBytes() >= 0);
        QVERIFY(controller.memoryUsage() >= 0.0);
        QVERIFY(controller.memoryUsage() <= 100.0);
        QVERIFY(controller.storageTotalBytes() >= 0);
        QVERIFY(controller.uptimeSeconds() >= 0);

        controller.unsubscribe(QStringLiteral("test"));
        QVERIFY(!controller.monitoring());
    }

    void boundsRefreshInterval()
    {
        PerformanceController controller;
        controller.setRefreshInterval(1);
        QCOMPARE(controller.refreshInterval(), 500);
        controller.setRefreshInterval(60000);
        QCOMPARE(controller.refreshInterval(), 10000);
    }
};

QTEST_GUILESS_MAIN(PerformanceControllerTest)

#include "performancecontroller-test.moc"
