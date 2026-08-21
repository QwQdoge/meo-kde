#include "dynamiccolors.h"

#include <KConfigBase>
#include <KConfigGroup>
#include <KSharedConfig>

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>
#include <QTextStream>

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
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
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
    QCommandLineOption darkOption("dark", "Generate/select the dark scheme.");
    parser.addOption(accentOption);
    parser.addOption(outputOption);
    parser.addOption(contrastOption);
    parser.addOption(applyOption);
    parser.addOption(darkOption);
    parser.process(app);

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
    if (!DynamicColors::writeScheme(QDir(outputDir).filePath(name + QStringLiteral(".colors")), name, scheme, &error)) {
        QTextStream(stderr) << error << Qt::endl;
        return 1;
    }

    if (parser.isSet(applyOption)) {
        const auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
        KConfigGroup general(globals, "General");
        general.writeEntry("ColorScheme", name, KConfigBase::Notify);
        general.writeEntry("AccentColor", QStringLiteral("%1,%2,%3").arg(accent.red()).arg(accent.green()).arg(accent.blue()),
                           KConfigBase::Notify);
        globals->sync();
    }
    QTextStream(stdout) << "MEO_DYNAMIC_COLORS accent=" << accent.name(QColor::HexRgb)
                        << " scheme=" << name << " contrast=" << contrast << Qt::endl;
    return 0;
}
