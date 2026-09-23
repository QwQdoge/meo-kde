#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-system-monitor"));
    app.setApplicationDisplayName(QStringLiteral("System Monitor"));
    app.setOrganizationName(QStringLiteral("Meo"));

    QQmlApplicationEngine engine;
    engine.loadFromModule(QStringLiteral("MeoKDE"), QStringLiteral("SystemMonitorWindow"));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
