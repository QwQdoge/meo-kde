#pragma once

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QTimer>

class MeoStyle;
class QWidget;

class MeoStyleAnimationEngine final : public QObject
{
public:
    explicit MeoStyleAnimationEngine(MeoStyle *style);
    void watch(QWidget *widget);
    void forget(QWidget *widget);
    qreal progressPhase(const QWidget *widget);
    qreal value(const QWidget *widget, const QString &channel, qreal target, bool spatial);
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    struct Transition {
        qreal from = 0, target = 0;
        qint64 started = 0;
        bool spatial = false, running = false;
    };
    struct Entry {
        QPointer<QWidget> widget;
        QMetaObject::Connection destroyed;
        QHash<QString, Transition> channels;
        bool busy = false;
    };
    void registerWidget(QWidget *widget);
    bool motionAllowed(const QWidget *widget) const;
    bool busyEligible(const QWidget *widget) const;
    qreal sample(Transition &transition) const;
    void repaintWatched();
    void stopIfIdle();
    MeoStyle *m_style;
    QHash<QWidget *, Entry> m_entries;
    QTimer m_timer;
    QElapsedTimer m_clock;
};
