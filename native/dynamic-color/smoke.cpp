#include "dynamiccolors.h"
#include "dynamiccolorsource.h"

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QTemporaryDir>
#include <QTextStream>
#include <QTimer>
#include <QUrl>

namespace {
bool hasColor(const DynamicColors::ColorScheme &scheme, const QString &role, const QString &expected)
{
    return scheme.value(role).name(QColor::HexRgb).compare(expected, Qt::CaseInsensitive) == 0;
}

QByteArray contents(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}
}

int main(int argc, char *argv[])
{
    QTemporaryDir configDirectory;
    if (!configDirectory.isValid()) {
        return 1;
    }
    qputenv("XDG_CONFIG_HOME", configDirectory.path().toUtf8());
    qputenv("XDG_DATA_HOME", configDirectory.filePath(QStringLiteral("data")).toUtf8());
    qputenv("XDG_CACHE_HOME", configDirectory.filePath(QStringLiteral("cache")).toUtf8());
    qputenv("XDG_RUNTIME_DIR", configDirectory.path().toUtf8());
    qputenv("HOME", configDirectory.path().toUtf8());
    qputenv("QT_QPA_PLATFORM", "offscreen");
    // Never let krdb's X11 or launch-environment compatibility paths contact
    // the user's actual XWayland or session D-Bus endpoints.
    qunsetenv("DISPLAY");
    qunsetenv("WAYLAND_DISPLAY");
    qunsetenv("XAUTHORITY");
    qunsetenv("GTK_RC_FILES");
    qunsetenv("GTK2_RC_FILES");
    qputenv("DBUS_SESSION_BUS_ADDRESS",
            "unix:path=/nonexistent/meo-dynamic-colors-smoke-session-bus");
    qunsetenv("DBUS_STARTER_ADDRESS");
    QGuiApplication app(argc, argv);
    const QString globalsPath = configDirectory.filePath(QStringLiteral("kdeglobals"));
    {
        KConfig initialGlobals(globalsPath, KConfig::SimpleConfig);
        KConfigGroup(&initialGlobals, QStringLiteral("WM"))
            .writeEntry(QStringLiteral("activeFont"), QStringLiteral("Preserved Font,10"));
        KConfigGroup(&initialGlobals, QStringLiteral("KDE"))
            .writeEntry(QStringLiteral("AnimationDurationFactor"), 0.0);
        KConfigGroup(&initialGlobals, QStringLiteral("General"))
            .writeEntry(QStringLiteral("MeoSmokeSentinel"), QStringLiteral("preserve"));
        if (!initialGlobals.sync()) {
            return 1;
        }
    }

    // Source selection is deliberately testable without a real Plasma
    // session.  The wallpaper resolver reads one configured local image, and
    // persisted manual choice never becomes a second palette algorithm.
    const QString wallpaperPath = configDirectory.filePath(QStringLiteral("wallpaper.png"));
    QImage wallpaper(16, 16, QImage::Format_RGBA8888);
    wallpaper.fill(QColor(QStringLiteral("#4285f4")));
    if (!wallpaper.save(wallpaperPath)) {
        return 1;
    }
    {
        KConfig desktop(configDirectory.filePath(QStringLiteral("plasma-org.kde.plasma.desktop-appletsrc")),
                        KConfig::SimpleConfig);
        KConfigGroup containments(&desktop, QStringLiteral("Containments"));
        KConfigGroup containment(&containments, QStringLiteral("1"));
        containment.writeEntry("wallpaperplugin", QStringLiteral("org.kde.image"));
        KConfigGroup wallpaperGroup(&containment,
                                     QStringLiteral("/Wallpaper/org.kde.image/General"));
        wallpaperGroup.writeEntry("Image", QUrl::fromLocalFile(wallpaperPath).toString());
        if (!desktop.sync()) {
            return 1;
        }
    }
    QString sourceError;
    if (DynamicColorSource::configuredWallpaperPath(&sourceError) != wallpaperPath
        || DynamicColorSource::seedFromWallpaper(wallpaperPath, &sourceError)
               != QColor(QStringLiteral("#4285f4"))
        || !DynamicColorSource::persist(QStringLiteral("manual"), QColor(QStringLiteral("#6750a4")),
                                        &sourceError)
        || DynamicColorSource::configuredMode() != QStringLiteral("manual")
        || DynamicColorSource::configuredManualColor() != QColor(QStringLiteral("#6750a4"))) {
        QTextStream(stderr) << "Dynamic color source storage/resolution failed: " << sourceError << Qt::endl;
        return 1;
    }
    QColor resolvedSeed;
    QString resolvedSource;
    QString resolvedWallpaper;
    if (!DynamicColorSource::resolve(QString(), QColor(QStringLiteral("#ff0000")), QColor(), QString(),
                                     &resolvedSeed, &resolvedSource, &resolvedWallpaper, &sourceError)
        || resolvedSource != QStringLiteral("manual")
        || resolvedSeed != QColor(QStringLiteral("#6750a4"))
        || !DynamicColorSource::resolve(QStringLiteral("wallpaper"), QColor(), QColor(), QString(),
                                        &resolvedSeed, &resolvedSource, &resolvedWallpaper, &sourceError)
        || resolvedSource != QStringLiteral("wallpaper")
        || resolvedSeed != QColor(QStringLiteral("#4285f4"))
        || resolvedWallpaper != wallpaperPath) {
        QTextStream(stderr) << "Dynamic color source did not resolve a stable seed: " << sourceError << Qt::endl;
        return 1;
    }
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
    if (!file.open(QIODevice::ReadOnly)) {
        return 1;
    }
    const QByteArray generated = file.readAll();
    for (const QByteArray section : {
             QByteArray("[ColorEffects:Disabled]"),
             QByteArray("[ColorEffects:Inactive]"),
             QByteArray("[Colors:Header][Inactive]"),
             QByteArray("[Colors:Selection]"),
             QByteArray("[Colors:Tooltip]"),
             QByteArray("[KDE]"),
             QByteArray("[MeoMaterial]"),
         }) {
        if (!generated.contains(section)) {
            QTextStream(stderr) << "Generated KDE scheme is missing " << section << Qt::endl;
            return 1;
        }
    }
    if (!generated.contains("frameContrast=0.2")) {
        QTextStream(stderr) << "Generated KDE scheme is missing frameContrast." << Qt::endl;
        return 1;
    }
    bool changed = false;
    if (!DynamicColors::applyScheme(path, QStringLiteral("MeoDynamicLight"), seed,
                                    true, &changed, &error)
        || !changed) {
        QTextStream(stderr) << "Generated scheme was not projected into kdeglobals: " << error << Qt::endl;
        return 1;
    }
    KConfig globals(QStringLiteral("kdeglobals"));
    for (const QString &group : {
             QStringLiteral("Colors:Button"),
             QStringLiteral("Colors:Header"),
             QStringLiteral("Colors:Tooltip"),
             QStringLiteral("MeoMaterial"),
         }) {
        if (!globals.hasGroup(group)) {
            QTextStream(stderr) << "Applied kdeglobals is missing " << group << Qt::endl;
            return 1;
        }
    }
    if (KConfigGroup(&globals, QStringLiteral("General"))
            .readEntry(QStringLiteral("ColorScheme"), QString()) != QStringLiteral("MeoDynamicLight")) {
        return 1;
    }
    if (KConfigGroup(&globals, QStringLiteral("WM"))
            .readEntry(QStringLiteral("activeFont"), QString()) != QStringLiteral("Preserved Font,10")
        || KConfigGroup(&globals, QStringLiteral("KDE"))
               .readEntry(QStringLiteral("frameContrast"), -1.0) != 0.2
        || KConfigGroup(&globals, QStringLiteral("General"))
               .readEntry(QStringLiteral("MeoSmokeSentinel"), QString()) != QStringLiteral("preserve")) {
        QTextStream(stderr) << "Applying colors replaced an unmanaged kdeglobals value." << Qt::endl;
        return 1;
    }
    changed = true;
    if (!DynamicColors::applyScheme(path, QStringLiteral("MeoDynamicLight"), seed,
                                    false, &changed, &error)
        || changed) {
        QTextStream(stderr) << "Repeated scheme application was not idempotent: " << error << Qt::endl;
        return 1;
    }

    const QByteArray beforeBrokenApply = contents(globalsPath);
    const QString brokenPath = directory.filePath(QStringLiteral("MeoBroken.colors"));
    if (!QFile::copy(path, brokenPath)) {
        return 1;
    }
    {
        KConfig broken(brokenPath, KConfig::SimpleConfig);
        broken.deleteGroup(QStringLiteral("Colors:Tooltip"));
        if (!broken.sync()) {
            return 1;
        }
    }
    changed = true;
    if (DynamicColors::applyScheme(brokenPath, QStringLiteral("MeoBroken"), seed,
                                   false, &changed, &error)
        || changed || contents(globalsPath) != beforeBrokenApply) {
        QTextStream(stderr) << "A broken scheme caused a partial kdeglobals write." << Qt::endl;
        return 1;
    }

    const QColor secondSeed = QColor::fromRgb(0x00, 0x78, 0xd4);
    const auto secondLight = DynamicColors::schemeFor(secondSeed, false);
    if (!DynamicColors::writeScheme(path, QStringLiteral("MeoDynamicLight"), secondLight, &error)) {
        return 1;
    }
    const QString firstWindow = KConfigGroup(&globals, QStringLiteral("Colors:Window"))
                                    .readEntry(QStringLiteral("BackgroundAlternate"), QString());
    changed = false;
    if (!DynamicColors::applyScheme(path, QStringLiteral("MeoDynamicLight"), secondSeed,
                                    false, &changed, &error, QStringLiteral("wallpaper"))
        || !changed) {
        return 1;
    }
    globals.reparseConfiguration();
    if (KConfigGroup(&globals, QStringLiteral("Colors:Window"))
            .readEntry(QStringLiteral("BackgroundAlternate"), QString()) == firstWindow) {
        QTextStream(stderr) << "A second wallpaper seed did not update concrete KDE colors." << Qt::endl;
        return 1;
    }
    if (KConfigGroup(&globals, QStringLiteral("General"))
            .readEntry(QStringLiteral("MeoDynamicColorSource"), QString()) != QStringLiteral("wallpaper")) {
        QTextStream(stderr) << "Applied scheme did not retain dynamic source metadata." << Qt::endl;
        return 1;
    }
    QTextStream(stdout) << "MEO_DYNAMIC_COLORS_SMOKE primary="
                        << light.value(QStringLiteral("primary")).name(QColor::HexRgb) << Qt::endl;
    QTimer::singleShot(0, &app, [&app]() { app.exit(0); });
    return app.exec();
}
