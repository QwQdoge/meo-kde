#pragma once

#include <QColor>
#include <QMap>
#include <QString>
#include <QVariantMap>

class DynamicColors final
{
public:
    using ColorScheme = QMap<QString, QColor>;

    // Generates the complete Material 3 role set from one KDE accent colour.
    // The implementation is the upstream HCT/CAM16 SchemeTonalSpot algorithm,
    // rather than RGB/HSL interpolation.
    static ColorScheme schemeFor(const QColor &seed, bool dark, qreal contrastLevel = 0.0);
    static QVariantMap qmlSchemeFor(const QColor &seed, bool dark, qreal contrastLevel = 0.0);

    // Converts the generated Material roles to the closest KDE colour-scheme
    // groups without inventing a second HSL palette.
    static bool writeScheme(const QString &path, const QString &name,
                            const ColorScheme &scheme, QString *error);
};
