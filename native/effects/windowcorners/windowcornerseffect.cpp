#include "windowcornerseffect.h"

#include <kwin/effect/effectwindow.h>
#include <kwin/effect/effecthandler.h>
#include <kwin/core/rendertarget.h>
#include <kwin/core/renderviewport.h>
#include <kwin/core/region.h>
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

    // Skip maximized or fullscreen windows if configured
    if (w->isFullScreen()) {
        return false;
    }

    return true;
}

void WindowCornersEffect::drawWindow(const KWin::RenderTarget &renderTarget,
                                    const KWin::RenderViewport &viewport,
                                    KWin::EffectWindow *w,
                                    int mask,
                                    const KWin::Region &region,
                                    KWin::WindowPaintData &data)
{
    if (shouldClipWindow(w) && m_cornerRadius > 0) {
        QRectF winGeo = w->expandedGeometry();
        QPainterPath clipPath;
        clipPath.addRoundedRect(winGeo, m_cornerRadius, m_cornerRadius);
        
        KWin::Region roundedRegion(QRegion(clipPath.toFillPolygon().toPolygon()));
        KWin::Region clipRegion = region.intersected(roundedRegion);

        KWin::effects->drawWindow(renderTarget, viewport, w, mask, clipRegion, data);
    } else {
        KWin::effects->drawWindow(renderTarget, viewport, w, mask, region, data);
    }
}

} // namespace MeoWindowCorners

bool MeoWindowCorners::WindowCornersEffectFactory::isSupported() const
{
    return WindowCornersEffect::supported();
}

KWin::Effect *MeoWindowCorners::WindowCornersEffectFactory::createEffect() const
{
    return new WindowCornersEffect();
}
