#include "windowblur.h"

#include <KWindowEffects>

#include <QPainterPath>
#include <QPolygonF>

WindowBlur::WindowBlur(QObject *parent)
    : QObject(parent)
{
}

WindowBlur::~WindowBlur()
{
    withdraw();
}

QRegion WindowBlur::roundedRegion(const QRectF &rect, qreal radius)
{
    if (rect.isEmpty()) {
        return {};
    }
    const qreal r = qBound<qreal>(0, radius, qMin(rect.width(), rect.height()) / 2);
    QPainterPath path;
    path.addRoundedRect(rect, r, r);
    return QRegion(path.toFillPolygon().toPolygon());
}

void WindowBlur::setWindow(QWindow *window)
{
    if (m_window == window) {
        return;
    }
    withdraw();
    if (m_window) {
        disconnect(m_window, nullptr, this, nullptr);
    }
    m_window = window;
    if (m_window) {
        // The platform surface exists only once the window is shown.
        connect(m_window, &QWindow::visibleChanged, this, [this]() { apply(); });
        connect(m_window, &QWindow::widthChanged, this, [this]() { apply(); });
        connect(m_window, &QWindow::heightChanged, this, [this]() { apply(); });
    }
    Q_EMIT windowChanged();
    apply();
}

void WindowBlur::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    apply();
}

void WindowBlur::setRect(const QRectF &rect)
{
    if (m_rect == rect) {
        return;
    }
    m_rect = rect;
    Q_EMIT rectChanged();
    apply();
}

void WindowBlur::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    apply();
}

void WindowBlur::withdraw()
{
    if (m_applied && m_window) {
        KWindowEffects::enableBlurBehind(m_window, false);
    }
    m_applied = false;
}

void WindowBlur::apply()
{
    if (!m_window || !m_enabled || !m_window->isVisible() || m_rect.isEmpty()) {
        withdraw();
        return;
    }
    KWindowEffects::enableBlurBehind(m_window, true, roundedRegion(m_rect, m_radius));
    m_applied = true;
}
