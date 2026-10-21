#include "shellappearance.h"
#include "windowblur.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

class ShellAppearanceTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QVERIFY(m_config.isValid());
        qputenv("XDG_CONFIG_HOME", m_config.path().toUtf8());
    }

    void defaultsAreSolid()
    {
        ShellAppearance appearance;
        QVERIFY(!appearance.transparency());
        QVERIFY(!appearance.blur());
    }

    void roundedRegionCutsTheCorners()
    {
        const QRegion region = WindowBlur::roundedRegion(QRectF(0, 0, 100, 60), 20);
        QVERIFY(region.contains(QPoint(50, 30)));
        QVERIFY(region.contains(QPoint(50, 1)));
        // The very corner pixel lies outside a 20px radius.
        QVERIFY(!region.contains(QPoint(0, 0)));
        QVERIFY(!region.contains(QPoint(99, 59)));
        QVERIFY(WindowBlur::roundedRegion(QRectF(), 8).isEmpty());
    }

private:
    QTemporaryDir m_config;
};

QTEST_MAIN(ShellAppearanceTest)
#include "shellappearance-test.moc"
