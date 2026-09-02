#pragma once

#include <QObject>
#include <QPointer>

class QQuickWindow;

namespace LayerShellQt
{
class Window;
}

class DockWindowController final : public QObject
{
    Q_OBJECT

public:
    explicit DockWindowController(QObject *parent = nullptr);

    void attach(QQuickWindow *window);
    Q_INVOKABLE void updateSurfaceRegion(qreal x, qreal y, qreal width, qreal height,
                                         qreal radius);

private:
    void syncDesiredSize();

    QPointer<QQuickWindow> m_window;
    QPointer<LayerShellQt::Window> m_layerWindow;
};
