#include "windowcornerseffect.h"

#include <kwin/effect/effectwindow.h>
#include <kwin/effect/render-target.h>
#include <kwin/effect/render-viewport.h>
#include <KConfigGroup>
#include <KSharedConfig>
#include <QPainterPath>
#include <QRegion>

namespace MeoWindowCorners {

WindowCornersEffect::WindowCornersEffect()
{
    reconfigure(ReconfigureAll);
}

WindowCornersEffect::~WindowCornersEffect() = default;

bool WindowCornersEffect::supported()
{
    return true;
}

void WindowCornersEffect::reconfigure(ReconfigureFlags flags)
{
    Q_UNUSED(flags);
    auto config = KSharedConfig::openConfig("kwinrc");
    KConfigGroup group(config, "org.meo.decoration");

    m_cornerRadius = group.readEntry("CornerRadius", 14);
    m_squareMaximized = group.readEntry("SquareMaximized", true);
    m_enabled = group.readEntry("EnableCompanionEffect", true);
}

bool WindowCornersEffect::isActive() const
{
    return m_enabled;
}

bool WindowCornersEffect::shouldClipWindow(KWin::EffectWindow *w) const
{
    if (!w || !m_enabled) return false;

    // Skip special window types (dock, desktop, tooltip, notification, menu)
    if (w->isDock() || w->isDesktop() || w->isTooltip() || w->isNotification() || w->isPopupMenu() || w->isDropdownMenu()) {
        return false;
    }

    // Skip maximized, fullscreen, or tiled windows if configured
    if (m_squareMaximized && (w->isMaximized() || w->isFullScreen())) {
        return false;
    }

    return true;
}

void WindowCornersEffect::drawWindow(const KWin::RenderTarget &renderTarget,
                                    const KWin::RenderViewport &viewport,
                                    KWin::EffectWindow *w,
                                    int mask,
                                    const QRegion &region,
                                    KWin::WindowPaintData &data)
{
    if (shouldClipWindow(w) && m_cornerRadius > 0) {
        QRect winGeo = w->expandedGeometry();
        QPainterPath clipPath;
        clipPath.addRoundedRect(winGeo, m_cornerRadius, m_cornerRadius);
        
        QRegion roundedRegion = QRegion(clipPath.toFillPolygon().toPolygon());
        QRegion clipRegion = region.intersected(roundedRegion);

        KWin::effects->drawWindow(renderTarget, viewport, w, mask, clipRegion, data);
    } else {
        KWin::effects->drawWindow(renderTarget, viewport, w, mask, region, data);
    }
}

WindowCornersEffectFactory::WindowCornersEffectFactory() = default;

KWin::Effect *WindowCornersEffectFactory::createEffect() const
{
    return new WindowCornersEffect();
}

} // namespace MeoWindowCorners

#include "windowcornerseffect.moc"
