#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtTest/QTest>
#include <QtWidgets/QApplication>
#include <QtWidgets/QStyle>
#include <QtWidgets/QStyleFactory>

#include <memory>

class StyleSmoke final : public QObject
{
    Q_OBJECT

private slots:
    void discoversMeo()
    {
        QCoreApplication::addLibraryPath(QStringLiteral(MEO_STYLE_PLUGIN_ROOT));
        QVERIFY2(QStyleFactory::keys().contains(QStringLiteral("Meo"), Qt::CaseInsensitive),
                 "The staged Meo QStyle plugin was not discovered");
        std::unique_ptr<QStyle> style(QStyleFactory::create(QStringLiteral("Meo")));
        QVERIFY(style);
        QCOMPARE(style->objectName().compare(QStringLiteral("Meo"), Qt::CaseInsensitive), 0);
    }
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    StyleSmoke test;
    return QTest::qExec(&test, argc, argv);
}

#include "style-smoke.moc"
