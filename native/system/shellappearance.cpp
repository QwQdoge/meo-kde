#include "shellappearance.h"

#include <KConfigGroup>
#include <KSharedConfig>

ShellAppearance::ShellAppearance(QObject *parent)
    : QObject(parent)
    , m_watcher(KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("meo-shellrc"))))
{
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == QLatin1String("Appearance")) {
            reload();
        }
    });
    reload();
}

void ShellAppearance::reload()
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("meo-shellrc"));
    config->reparseConfiguration();
    const KConfigGroup group(config, QStringLiteral("Appearance"));
    const bool transparency = group.readEntry("SurfaceTransparency", false);
    const bool blur = group.readEntry("SurfaceBlur", false);
    if (transparency != m_transparency || blur != m_blur) {
        m_transparency = transparency;
        m_blur = blur;
        Q_EMIT changed();
    }
}
