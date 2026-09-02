#include "dockwindowcontroller.h"

#include <KWindowEffects>
#include <LayerShellQt/Window>

#include <QPainterPath>
#include <QQuickWindow>
#include <QRegion>

DockWindowController::DockWindowController(QObject *parent)
    : QObject(parent)
{
}

void DockWindowController::attach(QQuickWindow *window)
{
    m_window = window;
    m_layerWindow = LayerShellQt::Window::get(window);
    m_layerWindow->setScope(QStringLiteral("org.meo.dock"));
    m_layerWindow->setLayer(LayerShellQt::Window::LayerTop);
    m_layerWindow->setAnchors(LayerShellQt::Window::AnchorBottom);
    m_layerWindow->setMargins(QMargins(0, 0, 0, 18));
    m_layerWindow->setExclusiveZone(0);
    m_layerWindow->setKeyboardInteractivity(
        LayerShellQt::Window::KeyboardInteractivityNone);
    m_layerWindow->setActivateOnShow(false);
    m_layerWindow->setWantsToBeOnActiveScreen(true);
    m_layerWindow->setCloseOnDismissed(false);
    connect(window, &QQuickWindow::widthChanged, this, &DockWindowController::syncDesiredSize);
    connect(window, &QQuickWindow::heightChanged, this, &DockWindowController::syncDesiredSize);
    syncDesiredSize();
}

void DockWindowController::updateSurfaceRegion(qreal x, qreal y, qreal width,
                                                qreal height, qreal radius)
{
    if (!m_window || width <= 0 || height <= 0) {
        return;
    }
    QPainterPath path;
    path.addRoundedRect(QRectF(x, y, width, height), radius, radius);
    const QRegion region(path.toFillPolygon().toPolygon());
    KWindowEffects::enableBlurBehind(m_window, true, region);
    KWindowEffects::enableBackgroundContrast(m_window, true, 1.0, 1.0, 1.12, region);
}

void DockWindowController::syncDesiredSize()
{
    if (m_window && m_layerWindow) {
        m_layerWindow->setDesiredSize(m_window->size());
    }
}
