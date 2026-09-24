#include "taskmanagercontroller.h"

#include <QCoreApplication>
#include <QTest>

class TaskManagerControllerTest : public QObject
{
    Q_OBJECT

private slots:
    void samplesProcessesOnDemand()
    {
        TaskManagerController controller;
        QVERIFY(controller.available());
        QVERIFY(!controller.monitoring());

        controller.subscribe(QStringLiteral("test"),
                             {QStringLiteral("processes"), QStringLiteral("users")});
        QVERIFY(controller.monitoring());
        QVERIFY(controller.activeModules().contains(QStringLiteral("processes")));

        controller.refreshNow();
        QVERIFY(!controller.processes().isEmpty());
        QVERIFY(!controller.processTree().isEmpty());
        QVERIFY(!controller.processGroups().isEmpty());
        QVERIFY(!controller.userSummaries().isEmpty());

        const QVariantMap first = controller.processes().constFirst().toMap();
        QVERIFY(first.contains(QStringLiteral("pid")));
        QVERIFY(first.contains(QStringLiteral("cpu")));
        QVERIFY(first.contains(QStringLiteral("memoryBytes")));
        QVERIFY(first.contains(QStringLiteral("diskReadBytesPerSecond")));
        QVERIFY(first.contains(QStringLiteral("category")));

        controller.unsubscribe(QStringLiteral("test"));
        QVERIFY(!controller.monitoring());
    }

    void protectsEssentialProcesses()
    {
        TaskManagerController controller;
        QVERIFY(!controller.terminateProcess(1));
        QVERIFY(!controller.actionError().isEmpty());
        controller.clearActionError();
        QVERIFY(controller.actionError().isEmpty());

        QVERIFY(!controller.setProcessPriority(1, 10));
        QVERIFY(!controller.actionError().isEmpty());

        controller.clearActionError();
        QVERIFY(!controller.setProcessEfficiency(1, true));
        QVERIFY(!controller.actionError().isEmpty());

        controller.clearActionError();
        QVERIFY(!controller.setProcessSuspended(1, true));
        QVERIFY(!controller.actionError().isEmpty());

        controller.clearActionError();
        QVERIFY(!controller.terminateProcessTree(1));
        QVERIFY(!controller.actionError().isEmpty());

        controller.clearActionError();
        QVERIFY(!controller.terminateProcesses(QVariantList{1}));
        QVERIFY(!controller.actionError().isEmpty());

        controller.clearActionError();
        QVERIFY(!controller.setProcessCpuAffinityAll(1));
        QVERIFY(!controller.actionError().isEmpty());
    }

    void pausesSamplingWithoutDroppingSubscriptions()
    {
        TaskManagerController controller;
        controller.subscribe(QStringLiteral("test"), {QStringLiteral("processes")});
        QVERIFY(controller.monitoring());
        QVERIFY(!controller.paused());

        controller.setPaused(true);
        QVERIFY(controller.paused());
        QVERIFY(controller.monitoring());
        controller.refreshNow();
        QVERIFY(!controller.processes().isEmpty());

        controller.setPaused(false);
        QVERIFY(!controller.paused());
    }

    void selectedProcessExposesAdvancedDiagnostics()
    {
        TaskManagerController controller;
        controller.subscribe(QStringLiteral("details"),
                             {QStringLiteral("processes"), QStringLiteral("details")});
        controller.refreshNow();
        controller.selectProcess(QCoreApplication::applicationPid());

        const QVariantMap details = controller.selectedProcessDetails();
        QCOMPARE(details.value(QStringLiteral("pid")).toLongLong(),
                 static_cast<qint64>(QCoreApplication::applicationPid()));
        QVERIFY(details.contains(QStringLiteral("executablePath")));
        QVERIFY(details.contains(QStringLiteral("workingDirectory")));
        QVERIFY(details.contains(QStringLiteral("openFileDescriptorCount")));
        QVERIFY(details.contains(QStringLiteral("cpuAffinity")));
        QVERIFY(details.contains(QStringLiteral("cpuTimeSeconds")));
        QVERIFY(details.contains(QStringLiteral("elapsedSeconds")));
        QVERIFY(details.contains(QStringLiteral("virtualMemoryBytes")));
        QVERIFY(details.contains(QStringLiteral("peakResidentMemoryBytes")));
        QVERIFY(details.contains(QStringLiteral("tcpSocketCount")));
        QVERIFY(details.contains(QStringLiteral("udpSocketCount")));
        QVERIFY(details.contains(QStringLiteral("cgroupPath")));
        QVERIFY(details.contains(QStringLiteral("oomScore")));
    }

    void boundsRefreshInterval()
    {
        TaskManagerController controller;
        controller.setRefreshInterval(1);
        QCOMPARE(controller.refreshInterval(), 500);
        controller.setRefreshInterval(60000);
        QCOMPARE(controller.refreshInterval(), 10000);
    }
};

QTEST_GUILESS_MAIN(TaskManagerControllerTest)

#include "taskmanagercontroller-test.moc"
