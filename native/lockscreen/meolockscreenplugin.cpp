/*
    SPDX-FileCopyrightText: 2026 MeoArch contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "screencoordinator.h"

#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <qqml.h>

namespace
{
QObject *screenCoordinatorProvider(QQmlEngine *, QJSEngine *)
{
    auto *coordinator = new ScreenCoordinator;
    // KScreenLocker uses one shared QML engine for all its per-screen secure
    // windows. C++ ownership makes that single, non-secret presentation state
    // survive component replacement until the greeter exits.
    QQmlEngine::setObjectOwnership(coordinator, QQmlEngine::CppOwnership);
    return coordinator;
}

class MeoLockScreenPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QByteArray(uri) == QByteArray("Meo.KScreenLocker"));
        qmlRegisterSingletonType<ScreenCoordinator>(uri, 1, 0, "ScreenCoordinator", screenCoordinatorProvider);
    }
};
}

#include "meolockscreenplugin.moc"
