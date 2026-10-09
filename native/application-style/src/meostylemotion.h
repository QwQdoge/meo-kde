#pragma once

#include <QObject>
#include <QHash>
#include <QPointer>
#include <QVariantAnimation>
#include <QFileSystemWatcher>
#include <QTimer>

class QWidget;

// State transitions only. The engine never changes events, focus, checked
// values or application geometry; the widget remains the interaction owner.
class MeoStyleMotion final : public QObject
{
public:
    explicit MeoStyleMotion(QObject *parent);
    void watch(QWidget *widget);
    void unwatch(QWidget *widget);
    bool animationsEnabled(const QWidget *widget) const;
    qreal opacity(const QWidget *widget, qreal fallback) const;
    qreal busyProgress(const QWidget *widget) const;
    qreal checkProgress(const QWidget *widget, bool checked) const;
    qreal pressProgress(const QWidget *widget, bool pressed) const;

protected:
    bool eventFilter(QObject *object, QEvent *event) override;

private:
    struct State final : QObject {
        explicit State(QWidget *widget, QObject *parent);
        QPointer<QWidget> widget;
        bool hadHover = false;
        QVariantAnimation hover, focus, press, check, busy;
    };
    void transition(State *state, QVariantAnimation &channel, bool active);
    bool reducedMotion(const QWidget *widget) const;
    QHash<const QWidget *, State *> m_states;
    QFileSystemWatcher m_configWatcher;
    QTimer m_configTimer;
    qreal m_motionScale = 1.0;
    void readMotionPreference();
};
