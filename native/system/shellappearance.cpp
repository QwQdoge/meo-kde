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
    const double transparencyLevel = qBound(25, group.readEntry("TransparencyLevel", 100), 200) / 100.0;
    const double cornerScale = qBound(0, group.readEntry("CornerScale", 100), 150) / 100.0;
    if (transparency != m_transparency || blur != m_blur
        || !qFuzzyCompare(transparencyLevel, m_transparencyLevel)
        || !qFuzzyCompare(cornerScale + 1.0, m_cornerScale + 1.0)) {
        m_transparency = transparency;
        m_blur = blur;
        m_transparencyLevel = transparencyLevel;
        m_cornerScale = cornerScale;
        Q_EMIT changed();
    }
}
