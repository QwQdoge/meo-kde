#include <taskmanager/abstracttasksmodel.h>
#include <taskmanager/launchertasksmodel.h>

#include <QtTest>

class DockTaskModelTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void resolvesFreedesktopLaunchers();
};

void DockTaskModelTest::resolvesFreedesktopLaunchers()
{
    TaskManager::LauncherTasksModel model;
    model.setLauncherList({QStringLiteral("applications:org.kde.dolphin.desktop"),
                           QStringLiteral("applications:org.kde.konsole.desktop")});

    QCOMPARE(model.launcherList().size(), 2);
    QCOMPARE(model.rowCount(), 2);
    QCOMPARE(model.data(model.index(0, 0), Qt::DecorationRole).canConvert<QIcon>(), true);
    QCOMPARE(model.data(model.index(0, 0), TaskManager::AbstractTasksModel::AppId).toString(),
             QStringLiteral("org.kde.dolphin.desktop"));
}

QTEST_MAIN(DockTaskModelTest)

#include "tst_taskmodel.moc"
