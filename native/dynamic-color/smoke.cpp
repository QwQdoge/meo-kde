#include "dynamiccolors.h"

#include <QCoreApplication>
#include <QFile>
#include <QTemporaryDir>
#include <QTextStream>

namespace {
bool hasColor(const DynamicColors::ColorScheme &scheme, const QString &role, const QString &expected)
{
    return scheme.value(role).name(QColor::HexRgb).compare(expected, Qt::CaseInsensitive) == 0;
}
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const QColor seed = QColor::fromRgb(0x67, 0x50, 0xa4);
    const auto light = DynamicColors::schemeFor(seed, false);
    const auto dark = DynamicColors::schemeFor(seed, true);

    // Reference values from the upstream Material Color Utilities
    // SchemeTonalSpot implementation at the vendored commit.
    if (!hasColor(light, QStringLiteral("primary"), QStringLiteral("#65558f"))
        || !hasColor(light, QStringLiteral("primaryContainer"), QStringLiteral("#e9ddff"))
        || !hasColor(light, QStringLiteral("surfaceContainer"), QStringLiteral("#f2ecf4"))
        || !hasColor(dark, QStringLiteral("primary"), QStringLiteral("#cfbdfe"))
        || !hasColor(dark, QStringLiteral("onSurface"), QStringLiteral("#e6e0e9"))) {
        QTextStream(stderr) << "Material 3 role generation did not match SchemeTonalSpot." << Qt::endl;
        return 1;
    }

    const QVariantMap qmlScheme = DynamicColors::qmlSchemeFor(seed, false);
    if (qmlScheme.value(QStringLiteral("onPrimaryFixed")).value<QColor>()
            != light.value(QStringLiteral("onPrimaryFixed"))
        || !qmlScheme.contains(QStringLiteral("surfaceContainerHighest"))) {
        QTextStream(stderr) << "QML role map is incomplete." << Qt::endl;
        return 1;
    }

    QTemporaryDir directory;
    if (!directory.isValid()) {
        return 1;
    }
    const QString path = directory.filePath(QStringLiteral("MeoDynamicLight.colors"));
    QString error;
    if (!DynamicColors::writeScheme(path, QStringLiteral("MeoDynamicLight"), light, &error)) {
        QTextStream(stderr) << error << Qt::endl;
        return 1;
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)
        || !file.readAll().contains("[Colors:Selection]")) {
        return 1;
    }
    QTextStream(stdout) << "MEO_DYNAMIC_COLORS_SMOKE primary="
                        << light.value(QStringLiteral("primary")).name(QColor::HexRgb) << Qt::endl;
    return 0;
}
