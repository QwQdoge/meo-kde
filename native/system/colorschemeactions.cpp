#include "colorschemeactions.h"

#include <KLocalizedString>

#include <QProcess>
#include <QStandardPaths>

ColorSchemeActions::ColorSchemeActions(QObject *parent)
    : QObject(parent)
{
}

QString ColorSchemeActions::schemeName(bool dark)
{
    return dark ? QStringLiteral("MeoDark") : QStringLiteral("MeoLight");
}

void ColorSchemeActions::setDarkMode(bool dark)
{
    if (m_busy) {
        return;
    }
    const QString executable = QStandardPaths::findExecutable(QStringLiteral("plasma-apply-colorscheme"));
    if (executable.isEmpty()) {
        m_error = i18n("KDE color scheme tool is unavailable.");
        Q_EMIT changed();
        return;
    }
    m_busy = true;
    m_error.clear();
    Q_EMIT changed();

    auto *process = new QProcess(this);
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError) {
        m_busy = false;
        m_error = process->errorString();
        Q_EMIT changed();
        process->deleteLater();
    });
    connect(process, &QProcess::finished, this, [this, process](int code, QProcess::ExitStatus status) {
        m_busy = false;
        if (code != 0 || status != QProcess::NormalExit) {
            m_error = i18n("KDE could not change the color scheme.");
        }
        Q_EMIT changed();
        process->deleteLater();
    });
    process->start(executable, {schemeName(dark)});
}
