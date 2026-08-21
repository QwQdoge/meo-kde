#include "dynamiccolors.h"

#include <KConfig>
#include <KConfigGroup>

#include <QDir>
#include <QFileInfo>
#include <QtGlobal>

#include "cpp/cam/hct.h"
#include "cpp/dynamiccolor/dynamic_scheme.h"
#include "cpp/scheme/scheme_tonal_spot.h"
#include "cpp/utils/utils.h"

namespace {
using material_color_utilities::Argb;
using material_color_utilities::Hct;
using material_color_utilities::SchemeTonalSpot;

constexpr auto fallbackRed = 0x67;
constexpr auto fallbackGreen = 0x50;
constexpr auto fallbackBlue = 0xa4;

QColor fromArgb(Argb argb)
{
    return QColor::fromRgb((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
}

Argb toArgb(const QColor &color)
{
    return material_color_utilities::ArgbFromRgb(color.red(), color.green(), color.blue());
}

QString encoded(const QColor &color)
{
    return QStringLiteral("%1,%2,%3").arg(color.red()).arg(color.green()).arg(color.blue());
}

QColor role(const DynamicColors::ColorScheme &scheme, const QString &name)
{
    const QColor value = scheme.value(name);
    return value.isValid() ? value : QColor::fromRgb(fallbackRed, fallbackGreen, fallbackBlue);
}

void writeColorSet(KConfig &config, const QString &name, const DynamicColors::ColorScheme &scheme,
                   const QColor &background, const QColor &alternate,
                   const QColor &foreground, const QColor &inactiveForeground,
                   const QColor &activeForeground)
{
    KConfigGroup group(&config, name);
    group.writeEntry("BackgroundNormal", encoded(background));
    group.writeEntry("BackgroundAlternate", encoded(alternate));
    group.writeEntry("ForegroundNormal", encoded(foreground));
    group.writeEntry("ForegroundInactive", encoded(inactiveForeground));
    group.writeEntry("ForegroundActive", encoded(activeForeground));
    group.writeEntry("ForegroundLink", encoded(role(scheme, QStringLiteral("primary"))));
    group.writeEntry("ForegroundVisited", encoded(role(scheme, QStringLiteral("tertiary"))));
    // Material 3 has an error role but no success/warning role. Keep KDE's
    // semantic slots legible by mapping neutral feedback to tonal roles and
    // failure feedback to the official Material error role.
    group.writeEntry("ForegroundPositive", encoded(role(scheme, QStringLiteral("tertiary"))));
    group.writeEntry("ForegroundNegative", encoded(role(scheme, QStringLiteral("error"))));
    group.writeEntry("ForegroundNeutral", encoded(role(scheme, QStringLiteral("outline"))));
    group.writeEntry("DecorationFocus", encoded(role(scheme, QStringLiteral("primary"))));
    group.writeEntry("DecorationHover", encoded(role(scheme, QStringLiteral("primary"))));
}

void insert(DynamicColors::ColorScheme &scheme, const QString &name, Argb value)
{
    scheme.insert(name, fromArgb(value));
}
}

DynamicColors::ColorScheme DynamicColors::schemeFor(const QColor &accent, bool dark, qreal contrastLevel)
{
    const QColor seed = accent.isValid() ? accent : QColor::fromRgb(fallbackRed, fallbackGreen, fallbackBlue);
    const SchemeTonalSpot scheme(Hct(toArgb(seed)), dark,
                                 qBound(-1.0, static_cast<double>(contrastLevel), 1.0));
    ColorScheme roles;

    insert(roles, QStringLiteral("sourceColor"), scheme.SourceColorArgb());
    insert(roles, QStringLiteral("primary"), scheme.GetPrimary());
    insert(roles, QStringLiteral("onPrimary"), scheme.GetOnPrimary());
    insert(roles, QStringLiteral("primaryContainer"), scheme.GetPrimaryContainer());
    insert(roles, QStringLiteral("onPrimaryContainer"), scheme.GetOnPrimaryContainer());
    insert(roles, QStringLiteral("inversePrimary"), scheme.GetInversePrimary());
    insert(roles, QStringLiteral("secondary"), scheme.GetSecondary());
    insert(roles, QStringLiteral("onSecondary"), scheme.GetOnSecondary());
    insert(roles, QStringLiteral("secondaryContainer"), scheme.GetSecondaryContainer());
    insert(roles, QStringLiteral("onSecondaryContainer"), scheme.GetOnSecondaryContainer());
    insert(roles, QStringLiteral("tertiary"), scheme.GetTertiary());
    insert(roles, QStringLiteral("onTertiary"), scheme.GetOnTertiary());
    insert(roles, QStringLiteral("tertiaryContainer"), scheme.GetTertiaryContainer());
    insert(roles, QStringLiteral("onTertiaryContainer"), scheme.GetOnTertiaryContainer());
    insert(roles, QStringLiteral("error"), scheme.GetError());
    insert(roles, QStringLiteral("onError"), scheme.GetOnError());
    insert(roles, QStringLiteral("errorContainer"), scheme.GetErrorContainer());
    insert(roles, QStringLiteral("onErrorContainer"), scheme.GetOnErrorContainer());
    insert(roles, QStringLiteral("background"), scheme.GetBackground());
    insert(roles, QStringLiteral("onBackground"), scheme.GetOnBackground());
    insert(roles, QStringLiteral("surface"), scheme.GetSurface());
    insert(roles, QStringLiteral("onSurface"), scheme.GetOnSurface());
    insert(roles, QStringLiteral("surfaceDim"), scheme.GetSurfaceDim());
    insert(roles, QStringLiteral("surfaceBright"), scheme.GetSurfaceBright());
    insert(roles, QStringLiteral("surfaceContainerLowest"), scheme.GetSurfaceContainerLowest());
    insert(roles, QStringLiteral("surfaceContainerLow"), scheme.GetSurfaceContainerLow());
    insert(roles, QStringLiteral("surfaceContainer"), scheme.GetSurfaceContainer());
    insert(roles, QStringLiteral("surfaceContainerHigh"), scheme.GetSurfaceContainerHigh());
    insert(roles, QStringLiteral("surfaceContainerHighest"), scheme.GetSurfaceContainerHighest());
    insert(roles, QStringLiteral("surfaceVariant"), scheme.GetSurfaceVariant());
    insert(roles, QStringLiteral("onSurfaceVariant"), scheme.GetOnSurfaceVariant());
    insert(roles, QStringLiteral("outline"), scheme.GetOutline());
    insert(roles, QStringLiteral("outlineVariant"), scheme.GetOutlineVariant());
    insert(roles, QStringLiteral("inverseSurface"), scheme.GetInverseSurface());
    insert(roles, QStringLiteral("onInverseSurface"), scheme.GetInverseOnSurface());
    insert(roles, QStringLiteral("shadow"), scheme.GetShadow());
    insert(roles, QStringLiteral("scrim"), scheme.GetScrim());
    insert(roles, QStringLiteral("surfaceTint"), scheme.GetSurfaceTint());
    insert(roles, QStringLiteral("primaryFixed"), scheme.GetPrimaryFixed());
    insert(roles, QStringLiteral("primaryFixedDim"), scheme.GetPrimaryFixedDim());
    insert(roles, QStringLiteral("onPrimaryFixed"), scheme.GetOnPrimaryFixed());
    insert(roles, QStringLiteral("onPrimaryFixedVariant"), scheme.GetOnPrimaryFixedVariant());
    insert(roles, QStringLiteral("secondaryFixed"), scheme.GetSecondaryFixed());
    insert(roles, QStringLiteral("secondaryFixedDim"), scheme.GetSecondaryFixedDim());
    insert(roles, QStringLiteral("onSecondaryFixed"), scheme.GetOnSecondaryFixed());
    insert(roles, QStringLiteral("onSecondaryFixedVariant"), scheme.GetOnSecondaryFixedVariant());
    insert(roles, QStringLiteral("tertiaryFixed"), scheme.GetTertiaryFixed());
    insert(roles, QStringLiteral("tertiaryFixedDim"), scheme.GetTertiaryFixedDim());
    insert(roles, QStringLiteral("onTertiaryFixed"), scheme.GetOnTertiaryFixed());
    insert(roles, QStringLiteral("onTertiaryFixedVariant"), scheme.GetOnTertiaryFixedVariant());
    return roles;
}

QVariantMap DynamicColors::qmlSchemeFor(const QColor &accent, bool dark, qreal contrastLevel)
{
    const ColorScheme scheme = schemeFor(accent, dark, contrastLevel);
    QVariantMap result;
    for (auto it = scheme.cbegin(); it != scheme.cend(); ++it) {
        result.insert(it.key(), it.value());
    }
    return result;
}

bool DynamicColors::writeScheme(const QString &path, const QString &name,
                                const ColorScheme &scheme, QString *error)
{
    const QFileInfo fileInfo(path);
    if (!QDir().mkpath(fileInfo.absolutePath())) {
        if (error) {
            *error = QStringLiteral("Cannot create color-scheme directory: %1").arg(fileInfo.absolutePath());
        }
        return false;
    }

    KConfig config(path, KConfig::SimpleConfig);
    KConfigGroup general(&config, "General");
    general.writeEntry("ColorScheme", name);
    general.writeEntry("Name", name);
    general.writeEntry("shadeSortColumn", true);

    writeColorSet(config, QStringLiteral("Colors:View"), scheme,
                  role(scheme, QStringLiteral("surface")),
                  role(scheme, QStringLiteral("surfaceContainerLow")),
                  role(scheme, QStringLiteral("onSurface")),
                  role(scheme, QStringLiteral("onSurfaceVariant")),
                  role(scheme, QStringLiteral("primary")));
    writeColorSet(config, QStringLiteral("Colors:Window"), scheme,
                  role(scheme, QStringLiteral("surface")),
                  role(scheme, QStringLiteral("surfaceContainer")),
                  role(scheme, QStringLiteral("onSurface")),
                  role(scheme, QStringLiteral("onSurfaceVariant")),
                  role(scheme, QStringLiteral("primary")));
    writeColorSet(config, QStringLiteral("Colors:Button"), scheme,
                  role(scheme, QStringLiteral("surfaceContainerLow")),
                  role(scheme, QStringLiteral("surfaceContainer")),
                  role(scheme, QStringLiteral("onSurface")),
                  role(scheme, QStringLiteral("onSurfaceVariant")),
                  role(scheme, QStringLiteral("primary")));
    writeColorSet(config, QStringLiteral("Colors:Header"), scheme,
                  role(scheme, QStringLiteral("surfaceContainer")),
                  role(scheme, QStringLiteral("surfaceContainerHigh")),
                  role(scheme, QStringLiteral("onSurface")),
                  role(scheme, QStringLiteral("onSurfaceVariant")),
                  role(scheme, QStringLiteral("primary")));
    writeColorSet(config, QStringLiteral("Colors:Selection"), scheme,
                  role(scheme, QStringLiteral("primary")),
                  role(scheme, QStringLiteral("primaryContainer")),
                  role(scheme, QStringLiteral("onPrimary")),
                  role(scheme, QStringLiteral("onPrimary")),
                  role(scheme, QStringLiteral("onPrimary")));
    writeColorSet(config, QStringLiteral("Colors:Complementary"), scheme,
                  role(scheme, QStringLiteral("inverseSurface")),
                  role(scheme, QStringLiteral("surfaceContainerHighest")),
                  role(scheme, QStringLiteral("onInverseSurface")),
                  role(scheme, QStringLiteral("onSurfaceVariant")),
                  role(scheme, QStringLiteral("inversePrimary")));

    KConfigGroup wm(&config, "WM");
    wm.writeEntry("activeBackground", encoded(role(scheme, QStringLiteral("surfaceContainer"))));
    wm.writeEntry("activeForeground", encoded(role(scheme, QStringLiteral("onSurface"))));
    wm.writeEntry("activeBlend", encoded(role(scheme, QStringLiteral("primary"))));
    wm.writeEntry("inactiveBackground", encoded(role(scheme, QStringLiteral("surfaceContainerLow"))));
    wm.writeEntry("inactiveForeground", encoded(role(scheme, QStringLiteral("onSurfaceVariant"))));
    wm.writeEntry("inactiveBlend", encoded(role(scheme, QStringLiteral("outline"))));

    if (!config.sync()) {
        if (error) {
            *error = QStringLiteral("Cannot write color scheme: %1").arg(path);
        }
        return false;
    }
    return true;
}
