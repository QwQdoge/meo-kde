#include "dockconfig.h"
#include "dockwindowcontroller.h"

#include <QDBusConnection>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QTextStream>
#include <QTimer>

int main(int argc, char **argv)
{
    QGuiApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("Meo Dock"));
    application.setApplicationDisplayName(QStringLiteral("Meo Dock"));
    application.setDesktopFileName(QStringLiteral("org.meo.dock"));
    application.setOrganizationName(QStringLiteral("MeoArch"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Meo Dock"));
    parser.addHelpOption();
    const QCommandLineOption validateOption(
        QStringLiteral("validate"),
        QStringLiteral("Load the task model and QML without creating a Layer Shell surface."));
    parser.addOption(validateOption);
    const QCommandLineOption screenshotOption(
        QStringLiteral("screenshot"),
        QStringLiteral("Render a non-Layer-Shell visual preview and save it."),
        QStringLiteral("file"));
    parser.addOption(screenshotOption);
    parser.process(application);

    // One task model must own the launchers. A second process would duplicate
    // the Layer Shell surface and race while persisting manual launcher order.
    const bool nonInteractive = parser.isSet(validateOption) || parser.isSet(screenshotOption);
    if (!nonInteractive) {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("org.meo.Dock"))) {
            return EXIT_SUCCESS;
        }
    }

    DockConfig config;
    if (!nonInteractive && !config.shouldShow()) {
        return EXIT_SUCCESS;
    }
    if (!nonInteractive) {
        QDBusConnection::sessionBus().registerObject(
            QStringLiteral("/Dock"), &config,
            QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableProperties);
    }
    DockWindowController windowController;
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlEngine::warnings, &engine,
                     [](const QList<QQmlError> &warnings) {
                         QTextStream errorStream(stderr);
                         for (const QQmlError &warning : warnings) {
                             errorStream << warning.toString() << Qt::endl;
                         }
                     });
#ifdef MEOUI_IMPORT_ROOT_PATH
    engine.addImportPath(QStringLiteral(MEOUI_IMPORT_ROOT_PATH));
#endif
#ifdef MEO_KDE_IMPORT_ROOT_PATH
    engine.addImportPath(QStringLiteral(MEO_KDE_IMPORT_ROOT_PATH));
#endif
    engine.rootContext()->setContextProperty(QStringLiteral("DockConfig"), &config);
    engine.rootContext()->setContextProperty(QStringLiteral("DockWindowController"),
                                             &windowController);
    engine.rootContext()->setContextProperty(QStringLiteral("DockPreviewMode"),
                                             parser.isSet(screenshotOption));
    engine.loadFromModule(QStringLiteral("org.meo.dock"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) {
        return EXIT_FAILURE;
    }
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!window) {
        return EXIT_FAILURE;
    }
    if (parser.isSet(validateOption)) {
        QTimer::singleShot(0, &application, &QCoreApplication::quit);
        return application.exec();
    }
    if (parser.isSet(screenshotOption)) {
        const QString path = parser.value(screenshotOption);
        window->show();
        QTimer::singleShot(900, window, [window, path, &application] {
            const QImage image = window->grabWindow();
            if (!image.isNull() && image.save(path)) {
                application.quit();
            } else {
                application.exit(EXIT_FAILURE);
            }
        });
        return application.exec();
    }
    windowController.attach(window);
    window->show();
    return application.exec();
}
