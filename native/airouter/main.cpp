#include "service.h"

#include <QDBusConnection>
#include <QDebug>
#include <QGuiApplication>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    // KIO activation may create and close transient startup windows. The
    // session-bus owner must remain alive after the launched application opens.
    app.setQuitOnLastWindowClosed(false);
    // KIO jobs use QEventLoopLocker; releasing a job must not quit this daemon.
    QCoreApplication::setQuitLockEnabled(false);
    app.setApplicationName(QStringLiteral("Meo AI Router"));
    RouterService service;
    auto bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.meo.AIRouter1"))
        || !bus.registerObject(QStringLiteral("/org/meo/AIRouter1"), &service,
                               QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals)) {
        qCritical() << "Could not register org.meo.AIRouter1:" << bus.lastError().message();
        return EXIT_FAILURE;
    }
    return app.exec();
}
