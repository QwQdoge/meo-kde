#include "authenticationcontroller.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>

#ifdef __linux__
#include <sys/prctl.h>
#endif

int main(int argc, char **argv)
{
#ifdef __linux__
    prctl(PR_SET_DUMPABLE, 0);
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-polkit-agent"));
    app.setOrganizationName(QStringLiteral("MeoArch"));
    app.setQuitOnLastWindowClosed(false);

    auto *busInterface = QDBusConnection::sessionBus().interface();
    if (!busInterface) {
        qCritical("Unable to access the session D-Bus.");
        return 1;
    }
    const auto registration = busInterface->registerService(
        QStringLiteral("org.kde.polkit-kde-authentication-agent-1"),
        QDBusConnectionInterface::ReplaceExistingService,
        QDBusConnectionInterface::DontAllowReplacement);
    if (!registration.isValid() || registration.value()
        != QDBusConnectionInterface::ServiceRegistered) {
        qCritical("Another PolicyKit authentication agent is already running.");
        return 1;
    }

    AuthenticationController controller;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("authorization"), &controller);
    engine.load(QUrl(QStringLiteral("qrc:/qml/AuthenticationDialog.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    controller.setDialogWindow(engine.rootObjects().constFirst());
    if (!controller.registerForCurrentSession()) {
        qCritical("Unable to register the Meo PolicyKit listener for this session.");
        return 1;
    }

    return app.exec();
}
