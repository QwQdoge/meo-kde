#include <KWindowSystem>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QWindow>

namespace {

const QString kService = QStringLiteral("org.meo.SystemMonitor");
const QString kPath = QStringLiteral("/org/meo/SystemMonitor");
const QString kInterface = QStringLiteral("org.meo.SystemMonitor");

// Task-manager behaviour: Ctrl+Shift+Esc (or the launcher) raises the
// running monitor instead of starting a second one. The second process hands
// its XDG activation token to the first, because on Wayland only a token
// issued for this user action allows the existing window to take focus.
class Activator : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.meo.SystemMonitor")

public:
    explicit Activator(QQmlApplicationEngine *engine, QObject *parent = nullptr)
        : QObject(parent)
        , m_engine(engine)
    {
    }

public Q_SLOTS:
    void activate(const QString &activationToken)
    {
        const QList<QObject *> roots = m_engine->rootObjects();
        for (QObject *object : roots) {
            auto *window = qobject_cast<QWindow *>(object);
            if (!window) {
                continue;
            }
            if (!activationToken.isEmpty()) {
                KWindowSystem::setCurrentXdgActivationToken(activationToken);
            }
            if (!window->isVisible() || window->visibility() == QWindow::Minimized) {
                window->showNormal();
            }
            window->raise();
            KWindowSystem::activateWindow(window);
        }
    }

private:
    QQmlApplicationEngine *m_engine;
};

} // namespace

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-system-monitor"));
    app.setApplicationDisplayName(QStringLiteral("System Monitor"));
    app.setOrganizationName(QStringLiteral("Meo"));
    app.setDesktopFileName(QStringLiteral("org.meo.systemmonitor"));

    QDBusConnection bus = QDBusConnection::sessionBus();
    const bool primary = !bus.isConnected() || bus.registerService(kService);
    if (!primary) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            kService, kPath, kInterface, QStringLiteral("activate"));
        message << qEnvironmentVariable("XDG_ACTIVATION_TOKEN");
        const QDBusMessage reply = bus.call(message, QDBus::Block, 3000);
        if (reply.type() != QDBusMessage::ErrorMessage) {
            return 0;
        }
        // The owner did not answer (hung or exiting): run a normal instance
        // rather than leaving the user without a task manager.
    }

    QQmlApplicationEngine engine;
    Activator activator(&engine);
    if (primary && bus.isConnected()) {
        bus.registerObject(kPath, &activator, QDBusConnection::ExportAllSlots);
    }

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

#include "systemmonitor-main.moc"
