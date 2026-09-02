#include "dynamiccolors.h"
#include "dynamiccolorsource.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QDir>
#include <QGuiApplication>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>

namespace {
QColor parseColor(const QString &serialized)
{
    const QStringList channels = serialized.split(',');
    if (channels.size() == 3) {
        bool validRed = false;
        bool validGreen = false;
        bool validBlue = false;
        const QColor parsed(channels.at(0).trimmed().toInt(&validRed),
                            channels.at(1).trimmed().toInt(&validGreen),
                            channels.at(2).trimmed().toInt(&validBlue));
        if (validRed && validGreen && validBlue && parsed.isValid()) {
            return parsed;
        }
    }
    return QColor(serialized);
}

QColor configuredAccent()
{
    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    const QColor accent = parseColor(KConfigGroup(globals, "General").readEntry("AccentColor", QString()));
    if (accent.isValid()) {
        return accent;
    }
    const QColor selection = parseColor(KConfigGroup(globals, "Colors:Selection")
                                             .readEntry("BackgroundNormal", QString()));
    return selection.isValid() ? selection : QColor::fromRgb(0x67, 0x50, 0xa4);
}

bool isDarkScheme()
{
    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    return KConfigGroup(globals, "General").readEntry("ColorScheme", QString())
        .contains(QStringLiteral("Dark"), Qt::CaseInsensitive);
}

QString activeColorScheme()
{
    const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    return KConfigGroup(globals, "General").readEntry("ColorScheme", QString());
}

QString refreshManagedApplicationIcons()
{
    const QString studio = QStandardPaths::findExecutable(QStringLiteral("meo-app-icon-studio"));
    if (studio.isEmpty()) {
        return QStringLiteral("unavailable");
    }

    QProcess process;
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start(studio, {QStringLiteral("--apply"), QStringLiteral("--managed-only")});
    if (!process.waitForStarted(3000)) {
        return QStringLiteral("start-failed");
    }
    if (!process.waitForFinished(45000)) {
        process.kill();
        process.waitForFinished(3000);
        return QStringLiteral("timed-out");
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return QStringLiteral("failed");
    }
    return QStringLiteral("updated");
}
}

int main(int argc, char *argv[])
{
    // Applying a palette exports Qt/GTK compatibility settings through krdb,
    // which uses GUI primitives even though this is a command-line tool.
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-dynamic-colors"));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Generate a Material 3 KDE color scheme from a chosen Meo color source."));
    parser.addHelpOption();
    QCommandLineOption accentOption({"a", "accent"},
                                     "Use an explicit manual seed color (#RRGGBB or R,G,B).", "color");
    QCommandLineOption sourceOption({"s", "source"},
                                     "Seed source: accent, wallpaper, or manual. Defaults to the remembered source.",
                                     "source");
    QCommandLineOption wallpaperOption("wallpaper",
                                       "Use this local image instead of the configured wallpaper (wallpaper source only).",
                                       "path");
    QCommandLineOption rememberSourceOption("remember-source",
                                            "Save this source choice for future Meo dynamic color refreshes.");
    QCommandLineOption outputOption({"o", "output-dir"},
                                     "Directory for generated KDE .colors files.", "path");
    QCommandLineOption contrastOption("contrast",
                                      "Material contrast level from -1.0 to 1.0 (default: 0.0).", "level", "0.0");
    QCommandLineOption applyOption("apply", "Select the generated light or dark scheme in kdeglobals.");
    QCommandLineOption followOption("follow-meo",
                                    "Apply only while the active KDE scheme belongs to Meo.");
    QCommandLineOption darkOption("dark", "Generate/select the dark scheme.");
    parser.addOption(accentOption);
    parser.addOption(sourceOption);
    parser.addOption(wallpaperOption);
    parser.addOption(rememberSourceOption);
    parser.addOption(outputOption);
    parser.addOption(contrastOption);
    parser.addOption(applyOption);
    parser.addOption(followOption);
    parser.addOption(darkOption);
    parser.process(app);

    if (parser.isSet(followOption)
        && !activeColorScheme().startsWith(QStringLiteral("Meo"), Qt::CaseInsensitive)) {
        QTextStream(stdout) << "MEO_DYNAMIC_COLORS skipped=non-meo-scheme" << Qt::endl;
        return 0;
    }

    bool contrastOk = false;
    const qreal contrast = parser.value(contrastOption).toDouble(&contrastOk);
    if (!contrastOk || contrast < -1.0 || contrast > 1.0) {
        QTextStream(stderr) << "--contrast must be between -1.0 and 1.0" << Qt::endl;
        return 2;
    }

    const QColor explicitManualColor = parser.isSet(accentOption)
        ? parseColor(parser.value(accentOption)) : QColor();
    if (parser.isSet(accentOption) && !explicitManualColor.isValid()) {
        QTextStream(stderr) << "--accent must be #RRGGBB or R,G,B" << Qt::endl;
        return 2;
    }
    QString requestedSource = parser.isSet(sourceOption) ? parser.value(sourceOption) : QString();
    if (!parser.isSet(sourceOption) && parser.isSet(accentOption)) {
        // Preserve the historical `--accent` behavior while making the source
        // explicit for diagnostics and optional persistence.
        requestedSource = QStringLiteral("manual");
    }
    if (parser.isSet(wallpaperOption)
        && requestedSource.compare(QStringLiteral("wallpaper"), Qt::CaseInsensitive) != 0) {
        QTextStream(stderr) << "--wallpaper requires --source wallpaper" << Qt::endl;
        return 2;
    }
    if (parser.isSet(sourceOption)
        && !DynamicColorSource::isSupportedMode(requestedSource)) {
        QTextStream(stderr) << "--source must be accent, wallpaper, or manual" << Qt::endl;
        return 2;
    }
    if (parser.isSet(sourceOption)
        && requestedSource.compare(QStringLiteral("manual"), Qt::CaseInsensitive) != 0
        && parser.isSet(accentOption)) {
        QTextStream(stderr) << "--accent is only valid with --source manual" << Qt::endl;
        return 2;
    }

    QColor accent;
    QString resolvedSource;
    QString resolvedWallpaper;
    QString sourceError;
    if (!DynamicColorSource::resolve(requestedSource, configuredAccent(), explicitManualColor,
                                     parser.value(wallpaperOption), &accent, &resolvedSource,
                                     &resolvedWallpaper, &sourceError)) {
        QTextStream(stderr) << sourceError << Qt::endl;
        return 2;
    }
    const bool dark = parser.isSet(darkOption) || (!parser.isSet(darkOption) && isDarkScheme());
    const QString name = dark ? QStringLiteral("MeoDynamicDark") : QStringLiteral("MeoDynamicLight");
    const QString outputDir = parser.value(outputOption).isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/color-schemes")
        : QDir(parser.value(outputOption)).absolutePath();
    const auto scheme = DynamicColors::schemeFor(accent, dark, contrast);
    QString error;
    const QString schemePath = QDir(outputDir).filePath(name + QStringLiteral(".colors"));
    if (!DynamicColors::writeScheme(schemePath, name, scheme, &error)) {
        QTextStream(stderr) << error << Qt::endl;
        return 1;
    }

    QString applicationIconStatus;
    if (parser.isSet(applyOption)) {
        if (!DynamicColors::applyScheme(schemePath, name, accent, true, nullptr, &error,
                                        resolvedSource)) {
            QTextStream(stderr) << error << Qt::endl;
            return 1;
        }
        // Icons are private hicolor assets. A refresh failure must never
        // affect a desktop color scheme that has already been applied.
        applicationIconStatus = refreshManagedApplicationIcons();
    }
    if (parser.isSet(rememberSourceOption)
        && !DynamicColorSource::persist(resolvedSource,
                                        resolvedSource == QLatin1String("manual") ? accent : QColor(),
                                        &error)) {
        QTextStream(stderr) << error << Qt::endl;
        return 1;
    }
    QTextStream output(stdout);
    output << "MEO_DYNAMIC_COLORS source=" << resolvedSource
           << " accent=" << accent.name(QColor::HexRgb)
           << " scheme=" << name << " contrast=" << contrast;
    if (!applicationIconStatus.isEmpty()) {
        output << " app_icons=" << applicationIconStatus;
    }
    if (!resolvedWallpaper.isEmpty()) {
        output << " wallpaper=" << resolvedWallpaper;
    }
    output << Qt::endl;
    // krdb schedules its launch-environment update for the next event-loop
    // turn. Match plasma-apply-colorscheme so that update is not dropped.
    QTimer::singleShot(0, &app, [&app]() { app.exit(0); });
    return app.exec();
}
