#include "dynamiccolors.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QDir>
#include <QGuiApplication>
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
}

int main(int argc, char *argv[])
{
    // Applying a palette exports Qt/GTK compatibility settings through krdb,
    // which uses GUI primitives even though this is a command-line tool.
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meo-dynamic-colors"));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Generate a Material 3 KDE color scheme from the active KDE accent color."));
    parser.addHelpOption();
    QCommandLineOption accentOption({"a", "accent"},
                                     "Use an explicit KDE seed color (#RRGGBB or R,G,B).", "color");
    QCommandLineOption outputOption({"o", "output-dir"},
                                     "Directory for generated KDE .colors files.", "path");
    QCommandLineOption contrastOption("contrast",
                                      "Material contrast level from -1.0 to 1.0 (default: 0.0).", "level", "0.0");
    QCommandLineOption applyOption("apply", "Select the generated light or dark scheme in kdeglobals.");
    QCommandLineOption followOption("follow-meo",
                                    "Apply only while the active KDE scheme belongs to Meo.");
    QCommandLineOption darkOption("dark", "Generate/select the dark scheme.");
    parser.addOption(accentOption);
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

    const QColor accent = parser.isSet(accentOption) ? parseColor(parser.value(accentOption)) : configuredAccent();
    if (!accent.isValid()) {
        QTextStream(stderr) << "--accent must be #RRGGBB or R,G,B" << Qt::endl;
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

    if (parser.isSet(applyOption)) {
        if (!DynamicColors::applyScheme(schemePath, name, accent, true, nullptr, &error)) {
            QTextStream(stderr) << error << Qt::endl;
            return 1;
        }
    }
    QTextStream(stdout) << "MEO_DYNAMIC_COLORS accent=" << accent.name(QColor::HexRgb)
                        << " scheme=" << name << " contrast=" << contrast << Qt::endl;
    // krdb schedules its launch-environment update for the next event-loop
    // turn. Match plasma-apply-colorscheme so that update is not dropped.
    QTimer::singleShot(0, &app, [&app]() { app.exit(0); });
    return app.exec();
}
