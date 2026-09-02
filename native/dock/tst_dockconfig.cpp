#include "dockconfig.h"

#include <QtTest>

class DockConfigTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void acceptsOnlyDocumentedIconModes();
    void createsStableSafeApplicationKeys();
};

void DockConfigTest::acceptsOnlyDocumentedIconModes()
{
    for (const QString &mode : {QStringLiteral("original"), QStringLiteral("tonal"),
                                QStringLiteral("mono"), QStringLiteral("ai")}) {
        QVERIFY(DockConfig::isSupportedIconMode(mode));
    }
    QVERIFY(!DockConfig::isSupportedIconMode(QStringLiteral("outline")));
    QVERIFY(!DockConfig::isSupportedIconMode(QString()));
}

void DockConfigTest::createsStableSafeApplicationKeys()
{
    QCOMPARE(DockConfig::stableApplicationId(QStringLiteral("org.kde.dolphin.desktop"), {}),
             QStringLiteral("org.kde.dolphin"));
    QCOMPARE(DockConfig::stableApplicationId(QString(), QUrl(QStringLiteral("applications:org.kde.konsole.desktop"))),
             QStringLiteral("org.kde.konsole"));
    QCOMPARE(DockConfig::configKeyForApplication(QStringLiteral("vendor/app.desktop"), {}),
             QStringLiteral("vendor%2Fapp"));
}

QTEST_GUILESS_MAIN(DockConfigTest)

#include "tst_dockconfig.moc"
