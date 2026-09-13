#include "desktopwidgetbridge.h"

#include <QDir>
#include <QFile>
#include <QSet>
#include <QTest>
#include <QTemporaryDir>

namespace
{
bool writePlasmaPackage(const QString &dataRoot,
                        const QString &pluginId,
                        const QString &metadata)
{
    const QDir packageDirectory(QDir(dataRoot).filePath(
        QStringLiteral("plasma/plasmoids/") + pluginId));
    if (!QDir().mkpath(packageDirectory.filePath(QStringLiteral("contents/ui")))) {
        return false;
    }
    QFile metadataFile(packageDirectory.filePath(QStringLiteral("metadata.json")));
    if (!metadataFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    metadataFile.write(metadata.toUtf8());
    metadataFile.close();

    QFile mainQml(packageDirectory.filePath(QStringLiteral("contents/ui/main.qml")));
    if (!mainQml.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    mainQml.write("import QtQuick\nItem {}\n");
    return true;
}
}

class DesktopWidgetBridgeTest : public QObject
{
    Q_OBJECT

private slots:
    void exposesMeoAndNativePlasmaCatalogsSeparately()
    {
        DesktopWidgetBridge bridge;
        const QVariantList meoCatalog = bridge.meoCatalog();
        QCOMPARE(meoCatalog.size(), 2);

        QSet<QString> ids;
        for (const QVariant &entry : meoCatalog) {
            const QVariantMap item = entry.toMap();
            QCOMPARE(item.value(QStringLiteral("host")).toString(), QStringLiteral("meo"));
            QVERIFY(item.value(QStringLiteral("lockScreenEligible")).toBool());
            QVERIFY(!item.value(QStringLiteral("lockScreenAdapter")).toString().isEmpty());
            QVERIFY(item.value(QStringLiteral("presentationModes")).toStringList()
                        .contains(QStringLiteral("meoFramed")));
            ids.insert(item.value(QStringLiteral("id")).toString());
        }
        QCOMPARE(ids, QSet<QString>({QStringLiteral("clock"), QStringLiteral("media")}));

        for (const QVariant &entry : bridge.plasmaCatalog()) {
            const QVariantMap item = entry.toMap();
            QCOMPARE(item.value(QStringLiteral("host")).toString(), QStringLiteral("plasma"));
            QVERIFY(item.value(QStringLiteral("compatibilityMode")).toBool());
            QVERIFY(!item.value(QStringLiteral("lockScreenEligible")).toBool());
            QVERIFY(item.value(QStringLiteral("lockScreenAdapter")).toString().isEmpty());
            QVERIFY(!item.value(QStringLiteral("pluginId")).toString().isEmpty());
            QVERIFY(item.value(QStringLiteral("presentationModes")).toStringList()
                        .contains(QStringLiteral("native")));
        }

        QCOMPARE(bridge.catalog().size(), meoCatalog.size() + bridge.plasmaCatalog().size());
    }

    void rejectsUnknownMeoWidgetIdsBeforeContainmentAccess()
    {
        DesktopWidgetBridge bridge;
        QVERIFY(!bridge.addMeoWidget(nullptr, QStringLiteral("not-in-registry")));
        QVERIFY(bridge.lastError().contains(QStringLiteral("registry")));
    }

    void rejectsRawUndiscoveredPlasmaPackageIdsBeforeContainmentAccess()
    {
        DesktopWidgetBridge bridge;
        QVERIFY(!bridge.addPlasmaWidget(nullptr, QStringLiteral("not.a.discovered.package")));
        QVERIFY(bridge.lastError().contains(QStringLiteral("standard Plasma package location")));
    }

    void discoversOnlyValidDesktopPackagesFromTheConfiguredStandardRoot()
    {
        QTemporaryDir dataRoot;
        QVERIFY(dataRoot.isValid());
        QVERIFY(writePlasmaPackage(dataRoot.path(), QStringLiteral("com.example.weather"),
                                   QStringLiteral(R"({
                "KPackageStructure": "Plasma/Applet",
                "KPlugin": {
                    "Id": "com.example.weather",
                    "Name": "Example weather",
                    "Description": "A test desktop package",
                    "Icon": "weather-clear",
                    "FormFactors": ["desktop"]
                }
            })")));
        QVERIFY(writePlasmaPackage(dataRoot.path(), QStringLiteral("com.example.containment"),
                                   QStringLiteral(R"({
                "KPackageStructure": "Plasma/Applet",
                "X-Plasma-ContainmentType": "Desktop",
                "KPlugin": { "Id": "com.example.containment", "Name": "Not a widget" }
            })")));
        QVERIFY(writePlasmaPackage(dataRoot.path(), QStringLiteral("com.example.panelonly"),
                                   QStringLiteral(R"({
                "KPackageStructure": "Plasma/Applet",
                "KPlugin": {
                    "Id": "com.example.panelonly",
                    "Name": "Panel only",
                    "FormFactors": ["panel"]
                }
            })")));

        DesktopWidgetBridge bridge(nullptr, {dataRoot.path()});
        const QVariantList catalog = bridge.plasmaCatalog();
        QCOMPARE(catalog.size(), 1);
        const QVariantMap item = catalog.constFirst().toMap();
        QCOMPARE(item.value(QStringLiteral("host")).toString(), QStringLiteral("plasma"));
        QCOMPARE(item.value(QStringLiteral("id")).toString(), QStringLiteral("com.example.weather"));
        QCOMPARE(item.value(QStringLiteral("source")).toString(), QStringLiteral("user"));
        QVERIFY(!item.value(QStringLiteral("lockScreenEligible")).toBool());
    }

    void rejectsNonDesktopContainments()
    {
        DesktopWidgetBridge bridge;
        QObject unrelatedObject;
        QVERIFY(!bridge.addMeoWidget(&unrelatedObject, QStringLiteral("clock")));
        QVERIFY(bridge.lastError().contains(QStringLiteral("desktop")));
    }
};

QTEST_GUILESS_MAIN(DesktopWidgetBridgeTest)

#include "desktopwidgetbridge-test.moc"
