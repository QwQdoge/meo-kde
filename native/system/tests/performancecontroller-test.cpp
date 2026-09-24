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
                              QStringLiteral("network"),
                              QStringLiteral("system"),
                              QStringLiteral("processes")});
        QVERIFY(controller.monitoring());
        QVERIFY(controller.activeModules().contains(QStringLiteral("cpu")));
        QVERIFY(controller.refreshInterval() >= 500);

        controller.refreshNow();

        QVERIFY(controller.cpuUsage() >= 0.0);
        QVERIFY(controller.cpuUsage() <= 100.0);
        QVERIFY(controller.logicalCores() >= 1);
        QVERIFY(controller.physicalCores() >= 1);
        QVERIFY(controller.cpuSockets() >= 1);
        QVERIFY(controller.cpuMaxFrequencyMHz() >= 0.0);
        QVERIFY(!controller.cpuArchitecture().isEmpty());
        QVERIFY(!controller.cpuCores().isEmpty());
        QVERIFY(controller.cpuCores().size() <= controller.logicalCores());
        if (!controller.cpuCaches().isEmpty()) {
            const QVariantMap cache = controller.cpuCaches().constFirst().toMap();
            QVERIFY(cache.value(QStringLiteral("level")).toInt() >= 1);
            QVERIFY(cache.value(QStringLiteral("sizeBytes")).toLongLong() > 0);
        }
        QVERIFY(controller.memoryTotalBytes() > 0);
        QVERIFY(controller.memoryUsedBytes() >= 0);
        QVERIFY(controller.memoryAvailableBytes() >= 0);
        QVERIFY(controller.memoryCachedBytes() >= 0);
        QVERIFY(controller.memoryBuffersBytes() >= 0);
        QVERIFY(controller.memorySharedBytes() >= 0);
        QVERIFY(controller.memoryAvailableBytes() <= controller.memoryTotalBytes());
        QVERIFY(controller.memoryUsage() >= 0.0);
        QVERIFY(controller.memoryUsage() <= 100.0);
        const QVariantMap pressure = controller.pressure();
        QVERIFY(pressure.contains(QStringLiteral("available")));
        QVERIFY(pressure.contains(QStringLiteral("cpuSomeAvg10")));
        QVERIFY(pressure.contains(QStringLiteral("memorySomeAvg10")));
        QVERIFY(pressure.contains(QStringLiteral("memoryFullAvg10")));
        QVERIFY(pressure.contains(QStringLiteral("ioSomeAvg10")));
        QVERIFY(pressure.contains(QStringLiteral("ioFullAvg10")));
        QVERIFY(pressure.value(QStringLiteral("cpuSomeAvg10")).toDouble() >= 0.0);
        QVERIFY(pressure.value(QStringLiteral("memorySomeAvg10")).toDouble() >= 0.0);
        QVERIFY(pressure.value(QStringLiteral("ioSomeAvg10")).toDouble() >= 0.0);
        QVERIFY(controller.storageTotalBytes() >= 0);
        if (!controller.networkInterfaces().isEmpty()) {
            const QVariantMap network = controller.networkInterfaces().constFirst().toMap();
            QVERIFY(network.contains(QStringLiteral("name")));
            QVERIFY(network.contains(QStringLiteral("rxBytesPerSecond")));
            QVERIFY(network.contains(QStringLiteral("txBytesPerSecond")));
            QVERIFY(network.contains(QStringLiteral("kind")));
            QVERIFY(network.contains(QStringLiteral("addressSummary")));
            QVERIFY(network.contains(QStringLiteral("hardwareAddress")));
            QVERIFY(network.contains(QStringLiteral("rxPackets")));
            QVERIFY(network.contains(QStringLiteral("txPackets")));
            QVERIFY(network.contains(QStringLiteral("rxErrors")));
            QVERIFY(network.contains(QStringLiteral("txErrors")));
            QVERIFY(network.contains(QStringLiteral("rxDropped")));
            QVERIFY(network.contains(QStringLiteral("txDropped")));
        }
        if (!controller.disks().isEmpty()) {
            const QVariantMap disk = controller.disks().constFirst().toMap();
            QVERIFY(disk.contains(QStringLiteral("name")));
            QVERIFY(disk.contains(QStringLiteral("usage")));
            QVERIFY(disk.contains(QStringLiteral("readBytesPerSecond")));
            QVERIFY(disk.contains(QStringLiteral("writeBytesPerSecond")));
            QVERIFY(disk.contains(QStringLiteral("readIops")));
            QVERIFY(disk.contains(QStringLiteral("writeIops")));
            QVERIFY(disk.contains(QStringLiteral("averageLatencyMs")));
            QVERIFY(disk.contains(QStringLiteral("inFlight")));
        }
        QVERIFY(controller.uptimeSeconds() >= 0);
        QVERIFY(controller.processCount() > 0);
        QVERIFY(!controller.processes().isEmpty());

        controller.unsubscribe(QStringLiteral("test"));
        QVERIFY(!controller.monitoring());
    }

    void protectsEssentialProcesses()
    {
        PerformanceController controller;
        QVERIFY(!controller.terminateProcess(1));
        QVERIFY(!controller.processActionError().isEmpty());
        controller.clearProcessActionError();
        QVERIFY(controller.processActionError().isEmpty());

        QVERIFY(!controller.setProcessPriority(1, 10));
        QVERIFY(!controller.processActionError().isEmpty());
    }

    void pausesSamplingWithoutDroppingSubscriptions()
    {
        PerformanceController controller;
        controller.subscribe(QStringLiteral("test"),
                             {QStringLiteral("cpu"), QStringLiteral("memory")});
        QVERIFY(controller.monitoring());
        QVERIFY(!controller.paused());

        controller.setPaused(true);
        QVERIFY(controller.paused());
        QVERIFY(controller.monitoring());
        controller.refreshNow();
        QVERIFY(controller.memoryTotalBytes() > 0);

        controller.setPaused(false);
        QVERIFY(!controller.paused());
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
