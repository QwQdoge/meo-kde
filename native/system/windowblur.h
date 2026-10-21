#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QRegion>
#include <QWindow>

/**
 * Asks the compositor to blur whatever is behind a rounded part of a shell
 * popup window (KWin's Blur effect, through KWindowEffects). Nothing is
 * captured or drawn by Meo; when blur is disabled the request is withdrawn.
 */
class WindowBlur : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // The surface to blur, in window coordinates, and its corner radius.
    Q_PROPERTY(QRectF rect READ rect WRITE setRect NOTIFY rectChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)

public:
    explicit WindowBlur(QObject *parent = nullptr);
    ~WindowBlur() override;

    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QRectF rect() const { return m_rect; }
    void setRect(const QRectF &rect);
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);

    static QRegion roundedRegion(const QRectF &rect, qreal radius);

Q_SIGNALS:
    void windowChanged();
    void enabledChanged();
    void rectChanged();
    void radiusChanged();

private:
    void apply();
    void withdraw();

    QPointer<QWindow> m_window;
    bool m_enabled = false;
    bool m_applied = false;
    QRectF m_rect;
    qreal m_radius = 0;
};
