#pragma once

#include <QObject>
#include <QString>

/**
 * Switches the desktop between Meo's light and dark KDE color schemes through
 * KDE's own `plasma-apply-colorscheme` tool, which stays the authority for
 * applying a scheme (kdeglobals, KDE notifications to running applications).
 *
 * The tool runs asynchronously as the current user; the result is read back by
 * consumers from the active KDE color scheme rather than assumed.
 */
class ColorSchemeActions final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "ColorSchemeActions")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit ColorSchemeActions(QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    QString error() const { return m_error; }

    Q_INVOKABLE void setDarkMode(bool dark);

    static QString schemeName(bool dark);

Q_SIGNALS:
    void changed();

private:
    bool m_busy = false;
    QString m_error;
};
