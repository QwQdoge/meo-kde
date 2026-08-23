#include "dynamiccolorprovider.h"

#include "dynamiccolors.h"

#include <KConfigGroup>
#include <KSharedConfig>

DynamicColorProvider::DynamicColorProvider(QObject *parent)
    : QObject(parent)
{
}

QVariantMap DynamicColorProvider::schemeFor(const QColor &seed, bool dark) const
{
    return DynamicColors::qmlSchemeFor(seed, dark);
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
