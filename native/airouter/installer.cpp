#include "installer.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>

namespace InstallerCapabilities {
namespace {

bool matches(const QString &pattern, const QString &value)
{
    return QRegularExpression(QStringLiteral("^(?:%1)$").arg(pattern)).match(value).hasMatch();
}

QString runtimeDirectory()
{
    const QString override = qEnvironmentVariable("MEO_INSTALLER_PROPOSAL_DIR");
    if (!override.isEmpty())
        return override;
    const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    return runtime.isEmpty() ? QString() : QDir(runtime).absoluteFilePath(QStringLiteral("meo-installer"));
}

QString logPath()
{
    const QString override = qEnvironmentVariable("MEO_INSTALLER_LOG");
    return override.isEmpty() ? QStringLiteral("/tmp/meoarch-installer/logs/install.log") : override;
}

} // namespace

bool liveEnvironment()
{
    return QDir(QStringLiteral("/run/archiso")).exists()
        || !qEnvironmentVariable("MEO_INSTALLER_PROPOSAL_DIR").isEmpty();
}

QString proposalPath()
{
    const QString dir = runtimeDirectory();
    return dir.isEmpty() ? QString() : QDir(dir).absoluteFilePath(QStringLiteral("ai-proposal.json"));
}

QJsonObject normalizeProposal(const QJsonObject &input, QString *error)
{
    auto fail = [error](const QString &message) {
        if (error)
            *error = message;
        return QJsonObject();
    };

    QJsonObject locale;
    QJsonObject software;
    QJsonObject disk;
    QJsonObject privacy;

    for (auto it = input.constBegin(); it != input.constEnd(); ++it) {
        const QString key = it.key();
        const QJsonValue value = it.value();
        if (key == QLatin1String("rationale"))
            continue;
        if (key == QLatin1String("systemLocale")) {
            if (!matches(QStringLiteral("[a-z]{2,3}_[A-Z]{2}\\.UTF-8"), value.toString()))
                return fail(QStringLiteral("systemLocale must look like en_US.UTF-8"));
            locale.insert(key, value.toString());
        } else if (key == QLatin1String("timezone")) {
            if (!matches(QStringLiteral("[A-Za-z0-9_+\\-]+(?:/[A-Za-z0-9_+\\-]+){0,2}"), value.toString()))
                return fail(QStringLiteral("timezone must be an IANA zone id"));
            locale.insert(key, value.toString());
        } else if (key == QLatin1String("keyboardLayout")) {
            if (!matches(QStringLiteral("[a-z0-9_\\-]{1,32}"), value.toString()))
                return fail(QStringLiteral("keyboardLayout is invalid"));
            locale.insert(key, value.toString());
        } else if (key == QLatin1String("profile") || key == QLatin1String("channel")) {
            static const QSet<QString> profiles{QStringLiteral("recommended"), QStringLiteral("minimal")};
            static const QSet<QString> channels{QStringLiteral("stable"), QStringLiteral("beta")};
            const QString text = value.toString();
            if (!(key == QLatin1String("profile") ? profiles : channels).contains(text))
                return fail(key + QStringLiteral(" is not an allowed value"));
            software.insert(key, text);
        } else if (key == QLatin1String("applications")) {
            QJsonArray ids;
            const QStringList parts = value.toString().split(QLatin1Char(','), Qt::SkipEmptyParts);
            if (parts.size() > 40)
                return fail(QStringLiteral("too many applications"));
            for (const QString &part : parts) {
                const QString id = part.trimmed();
                if (!matches(QStringLiteral("[a-z0-9][a-z0-9._+\\-]{0,63}"), id))
                    return fail(QStringLiteral("application id is invalid"));
                ids.append(id);
            }
            software.insert(key, ids);
        } else if (key == QLatin1String("targetDisk")) {
            // Stable disk id as listed by installer.disks.list. Only a
            // preselection: the Installer checks it against real disks.
            if (!matches(QStringLiteral("[A-Za-z0-9._:@+\\-/]{1,160}"), value.toString()))
                return fail(QStringLiteral("targetDisk must be a stable disk id"));
            disk.insert(QStringLiteral("target"), value.toString());
        } else if (key == QLatin1String("filesystem")) {
            if (value.toString() != QLatin1String("btrfs") && value.toString() != QLatin1String("ext4"))
                return fail(QStringLiteral("filesystem must be btrfs or ext4"));
            disk.insert(key, value.toString());
        } else if (key == QLatin1String("swap")) {
            static const QSet<QString> modes{QStringLiteral("zram"), QStringLiteral("file"), QStringLiteral("none")};
            if (!modes.contains(value.toString()))
                return fail(QStringLiteral("swap mode is not allowed"));
            disk.insert(key, value.toString());
        } else if (key == QLatin1String("separateHome")) {
            if (!value.isBool())
                return fail(QStringLiteral("separateHome must be boolean"));
            disk.insert(key, value.toBool());
        } else if (key == QLatin1String("firewall")) {
            if (!value.isBool())
                return fail(QStringLiteral("firewall must be boolean"));
            privacy.insert(key, value.toBool());
        } else {
            return fail(QStringLiteral("field is not proposable: ") + key);
        }
    }

    QJsonObject out;
    if (!locale.isEmpty()) out.insert(QStringLiteral("locale"), locale);
    if (!software.isEmpty()) out.insert(QStringLiteral("software"), software);
    if (!disk.isEmpty()) out.insert(QStringLiteral("disk"), disk);
    if (!privacy.isEmpty()) out.insert(QStringLiteral("privacy"), privacy);
    if (out.isEmpty())
        return fail(QStringLiteral("proposal contains no changes"));
    return out;
}

bool submitProposal(const QString &proposalJson, QString *message)
{
    auto fail = [message](const QString &text) {
        if (message)
            *message = text;
        return false;
    };
    if (!liveEnvironment())
        return fail(QStringLiteral("The installer capabilities are only available in the MeoArch Live environment."));
    if (proposalJson.size() > 8192)
        return fail(QStringLiteral("proposal is too large"));

    QJsonParseError parseError;
    const QJsonDocument parsed = QJsonDocument::fromJson(proposalJson.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !parsed.isObject())
        return fail(QStringLiteral("proposal must be a JSON object"));

    QString error;
    const QJsonObject selections = normalizeProposal(parsed.object(), &error);
    if (selections.isEmpty())
        return fail(error);

    const QString path = proposalPath();
    if (path.isEmpty())
        return fail(QStringLiteral("No per-user runtime directory is available for the proposal."));
    const QString dir = QFileInfo(path).absolutePath();
    QDir().mkpath(dir);
    QFile::setPermissions(dir, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);

    const QJsonObject document{
        {QStringLiteral("schemaVersion"), 1},
        {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
        {QStringLiteral("rationale"), parsed.object().value(QStringLiteral("rationale")).toString().left(500)},
        {QStringLiteral("selections"), selections},
    };
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return fail(QStringLiteral("The proposal could not be written."));
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    file.write(QJsonDocument(document).toJson(QJsonDocument::Compact));
    if (!file.commit())
        return fail(QStringLiteral("The proposal could not be saved."));

    if (message)
        *message = QStringLiteral("Proposal saved. Nothing was applied: the person must review and accept it in the installer.");
    return true;
}

bool readLog(int lines, QString *message)
{
    if (!liveEnvironment()) {
        if (message)
            *message = QStringLiteral("The installer capabilities are only available in the MeoArch Live environment.");
        return false;
    }
    if (lines < 1 || lines > 200) {
        if (message)
            *message = QStringLiteral("lines must be between 1 and 200");
        return false;
    }
    QFile file(logPath());
    if (!file.open(QIODevice::ReadOnly)) {
        if (message)
            *message = QStringLiteral("No installer log exists yet.");
        return false;
    }
    // Read only the tail; the log can grow large during package installs.
    const qint64 window = 64 * 1024;
    file.seek(qMax<qint64>(0, file.size() - window));
    QStringList all = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'));
    if (file.size() > window && !all.isEmpty())
        all.removeFirst();
    while (!all.isEmpty() && all.last().isEmpty())
        all.removeLast();
    all = all.mid(qMax(0, all.size() - lines));
    QJsonArray out;
    for (const QString &line : std::as_const(all))
        out.append(line.left(400));
    if (message)
        *message = QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
    return true;
}

bool listDisks(QString *message)
{
    if (!liveEnvironment()) {
        if (message)
            *message = QStringLiteral("The installer capabilities are only available in the MeoArch Live environment.");
        return false;
    }
    QProcess process;
    process.start(QStringLiteral("lsblk"),
                  {QStringLiteral("-J"), QStringLiteral("-b"), QStringLiteral("-d"), QStringLiteral("-o"),
                   QStringLiteral("PATH,MODEL,SIZE,TYPE,RO,RM,HOTPLUG,TRAN")});
    if (!process.waitForFinished(5000) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        process.kill();
        if (message)
            *message = QStringLiteral("Storage devices could not be read.");
        return false;
    }
    const QJsonArray devices = QJsonDocument::fromJson(process.readAllStandardOutput())
                                   .object().value(QStringLiteral("blockdevices")).toArray();
    const QDir byId(QStringLiteral("/dev/disk/by-id"));
    QJsonArray out;
    for (const QJsonValue &value : devices) {
        const QJsonObject device = value.toObject();
        if (device.value(QStringLiteral("type")).toString() != QLatin1String("disk"))
            continue;
        const QString path = device.value(QStringLiteral("path")).toString();
        // Use the same by-id identity the Installer uses for its selection.
        QString stableId = path;
        const QFileInfoList links = byId.entryInfoList(QDir::Files | QDir::NoDotAndDotDot | QDir::System);
        for (const QFileInfo &entry : links) {
            if (entry.symLinkTarget() == path) {
                stableId = entry.absoluteFilePath();
                break;
            }
        }
        auto flag = [&device](const char *key) {
            const QJsonValue v = device.value(QLatin1String(key));
            return v.isBool() ? v.toBool() : (v.toVariant().toString() == QLatin1String("1")
                                              || v.toVariant().toString() == QLatin1String("true"));
        };
        out.append(QJsonObject{
            {QStringLiteral("id"), stableId},
            {QStringLiteral("model"), device.value(QStringLiteral("model")).toString().trimmed().left(80)},
            {QStringLiteral("sizeBytes"), device.value(QStringLiteral("size")).toVariant().toLongLong()},
            {QStringLiteral("removable"), flag("rm") || flag("hotplug")},
            {QStringLiteral("readOnly"), flag("ro")},
            {QStringLiteral("transport"), device.value(QStringLiteral("tran")).toString()},
        });
    }
    if (message)
        *message = QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact));
    return true;
}

} // namespace InstallerCapabilities
