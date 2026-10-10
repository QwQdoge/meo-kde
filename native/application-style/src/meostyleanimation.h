#pragma once

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QTimer>

class MeoStyle;
class QProgressBar;
class QWidget;

class MeoStyleAnimationEngine final : public QObject
{
public:
    explicit MeoStyleAnimationEngine(MeoStyle *style);
    void watch(QWidget *widget);
    void forget(QWidget *widget);
    qreal progressPhase(const QWidget *widget);
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    struct Entry { QPointer<QProgressBar> bar; QMetaObject::Connection destroyed; bool active = false; };
    bool eligible(const QProgressBar *bar) const;
    void repaintWatched();
    void stopIfIdle();
    MeoStyle *m_style;
    QHash<QProgressBar *, Entry> m_entries;
    QTimer m_timer;
    QElapsedTimer m_clock;
};
