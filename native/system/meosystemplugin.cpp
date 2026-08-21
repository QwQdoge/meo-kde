#include "systemstatehub.h"
#include "dynamiccolorprovider.h"
#include "mediacontroller.h"
#include "platformcontroller.h"

#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <qqml.h>

namespace
{
QObject *systemStateProvider(QQmlEngine *, QJSEngine *)
{
    auto *state = new SystemStateHub;
    // plasmashell owns a long-lived engine and may unload QML components during
    // layout changes. Keep the process-wide backend alive until process exit;
    // deleting it during engine teardown can race BluezQt shared-pointer state.
    QQmlEngine::setObjectOwnership(state, QQmlEngine::CppOwnership);
    return state;
}

QObject *platformProvider(QQmlEngine *, QJSEngine *)
{
    auto *controller = new PlatformController;
    QQmlEngine::setObjectOwnership(controller, QQmlEngine::CppOwnership);
    return controller;
}

QObject *materialColorsProvider(QQmlEngine *, QJSEngine *)
{
    auto *provider = new DynamicColorProvider;
    QQmlEngine::setObjectOwnership(provider, QQmlEngine::CppOwnership);
    return provider;
}

QObject *mediaProvider(QQmlEngine *, QJSEngine *)
{
    auto *controller = new MediaController;
    QQmlEngine::setObjectOwnership(controller, QQmlEngine::CppOwnership);
    return controller;
}

class MeoSystemPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QByteArray(uri) == QByteArray("Meo.System"));
        qmlRegisterSingletonType<SystemStateHub>(uri, 1, 0, "SystemState", systemStateProvider);
        qmlRegisterSingletonType<PlatformController>(uri, 1, 0, "Platform", platformProvider);
        qmlRegisterSingletonType<MediaController>(uri, 1, 0, "Media", mediaProvider);
        qmlRegisterSingletonType<DynamicColorProvider>(uri, 1, 0, "MaterialColors", materialColorsProvider);
    }
};
}

#include "meosystemplugin.moc"
