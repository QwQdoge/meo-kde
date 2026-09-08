#include "sessionactionservice.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Meo Session Actions"));
    SessionActionService service;
    auto bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.meo.SessionAction1"))
        || !bus.registerObject(QStringLiteral("/org/meo/SessionAction1"), &service,
                               QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals)) {
        qCritical() << "Could not register org.meo.SessionAction1:" << bus.lastError().message();
        return EXIT_FAILURE;
    }
    return app.exec();
}
