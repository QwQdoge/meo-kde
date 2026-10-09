#include "meostylemotion.h"

#include <meodesigntokens.h>
#include <QAbstractButton>
#include <QApplication>
#include <QEvent>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QWidget>
#include <QProgressBar>
#include <QSettings>
#include <QStandardPaths>
#include <QFileInfo>
#include <QtMath>

MeoStyleMotion::State::State(QWidget *target, QObject *parent)
    : QObject(parent), widget(target)
{
    for (auto *channel : {&hover, &focus, &press, &check}) {
        channel->setStartValue(0.0);
        channel->setEndValue(0.0);
        channel->setEasingCurve(QEasingCurve::OutCubic);
        connect(channel, &QVariantAnimation::valueChanged, this, [this] {
            if (widget) widget->update();
        });
    }
    busy.setStartValue(0.0); busy.setEndValue(1.0);
    busy.setDuration(1200); busy.setLoopCount(-1);
    connect(&busy, &QVariantAnimation::valueChanged, this, [this] { if (widget) widget->update(); });
}

MeoStyleMotion::MeoStyleMotion(QObject *parent) : QObject(parent)
{
    m_configTimer.setSingleShot(true); m_configTimer.setInterval(50);
    connect(&m_configTimer, &QTimer::timeout, this, &MeoStyleMotion::readMotionPreference);
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    if (QFileInfo(directory).isDir()) m_configWatcher.addPath(directory);
    connect(&m_configWatcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_configTimer.start(); });
    connect(&m_configWatcher, &QFileSystemWatcher::fileChanged, this, [this] { m_configTimer.start(); });
    readMotionPreference();
}

void MeoStyleMotion::readMotionPreference()
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/kdeglobals");
    if (QFileInfo::exists(path) && !m_configWatcher.files().contains(path)) m_configWatcher.addPath(path);
    QSettings config(path, QSettings::IniFormat); config.sync();
    const qreal factor = config.value(QStringLiteral("KDE/AnimationDurationFactor"), 1.0).toDouble();
    m_motionScale = qIsFinite(factor) ? qBound<qreal>(0, factor, 4) : 1.0;
    if (m_motionScale <= 0) for (auto *state : m_states) {
        for (auto *channel : {&state->hover, &state->focus, &state->press, &state->check}) {
            channel->stop(); channel->setStartValue(channel->endValue()); channel->setDuration(0); channel->start();
        }
        state->busy.stop(); if (state->widget) state->widget->update();
    }
}

bool MeoStyleMotion::animationsEnabled(const QWidget *widget) const { return !reducedMotion(widget); }

bool MeoStyleMotion::reducedMotion(const QWidget *widget) const
{
    return m_motionScale <= 0 || qEnvironmentVariableIntValue("MEO_REDUCE_MOTION")
        || qApp->property("meo.reduceMotion").toBool()
        || (widget && widget->property("meo.reduceMotion").toBool());
}

void MeoStyleMotion::watch(QWidget *widget)
{
    if (m_states.contains(widget)) return;
    auto *state = new State(widget, this);
    state->hadHover = widget->testAttribute(Qt::WA_Hover);
    widget->setAttribute(Qt::WA_Hover, true);
    m_states.insert(widget, state);
    widget->installEventFilter(this);
    connect(widget, &QObject::destroyed, this, [this, widget] { delete m_states.take(widget); });
    if (auto *button = qobject_cast<QAbstractButton *>(widget)) {
        connect(button, &QAbstractButton::toggled, state, [this, state](bool checked) {
            transition(state, state->check, checked);
        });
        state->check.setStartValue(button->isChecked() ? 1.0 : 0.0);
        state->check.setEndValue(button->isChecked() ? 1.0 : 0.0);
    }
}

void MeoStyleMotion::unwatch(QWidget *widget)
{
    widget->removeEventFilter(this);
    if (auto *state = m_states.take(widget)) {
        widget->setAttribute(Qt::WA_Hover, state->hadHover);
        delete state;
    }
}

void MeoStyleMotion::transition(State *state, QVariantAnimation &channel, bool active)
{
    const qreal target = active ? 1.0 : 0.0;
    const qreal current = channel.currentValue().toReal();
    channel.stop();
    channel.setStartValue(current);
    channel.setEndValue(target);
    if (!state->widget || !state->widget->isVisible() || reducedMotion(state->widget)) {
        channel.setDuration(0);
    } else channel.setDuration(qRound(Meo::DesignTokens::motionStateDuration() * m_motionScale));
    channel.start();
}

bool MeoStyleMotion::eventFilter(QObject *object, QEvent *event)
{
    auto *widget = qobject_cast<QWidget *>(object);
    auto *state = m_states.value(widget, nullptr);
    if (!state) return false;
    switch (event->type()) {
    case QEvent::Enter: transition(state, state->hover, widget->isEnabled()); break;
    case QEvent::Leave: transition(state, state->hover, false); break;
    case QEvent::FocusIn: transition(state, state->focus, true); break;
    case QEvent::FocusOut: transition(state, state->focus, false); transition(state, state->press, false); break;
    case QEvent::MouseButtonPress:
        if (static_cast<QMouseEvent *>(event)->button() == Qt::LeftButton)
            transition(state, state->press, widget->isEnabled());
        break;
    case QEvent::MouseButtonRelease: transition(state, state->press, false); break;
    case QEvent::KeyPress:
        if (auto *key = static_cast<QKeyEvent *>(event); !key->isAutoRepeat()
            && (key->key() == Qt::Key_Space || key->key() == Qt::Key_Return))
            transition(state, state->press, widget->isEnabled());
        break;
    case QEvent::KeyRelease: transition(state, state->press, false); break;
    case QEvent::Hide:
        state->busy.stop();
        [[fallthrough]];
    case QEvent::EnabledChange:
        transition(state, state->hover, false);
        transition(state, state->press, false);
        transition(state, state->focus, widget->hasFocus() && widget->isEnabled());
        break;
    default: break;
    }
    return false;
}

qreal MeoStyleMotion::opacity(const QWidget *widget, qreal fallback) const
{
    const auto *state = m_states.value(widget, nullptr);
    if (!state || reducedMotion(widget)) return fallback;
    return qMax(state->hover.currentValue().toReal() * Meo::DesignTokens::stateOpacityHover(),
        qMax(state->focus.currentValue().toReal() * Meo::DesignTokens::stateOpacityFocus(),
             state->press.currentValue().toReal() * Meo::DesignTokens::stateOpacityPressed()));
}

qreal MeoStyleMotion::pressProgress(const QWidget *widget, bool pressed) const
{
    const auto *state = m_states.value(widget, nullptr);
    return !state || reducedMotion(widget) ? (pressed ? 1.0 : 0.0) : state->press.currentValue().toReal();
}

qreal MeoStyleMotion::checkProgress(const QWidget *widget, bool checked) const
{
    const auto *state = m_states.value(widget, nullptr);
    return !state || !qobject_cast<const QAbstractButton *>(widget) || reducedMotion(widget)
        ? (checked ? 1.0 : 0.0) : state->check.currentValue().toReal();
}

qreal MeoStyleMotion::busyProgress(const QWidget *widget) const
{
    auto *state = m_states.value(widget, nullptr);
    const auto *progress = qobject_cast<const QProgressBar *>(widget);
    if (!state || !progress) return 0.5;
    if (progress->minimum() != 0 || progress->maximum() != 0 || !widget->isVisible() || reducedMotion(widget)) {
        state->busy.stop(); return 0.5;
    }
    if (state->busy.state() != QAbstractAnimation::Running) state->busy.start();
    return state->busy.currentValue().toReal();
}
