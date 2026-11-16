#include "meostyleenvironment.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QEvent>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QFileSystemWatcher>
#include <QtCore/QPointer>
#include <QtCore/QStandardPaths>
#include <QtCore/QTextStream>
#include <QtWidgets/QApplication>
#include <QtWidgets/QWidget>

#include <cmath>

namespace {

const QString kGlobals = QStringLiteral("kdeglobals");
const QString kShell = QStringLiteral("meo-shellrc");

QString configPath(const QString &name)
{
    // XDG_CONFIG_HOME is the Meo session's own configuration home.
    const QString local = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)).filePath(name);
    if (QFileInfo::exists(local)) return local;
    return QStandardPaths::locate(QStandardPaths::GenericConfigLocation, name);
}

// Minimal KConfig reader for one group: MeoStyle links only Qt.
QHash<QString, QString> readGroup(const QString &path, const QString &group)
{
    QHash<QString, QString> entries;
    QFile file(path);
    if (path.isEmpty() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) return entries;
    QTextStream stream(&file);
    bool inside = false;
    const QString header = QLatin1Char('[') + group + QLatin1Char(']');
    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.startsWith(QLatin1Char('['))) { inside = line == header; continue; }
        if (!inside || line.isEmpty() || line.startsWith(QLatin1Char('#'))) continue;
        const int equals = line.indexOf(QLatin1Char('='));
        if (equals <= 0) continue;
        QString key = line.left(equals).trimmed();
        if (key.endsWith(QLatin1String("[$e]")) || key.endsWith(QLatin1String("[$i]"))) key.chop(4);
        entries.insert(key, line.mid(equals + 1).trimmed());
    }
    return entries;
}

QColor parseColor(const QString &value)
{
    const QStringList parts = value.split(QLatin1Char(','));
    if (parts.size() != 3) return QColor(value);
    bool ok[3] = {};
    const QColor color(parts[0].trimmed().toInt(&ok[0]), parts[1].trimmed().toInt(&ok[1]), parts[2].trimmed().toInt(&ok[2]));
    return ok[0] && ok[1] && ok[2] ? color : QColor();
}

class Environment final : public QObject
{
public:
    Environment()
        : QObject(QCoreApplication::instance())
    {
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Environment::changed);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Environment::changed);
        if (QCoreApplication::instance()) QCoreApplication::instance()->installEventFilter(this);
        load();
    }

    QHash<QString, QColor> roles;
    qreal cornerScale = 1.0;

    bool eventFilter(QObject *watched, QEvent *event) override
    {
        // A KDE colour-scheme change reaches running applications as a new
        // palette; re-read the roles generated for it.
        if (watched == QCoreApplication::instance() && event->type() == QEvent::ApplicationPaletteChange)
            load();
        return false;
    }

private:
    void load()
    {
        QHash<QString, QColor> nextRoles;
        const auto material = readGroup(configPath(kGlobals), QStringLiteral("MeoMaterial"));
        for (auto it = material.cbegin(); it != material.cend(); ++it) {
            const QColor color = parseColor(it.value());
            if (color.isValid()) nextRoles.insert(it.key(), color);
        }
        const auto appearance = readGroup(configPath(kShell), QStringLiteral("Appearance"));
        bool ok = false;
        const int percent = appearance.value(QStringLiteral("CornerScale")).toInt(&ok);
        const qreal nextScale = ok ? qBound(0, percent, 150) / 100.0 : 1.0;
        const bool differs = nextRoles != roles || !qFuzzyCompare(nextScale + 1.0, cornerScale + 1.0);
        roles = nextRoles;
        cornerScale = nextScale;
        watch();
        if (differs && qobject_cast<QApplication *>(QCoreApplication::instance())) {
            const auto widgets = QApplication::allWidgets();
            for (QWidget *widget : widgets) widget->update();
        }
    }

    void changed() { load(); }

    void watch()
    {
        // KConfig replaces files by rename, which drops a file watch; watch
        // the directory too and re-add the files every time.
        QStringList wanted;
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        if (QFileInfo(dir).isDir()) wanted << dir;
        for (const QString &name : {kGlobals, kShell}) {
            const QString path = configPath(name);
            if (!path.isEmpty()) wanted << path;
        }
        for (const QString &path : wanted)
            if (!m_watcher.files().contains(path) && !m_watcher.directories().contains(path))
                m_watcher.addPath(path);
    }

    QFileSystemWatcher m_watcher;
};

Environment &instance()
{
    static QPointer<Environment> environment;
    if (!environment) environment = new Environment;
    return *environment;
}

bool near(const QColor &a, const QColor &b)
{
    return std::abs(a.red() - b.red()) <= 6 && std::abs(a.green() - b.green()) <= 6
           && std::abs(a.blue() - b.blue()) <= 6;
}

} // namespace

namespace MeoStyleEnvironment {

QColor role(const QString &name, const QPalette &palette, QPalette::ColorGroup group)
{
    if (group == QPalette::Disabled) return {};
    const auto &roles = instance().roles;
    const QColor onSurface = roles.value(QStringLiteral("onSurface"));
    if (!onSurface.isValid() || !near(onSurface, palette.color(group, QPalette::WindowText))) return {};
    return roles.value(name);
}

qreal cornerScale()
{
    return instance().cornerScale;
}

} // namespace MeoStyleEnvironment
