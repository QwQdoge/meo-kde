#include "dynamiccolorprovider.h"

#include "dynamiccolors.h"

#include <KConfigGroup>
#include <KSharedConfig>

namespace {
QColor parseConfiguredColor(const QString &serialized)
{
    const QStringList channels = serialized.split(',');
    if (channels.size() == 3) {
        bool redOk = false;
        bool greenOk = false;
        bool blueOk = false;
        const QColor parsed(channels.at(0).trimmed().toInt(&redOk),
                            channels.at(1).trimmed().toInt(&greenOk),
                            channels.at(2).trimmed().toInt(&blueOk));
        if (redOk && greenOk && blueOk && parsed.isValid()) {
            return parsed;
        }
    }
    return QColor(serialized);
}
}

DynamicColorProvider::DynamicColorProvider(QObject *parent)
    : QObject(parent)
{
}

QVariantMap DynamicColorProvider::schemeFor(const QColor &seed, bool dark) const
{
    return DynamicColors::qmlSchemeFor(seed, dark);
}

QColor DynamicColorProvider::currentSeed() const
{
    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    const KConfigGroup general(globals, QStringLiteral("General"));
    QColor seed = parseConfiguredColor(
        general.readEntry("MeoDynamicColorSeed", QString()));
    if (!seed.isValid()) {
        seed = parseConfiguredColor(general.readEntry("AccentColor", QString()));
    }
    return seed.isValid() ? seed : QColor::fromRgb(0x67, 0x50, 0xa4);
}

QVariantMap DynamicColorProvider::currentScheme(bool dark) const
{
    return schemeFor(currentSeed(), dark);
}

QString DynamicColorProvider::sourceId() const
{
    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    const QString source = KConfigGroup(globals, QStringLiteral("General"))
                               .readEntry("MeoDynamicColorSource", QStringLiteral("accent"))
                               .trimmed()
                               .toLower();
    if (source == QLatin1String("wallpaper") || source == QLatin1String("manual")
        || source == QLatin1String("accent")) {
        return source;
    }
    return QStringLiteral("accent");
}
