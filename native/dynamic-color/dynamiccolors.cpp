#include "dynamiccolors.h"

#include <KConfig>
#include <KConfigBase>
#include <KConfigGroup>
#include <KSharedConfig>

#include <QCryptographicHash>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QTemporaryFile>
#include <QtGlobal>

#include <krdb.h>

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

QStringList sorted(QStringList values)
{
    values.sort();
    return values;
}

bool groupsMatch(const KConfigGroup &source, const KConfigGroup &target)
{
    if (sorted(source.keyList()) != sorted(target.keyList())
        || sorted(source.groupList()) != sorted(target.groupList())) {
        return false;
    }

    for (const QString &key : source.keyList()) {
        if (source.readEntry(key, QString()) != target.readEntry(key, QString())) {
            return false;
        }
    }
    for (const QString &name : source.groupList()) {
        if (!groupsMatch(source.group(name), target.group(name))) {
            return false;
        }
    }
    return true;
}

void copyGroup(const KConfigGroup &source, KConfigGroup &target,
               KConfigBase::WriteConfigFlags flags)
{
    for (const QString &key : source.keyList()) {
        target.writeEntry(key, source.readEntry(key, QString()), flags);
    }
    for (const QString &name : source.groupList()) {
        KConfigGroup sourceChild = source.group(name);
        KConfigGroup targetChild = target.group(name);
        copyGroup(sourceChild, targetChild, flags);
    }
}

bool writeIfChanged(KConfigGroup &group, const QString &key, const QString &value,
                    KConfigBase::WriteConfigFlags flags)
{
    if (group.readEntry(key, QString()) == value) {
        return false;
    }
    group.writeEntry(key, value, flags);
    return true;
}

void beginPaletteTransition(const KSharedConfigPtr &globals)
{
    const qreal factor = KConfigGroup(globals, QStringLiteral("KDE"))
                             .readEntry(QStringLiteral("AnimationDurationFactor"), 1.0);
    const int duration = qRound(300 * qBound(0.0, factor, 4.0));
    if (duration <= 0 || !QDBusConnection::sessionBus().isConnected()) {
        return;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/org/kde/KWin/BlendChanges"),
        QStringLiteral("org.kde.KWin.BlendChanges"), QStringLiteral("start"));
    message << duration;
    QDBusConnection::sessionBus().call(message, QDBus::Block, 1000);
}

void notifyPaletteChanged()
{
    if (!QDBusConnection::sessionBus().isConnected()) {
        return;
    }
    QDBusMessage message = QDBusMessage::createSignal(
        QStringLiteral("/KGlobalSettings"), QStringLiteral("org.kde.KGlobalSettings"),
        QStringLiteral("notifyChange"));
    // KGlobalSettings/KHintSettings PaletteChanged = 0.
    message.setArguments({0, 0});
    QDBusConnection::sessionBus().send(message);
}

void exportCompatibilityPalettes()
{
    KConfig displayConfig(QStringLiteral("kcmdisplayrc"), KConfig::NoGlobals);
    const bool exportKdeColors = KConfigGroup(&displayConfig, QStringLiteral("X11"))
                                     .readEntry(QStringLiteral("exportKDEColors"), true);
    runRdb(KRdbExportQtColors | KRdbExportGtkTheme
           | (exportKdeColors ? KRdbExportColors : 0));
}

void writeColorEntries(KConfigGroup &group, const DynamicColors::ColorScheme &scheme,
                       const QColor &background, const QColor &alternate,
                       const QColor &foreground, const QColor &inactiveForeground,
                       const QColor &activeForeground)
{
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

void writeColorSet(KConfig &config, const QString &name, const DynamicColors::ColorScheme &scheme,
                   const QColor &background, const QColor &alternate,
                   const QColor &foreground, const QColor &inactiveForeground,
                   const QColor &activeForeground)
{
    KConfigGroup group(&config, name);
    writeColorEntries(group, scheme, background, alternate, foreground,
                      inactiveForeground, activeForeground);
}

void writeInactiveHeader(KConfig &config, const DynamicColors::ColorScheme &scheme)
{
    KConfigGroup header(&config, QStringLiteral("Colors:Header"));
    KConfigGroup inactive(&header, QStringLiteral("Inactive"));
    writeColorEntries(inactive, scheme,
                      role(scheme, QStringLiteral("surfaceContainerLow")),
                      role(scheme, QStringLiteral("surfaceContainer")),
                      role(scheme, QStringLiteral("onSurfaceVariant")),
                      role(scheme, QStringLiteral("outline")),
                      role(scheme, QStringLiteral("primary")));
}

void writeColorEffects(KConfig &config, const DynamicColors::ColorScheme &scheme)
{
    KConfigGroup disabled(&config, QStringLiteral("ColorEffects:Disabled"));
    disabled.writeEntry("Color", encoded(role(scheme, QStringLiteral("onSurfaceVariant"))));
    disabled.writeEntry("ColorAmount", 0);
    disabled.writeEntry("ColorEffect", 0);
    disabled.writeEntry("ContrastAmount", 0.65);
    disabled.writeEntry("ContrastEffect", 1);
    disabled.writeEntry("IntensityAmount", 0.1);
    disabled.writeEntry("IntensityEffect", 2);

    KConfigGroup inactive(&config, QStringLiteral("ColorEffects:Inactive"));
    inactive.writeEntry("ChangeSelectionColor", true);
    inactive.writeEntry("Color", encoded(role(scheme, QStringLiteral("onSurfaceVariant"))));
    inactive.writeEntry("ColorAmount", 0.025);
    inactive.writeEntry("ColorEffect", 2);
    inactive.writeEntry("ContrastAmount", 0.1);
    inactive.writeEntry("ContrastEffect", 2);
    inactive.writeEntry("Enable", false);
    inactive.writeEntry("IntensityAmount", 0);
    inactive.writeEntry("IntensityEffect", 0);
}

void writeMaterialRoles(KConfig &config, const DynamicColors::ColorScheme &scheme)
{
    // KDE's standard color sets cannot represent every paired Material role.
    // Keep the subset consumed by non-Qt integrations in one explicit group so
    // they never have to infer on-container colors from unrelated KDE slots.
    KConfigGroup material(&config, QStringLiteral("MeoMaterial"));
    for (const QString &name : {
             QStringLiteral("surfaceContainer"),
             QStringLiteral("onSurface"),
             QStringLiteral("primary"),
             QStringLiteral("onPrimary"),
             QStringLiteral("primaryContainer"),
             QStringLiteral("onPrimaryContainer"),
             QStringLiteral("secondaryContainer"),
             QStringLiteral("onSecondaryContainer"),
             QStringLiteral("onSurfaceVariant"),
             QStringLiteral("outline"),
         }) {
        material.writeEntry(name, encoded(role(scheme, name)));
    }
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

    QTemporaryFile temporary(QDir(fileInfo.absolutePath()).filePath(QStringLiteral(".meo-colors-XXXXXX")));
    if (!temporary.open()) {
        if (error) {
            *error = QStringLiteral("Cannot create temporary color scheme beside: %1").arg(path);
        }
        return false;
    }
    const QString temporaryPath = temporary.fileName();
    temporary.close();

    {
        KConfig config(temporaryPath, KConfig::SimpleConfig);
        KConfigGroup general(&config, "General");
        general.writeEntry("ColorScheme", name);
        general.writeEntry("Name", name);
        general.writeEntry("shadeSortColumn", true);

        writeColorEffects(config, scheme);
        writeMaterialRoles(config, scheme);

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
        writeInactiveHeader(config, scheme);
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
        writeColorSet(config, QStringLiteral("Colors:Tooltip"), scheme,
                      role(scheme, QStringLiteral("surfaceContainerHigh")),
                      role(scheme, QStringLiteral("surfaceContainerHighest")),
                      role(scheme, QStringLiteral("onSurface")),
                      role(scheme, QStringLiteral("onSurfaceVariant")),
                      role(scheme, QStringLiteral("primary")));

        KConfigGroup kde(&config, QStringLiteral("KDE"));
        kde.writeEntry("contrast", 4);
        kde.writeEntry("frameContrast", 0.2);

        KConfigGroup wm(&config, "WM");
        wm.writeEntry("activeBackground", encoded(role(scheme, QStringLiteral("surfaceContainer"))));
        wm.writeEntry("activeForeground", encoded(role(scheme, QStringLiteral("onSurface"))));
        wm.writeEntry("activeBlend", encoded(role(scheme, QStringLiteral("primary"))));
        wm.writeEntry("inactiveBackground", encoded(role(scheme, QStringLiteral("surfaceContainerLow"))));
        wm.writeEntry("inactiveForeground", encoded(role(scheme, QStringLiteral("onSurfaceVariant"))));
        wm.writeEntry("inactiveBlend", encoded(role(scheme, QStringLiteral("outline"))));

        if (!config.sync()) {
            if (error) {
                *error = QStringLiteral("Cannot render color scheme: %1").arg(path);
            }
            return false;
        }
    }

    QFile renderedFile(temporaryPath);
    if (!renderedFile.open(QIODevice::ReadOnly)) {
        if (error) {
            *error = QStringLiteral("Cannot read rendered color scheme: %1").arg(temporaryPath);
        }
        return false;
    }
    const QByteArray rendered = renderedFile.readAll();
    QFile existingFile(path);
    if (existingFile.open(QIODevice::ReadOnly) && existingFile.readAll() == rendered) {
        return true;
    }

    QSaveFile destination(path);
    if (!destination.open(QIODevice::WriteOnly)
        || destination.write(rendered) != rendered.size()
        || !destination.commit()) {
        if (error) {
            *error = QStringLiteral("Cannot atomically write color scheme: %1").arg(path);
        }
        return false;
    }
    return true;
}

bool DynamicColors::applyScheme(const QString &path, const QString &name,
                                const QColor &accent, bool notifySession,
                                bool *changed, QString *error)
{
    if (changed) {
        *changed = false;
    }
    if (!QFileInfo::exists(path)) {
        if (error) {
            *error = QStringLiteral("Cannot apply missing color scheme: %1").arg(path);
        }
        return false;
    }

    KConfig source(path, KConfig::SimpleConfig);
    const QStringList replacedGroups = {
        QStringLiteral("ColorEffects:Disabled"),
        QStringLiteral("ColorEffects:Inactive"),
        QStringLiteral("Colors:Button"),
        QStringLiteral("Colors:Complementary"),
        QStringLiteral("Colors:Header"),
        QStringLiteral("Colors:Selection"),
        QStringLiteral("Colors:Tooltip"),
        QStringLiteral("Colors:View"),
        QStringLiteral("Colors:Window"),
        QStringLiteral("MeoMaterial"),
    };
    for (const QString &groupName : replacedGroups) {
        KConfigGroup sourceGroup(&source, groupName);
        if (!sourceGroup.exists()) {
            if (error) {
                *error = QStringLiteral("Generated scheme is missing required group: %1").arg(groupName);
            }
            return false;
        }
    }

    const QStringList wmKeys = {
        QStringLiteral("activeBackground"),
        QStringLiteral("activeForeground"),
        QStringLiteral("inactiveBackground"),
        QStringLiteral("inactiveForeground"),
        QStringLiteral("activeBlend"),
        QStringLiteral("inactiveBlend"),
    };
    KConfigGroup sourceWm(&source, QStringLiteral("WM"));
    for (const QString &key : wmKeys) {
        if (!sourceWm.hasKey(key)) {
            if (error) {
                *error = QStringLiteral("Generated scheme is missing required WM key: %1").arg(key);
            }
            return false;
        }
    }

    KConfigGroup sourceKde(&source, QStringLiteral("KDE"));
    for (const QString &key : {QStringLiteral("contrast"), QStringLiteral("frameContrast")}) {
        if (!sourceKde.hasKey(key)) {
            if (error) {
                *error = QStringLiteral("Generated scheme is missing required KDE key: %1").arg(key);
            }
            return false;
        }
    }

    QFile schemeFile(path);
    if (!schemeFile.open(QIODevice::ReadOnly)) {
        if (error) {
            *error = QStringLiteral("Cannot hash generated color scheme: %1").arg(path);
        }
        return false;
    }
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(schemeFile.readAll(), QCryptographicHash::Sha1).toHex());

    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    if (!globals->isConfigWritable(false)) {
        if (error) {
            *error = QStringLiteral("Cannot write kdeglobals");
        }
        return false;
    }
    const KConfigBase::WriteConfigFlags writeFlags = notifySession
        ? KConfigBase::WriteConfigFlags(KConfigBase::Notify)
        : KConfigBase::WriteConfigFlags(KConfigBase::Normal);
    bool dirty = false;

    for (const QString &groupName : replacedGroups) {
        KConfigGroup sourceGroup(&source, groupName);
        KConfigGroup targetGroup(globals, groupName);
        if (groupsMatch(sourceGroup, targetGroup)) {
            continue;
        }
        targetGroup.deleteGroup(writeFlags);
        copyGroup(sourceGroup, targetGroup, writeFlags);
        dirty = true;
    }

    KConfigGroup targetWm(globals, QStringLiteral("WM"));
    for (const QString &key : wmKeys) {
        dirty = writeIfChanged(targetWm, key, sourceWm.readEntry(key, QString()), writeFlags) || dirty;
    }

    KConfigGroup targetKde(globals, QStringLiteral("KDE"));
    for (const QString &key : {QStringLiteral("contrast"), QStringLiteral("frameContrast")}) {
        dirty = writeIfChanged(targetKde, key, sourceKde.readEntry(key, QString()), writeFlags) || dirty;
    }

    const QString encodedAccent = encoded(accent);
    KConfigGroup general(globals, QStringLiteral("General"));
    dirty = writeIfChanged(general, QStringLiteral("ColorScheme"), name, writeFlags) || dirty;
    dirty = writeIfChanged(general, QStringLiteral("ColorSchemeHash"), hash, writeFlags) || dirty;
    dirty = writeIfChanged(general, QStringLiteral("AccentColor"), encodedAccent, writeFlags) || dirty;

    if (!dirty) {
        return true;
    }
    if (notifySession) {
        beginPaletteTransition(globals);
    }
    if (!globals->sync()) {
        // KConfig normally retries dirty writes from its destructor. Do not
        // turn an explicitly reported failure into a later partial write.
        globals->markAsClean();
        if (error) {
            *error = QStringLiteral("Cannot project generated scheme into kdeglobals");
        }
        return false;
    }
    if (notifySession) {
        exportCompatibilityPalettes();
        notifyPaletteChanged();
    }
    if (changed) {
        *changed = true;
    }
    return true;
}
