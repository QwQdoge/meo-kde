#pragma once

#include <KConfigWatcher>
#include <QObject>

/**
 * User-selectable surface effects for Meo shell popups, read from the
 * `[Appearance]` group of `meo-shellrc`:
 *
 *   SurfaceTransparency=false   let popups show a little of what is below
 *   SurfaceBlur=false           blur what is below (needs transparency)
 *   TransparencyLevel=100       how see-through translucent surfaces are,
 *                               in percent of the designed amount (25-200)
 *   CornerScale=100             roundness of Meo corners, in percent of the
 *                               Meo Design System radii (0-150)
 *
 * Transparency and blur default to off, so popups are solid unless the user
 * opts in. Meo Settings writes these keys with KConfig::Notify, so running
 * surfaces follow without a restart.
 */
class ShellAppearance final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "ShellAppearance")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool transparency READ transparency NOTIFY changed)
    Q_PROPERTY(bool blur READ blur NOTIFY changed)
    Q_PROPERTY(double transparencyLevel READ transparencyLevel NOTIFY changed)
    Q_PROPERTY(double cornerScale READ cornerScale NOTIFY changed)

public:
    explicit ShellAppearance(QObject *parent = nullptr);

    bool transparency() const { return m_transparency; }
    // Blur is only meaningful behind a translucent surface.
    bool blur() const { return m_transparency && m_blur; }
    // 1.0 is the designed translucency; 0 is opaque.
    double transparencyLevel() const { return m_transparencyLevel; }
    // 1.0 is the Meo Design System corner radius; 0 is square.
    double cornerScale() const { return m_cornerScale; }

Q_SIGNALS:
    void changed();

private:
    void reload();

    KConfigWatcher::Ptr m_watcher;
    bool m_transparency = false;
    bool m_blur = false;
    double m_transparencyLevel = 1.0;
    double m_cornerScale = 1.0;
};
