#include "systemstatehub.h"

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

class MeoSystemPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QByteArray(uri) == QByteArray("Meo.System"));
        qmlRegisterSingletonType<SystemStateHub>(uri, 1, 0, "SystemState", systemStateProvider);
    }
};
}

#include "meosystemplugin.moc"
