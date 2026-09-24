#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-system-monitor"));
    app.setApplicationDisplayName(QStringLiteral("System Monitor"));
    app.setOrganizationName(QStringLiteral("Meo"));

    QQmlApplicationEngine engine;
    const QString userQmlRoot = QDir(
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("meo-kde/qml"));
    if (QFileInfo::exists(userQmlRoot)) {
        engine.addImportPath(userQmlRoot);
    }
    engine.loadFromModule(QStringLiteral("MeoKDE"), QStringLiteral("SystemMonitorWindow"));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
