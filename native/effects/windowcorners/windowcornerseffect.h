#pragma once

#include <kwin/effect/effect.h>
#include <kwin/effect/effectwindow.h>
#include <KConfigGroup>
#include <KSharedConfig>
#include <QRegion>
#include <QPainterPath>

namespace MeoWindowCorners {

class WindowCornersEffect : public KWin::Effect {
    Q_OBJECT
public:
    WindowCornersEffect();
    ~WindowCornersEffect() override;

    static bool supported();

    void reconfigure(ReconfigureFlags flags) override;
    void drawWindow(const KWin::RenderTarget &renderTarget,
                    const KWin::RenderViewport &viewport,
                    KWin::EffectWindow *w,
                    int mask,
                    const QRegion &region,
                    KWin::WindowPaintData &data) override;

    bool isActive() const override;

private:
    bool shouldClipWindow(KWin::EffectWindow *w) const;
    
    int m_cornerRadius = 14;
    bool m_squareMaximized = true;
    bool m_enabled = true;
};

class WindowCornersEffectFactory : public KWin::EffectFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID KPluginFactory_iid FILE "metadata.json")
    Q_INTERFACES(KPluginFactory)
public:
    WindowCornersEffectFactory();
    KWin::Effect *createEffect() const override;
};

} // namespace MeoWindowCorners
