#pragma once

#include <KConfigWatcher>
#include <QObject>

/**
 * User-selectable surface effects for Meo shell popups, read from the
 * `[Appearance]` group of `meo-shellrc`:
 *
 *   SurfaceTransparency=false   let popups show a little of what is below
 *   SurfaceBlur=false           blur what is below (needs transparency)
 *
 * Both default to off, so popups are solid unless the user opts in.
 */
class ShellAppearance final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "ShellAppearance")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool transparency READ transparency NOTIFY changed)
    Q_PROPERTY(bool blur READ blur NOTIFY changed)

public:
    explicit ShellAppearance(QObject *parent = nullptr);

    bool transparency() const { return m_transparency; }
    // Blur is only meaningful behind a translucent surface.
    bool blur() const { return m_transparency && m_blur; }

Q_SIGNALS:
    void changed();

private:
    void reload();

    KConfigWatcher::Ptr m_watcher;
    bool m_transparency = false;
    bool m_blur = false;
};
