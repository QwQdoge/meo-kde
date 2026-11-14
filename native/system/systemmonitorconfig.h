#pragma once

#include <KConfigGroup>
#include <KConfigWatcher>
#include <KSharedConfig>
#include <QtGlobal>

// Shared sampling preference of the Meo system monitor (task manager,
// performance dashboard and widget). Stored in `meosystemmonitorrc`:
//
//   [General]
//   RefreshIntervalMs=2000     500-10000
//
// The monitor and Meo Settings both write it; every running Performance and
// Tasks provider follows through KConfigWatcher.
namespace MeoSystemMonitorConfig
{
inline constexpr int DefaultRefreshIntervalMs = 2000;
inline constexpr int MinimumRefreshIntervalMs = 500;
inline constexpr int MaximumRefreshIntervalMs = 10000;

inline KSharedConfig::Ptr config()
{
    return KSharedConfig::openConfig(QStringLiteral("meosystemmonitorrc"), KConfig::SimpleConfig);
}

inline int boundedInterval(int interval)
{
    return qBound(MinimumRefreshIntervalMs, interval, MaximumRefreshIntervalMs);
}

inline int readRefreshInterval()
{
    auto shared = config();
    shared->reparseConfiguration();
    const KConfigGroup group(shared, QStringLiteral("General"));
    return boundedInterval(group.readEntry("RefreshIntervalMs", DefaultRefreshIntervalMs));
}

inline void writeRefreshInterval(int interval)
{
    KConfigGroup group(config(), QStringLiteral("General"));
    if (group.readEntry("RefreshIntervalMs", DefaultRefreshIntervalMs) == interval) {
        return;
    }
    group.writeEntry("RefreshIntervalMs", interval, KConfig::Notify);
    group.sync();
}

inline KConfigWatcher::Ptr watcher()
{
    return KConfigWatcher::create(config());
}
} // namespace MeoSystemMonitorConfig
