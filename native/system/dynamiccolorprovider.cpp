#include "dynamiccolorprovider.h"

#include "dynamiccolors.h"

DynamicColorProvider::DynamicColorProvider(QObject *parent)
    : QObject(parent)
{
}

QVariantMap DynamicColorProvider::schemeFor(const QColor &seed, bool dark) const
{
    return DynamicColors::qmlSchemeFor(seed, dark);
}
