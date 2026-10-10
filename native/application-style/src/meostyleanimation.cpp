#include "meostyleanimation.h"
#include "meostyle.h"
#include <meodesigntokens.h>

#include <QtCore/QCoreApplication>
#include <QtCore/QEvent>
#include <QtWidgets/QProgressBar>
#include <QtGui/QGuiApplication>
#include <QtGui/QStyleHints>
#include <cmath>
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
#include <QtGui/QAccessibilityHints>
#endif

MeoStyleAnimationEngine::MeoStyleAnimationEngine(MeoStyle *style) : QObject(style), m_style(style)
{
    m_clock.start();
    m_timer.setParent(this);
    m_timer.setObjectName(QStringLiteral("meo-progress-animation"));
    m_timer.setInterval(16);
    QObject::connect(&m_timer, &QTimer::timeout, this, [this] {
        for (auto &entry : m_entries) {
            if (!entry.widget) continue;
            const bool allowed = motionAllowed(entry.widget);
            entry.busy = entry.busy && busyEligible(entry.widget);
            bool repaint = entry.busy;
            for (auto &transition : entry.channels) {
                if (!transition.running) continue;
                repaint = true;
                if (allowed) sample(transition);
                else transition.running = false;
            }
            if (repaint) entry.widget->update();
        }
        stopIfIdle();
    });
    if (auto *app = QCoreApplication::instance()) app->installEventFilter(this);
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
    QObject::connect(QGuiApplication::styleHints()->accessibility(), &QAccessibilityHints::motionPreferenceChanged,
                     this, [this] { repaintWatched(); });
#endif
}

bool MeoStyleAnimationEngine::motionAllowed(const QWidget *widget) const
{
    if (!widget || !widget->isVisible() || !widget->isEnabled()) return false;
    if (widget->property("meo.reducedMotion").toBool()
        || (QCoreApplication::instance() && QCoreApplication::instance()->property("meo.reducedMotion").toBool())) return false;
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
    if (QGuiApplication::styleHints()->accessibility()->motionPreference() == Qt::MotionPreference::ReducedMotion) return false;
#endif
    return m_style->styleHint(QStyle::SH_Widget_Animation_Duration, nullptr, widget) > 0;
}

bool MeoStyleAnimationEngine::busyEligible(const QWidget *widget) const
{
    const auto *bar = qobject_cast<const QProgressBar *>(widget);
    return bar && bar->minimum() == 0 && bar->maximum() == 0 && motionAllowed(bar);
}

void MeoStyleAnimationEngine::registerWidget(QWidget *widget)
{
    if (!widget || m_entries.contains(widget)) return;
    Entry entry; entry.widget = widget;
    entry.destroyed = QObject::connect(widget, &QObject::destroyed, this, [this, widget] {
        m_entries.remove(widget); stopIfIdle();
    });
    m_entries.insert(widget, entry);
    // QApplication's filter already receives all widget events. Installing a
    // second local filter would process every lifecycle event twice.
}

void MeoStyleAnimationEngine::watch(QWidget *widget)
{
    if (qobject_cast<QProgressBar *>(widget)) registerWidget(widget);
}

void MeoStyleAnimationEngine::forget(QWidget *widget)
{
    auto entry = m_entries.find(widget);
    if (entry == m_entries.end()) return;
    QObject::disconnect(entry->destroyed);
    m_entries.erase(entry); stopIfIdle();
}

qreal MeoStyleAnimationEngine::sample(Transition &transition) const
{
    if (!transition.running) return transition.target;
    const qreal elapsed = m_clock.elapsed() - transition.started;
    if (elapsed >= Meo::DesignTokens::motionFastMaximumDuration()) {
        transition.running = false;
        return transition.target;
    }
    const qreal t = qMax(qreal(0), elapsed) / 1000.0;
    const qreal damping = transition.spatial ? Meo::DesignTokens::motionFastSpatialDamping()
                                             : Meo::DesignTokens::motionEffectsDamping();
    const qreal omega = std::sqrt(transition.spatial ? Meo::DesignTokens::motionFastSpatialStiffness()
                                                   : Meo::DesignTokens::motionEffectsStiffness());
    qreal progress;
    if (damping >= 1.0) progress = 1.0 - (1.0 + omega * t) * std::exp(-omega * t);
    else {
        const qreal wd = omega * std::sqrt(1.0 - damping * damping);
        progress = 1.0 - std::exp(-damping * omega * t)
            * (std::cos(wd * t) + damping * omega / wd * std::sin(wd * t));
    }
    // Opacities and checked fractions must stay in their physical range.
    return qBound(qreal(0), transition.from + (transition.target - transition.from) * progress, qreal(1));
}

qreal MeoStyleAnimationEngine::value(const QWidget *widget, const QString &channel, qreal target, bool spatial)
{
    target = qBound(qreal(0), target, qreal(1));
    auto *mutableWidget = const_cast<QWidget *>(widget);
    if (!widget) return target;
    registerWidget(mutableWidget);
    auto &channels = m_entries[mutableWidget].channels;
    auto found = channels.find(channel);
    const bool allowed = motionAllowed(widget);
    if (found == channels.end()) {
        // View/menu row identities may change indefinitely. Retain only a
        // bounded working set; never evict a transition still on screen.
        if (channels.size() >= 256) {
            for (auto it = channels.begin(); it != channels.end();) {
                sample(it.value());
                if (!it->running) it = channels.erase(it); else ++it;
            }
            if (channels.size() >= 256) return target;
        }
        channels.insert(channel, Transition{target, target, m_clock.elapsed(), spatial, false});
        return target; // First paint has no invented previous state.
    }
    auto &transition = found.value();
    const qreal current = sample(transition);
    if (!allowed) {
        transition = Transition{target, target, m_clock.elapsed(), spatial, false};
        stopIfIdle(); return target;
    }
    if (transition.target != target) {
        transition = Transition{current, target, m_clock.elapsed(), spatial, qAbs(current - target) > 0.0001};
    }
    if (transition.running && !m_timer.isActive()) m_timer.start();
    return sample(transition);
}

qreal MeoStyleAnimationEngine::progressPhase(const QWidget *widget)
{
    auto *bar = qobject_cast<QProgressBar *>(const_cast<QWidget *>(widget));
    if (!bar) return 0.75;
    watch(bar);
    auto &entry = m_entries[bar]; entry.busy = busyEligible(bar);
    if (entry.busy && !m_timer.isActive()) m_timer.start();
    if (!entry.busy) { stopIfIdle(); return 0.75; }
    return qreal(m_clock.elapsed() % 1750) / 1750.0;
}

void MeoStyleAnimationEngine::stopIfIdle()
{
    for (const auto &entry : m_entries) {
        if (entry.busy) return;
        for (const auto &transition : entry.channels) if (transition.running) return;
    }
    m_timer.stop();
}

void MeoStyleAnimationEngine::repaintWatched()
{
    for (auto &entry : m_entries) if (entry.widget) {
        if (!busyEligible(entry.widget)) entry.busy = false;
        if (!motionAllowed(entry.widget)) for (auto &transition : entry.channels) transition.running = false;
        entry.widget->update();
    }
    stopIfIdle();
}

bool MeoStyleAnimationEngine::eventFilter(QObject *object, QEvent *event)
{
    auto *widget = qobject_cast<QWidget *>(object);
    auto entry = m_entries.find(widget);
    if (event->type() == QEvent::Hide && entry != m_entries.end()) {
        entry->busy = false; entry->channels.clear(); stopIfIdle();
    } else if (event->type() == QEvent::Show || event->type() == QEvent::EnabledChange
               || event->type() == QEvent::DynamicPropertyChange) {
        if (object == QCoreApplication::instance()) repaintWatched();
        else if (entry != m_entries.end()) {
            if (!busyEligible(widget)) entry->busy = false;
            if (!motionAllowed(widget)) for (auto &transition : entry->channels) transition.running = false;
            widget->update(); stopIfIdle();
        }
    }
    return false; // Never consume application input or lifecycle events.
}
