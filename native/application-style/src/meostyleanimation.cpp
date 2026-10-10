#include "meostyleanimation.h"
#include "meostyle.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QEvent>
#include <QtWidgets/QProgressBar>
#include <QtGui/QGuiApplication>
#include <QtGui/QStyleHints>
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
            if (!entry.active) continue;
            if (!entry.bar || !eligible(entry.bar)) entry.active = false;
            else entry.bar->update();
        }
        stopIfIdle();
    });
    if (auto *app = QCoreApplication::instance()) app->installEventFilter(this);
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
    QObject::connect(QGuiApplication::styleHints()->accessibility(), &QAccessibilityHints::motionPreferenceChanged,
                     this, [this] { repaintWatched(); });
#endif
}

bool MeoStyleAnimationEngine::eligible(const QProgressBar *bar) const
{
    if (!bar || !bar->isVisible() || !bar->isEnabled() || bar->minimum() != 0 || bar->maximum() != 0) return false;
    if (bar->property("meo.reducedMotion").toBool()
        || (QCoreApplication::instance() && QCoreApplication::instance()->property("meo.reducedMotion").toBool())) return false;
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
    if (QGuiApplication::styleHints()->accessibility()->motionPreference() == Qt::MotionPreference::ReducedMotion) return false;
#endif
    // Older Qt versions expose the platform animation policy through QStyle.
    return m_style->styleHint(QStyle::SH_Widget_Animation_Duration, nullptr, bar) > 0;
}

void MeoStyleAnimationEngine::watch(QWidget *widget)
{
    auto *bar = qobject_cast<QProgressBar *>(widget);
    if (!bar || m_entries.contains(bar)) return;
    Entry entry; entry.bar = bar;
    entry.destroyed = QObject::connect(bar, &QObject::destroyed, this, [this, bar] {
        m_entries.remove(bar); stopIfIdle();
    });
    m_entries.insert(bar, entry);
    bar->installEventFilter(this);
}

void MeoStyleAnimationEngine::forget(QWidget *widget)
{
    auto *bar = qobject_cast<QProgressBar *>(widget);
    auto entry = m_entries.find(bar);
    if (entry == m_entries.end()) return;
    QObject::disconnect(entry->destroyed);
    bar->removeEventFilter(this);
    m_entries.erase(entry); stopIfIdle();
}

qreal MeoStyleAnimationEngine::progressPhase(const QWidget *widget)
{
    auto *bar = qobject_cast<QProgressBar *>(const_cast<QWidget *>(widget));
    if (!bar) return 0.75;
    watch(bar);
    auto &entry = m_entries[bar]; entry.active = eligible(bar);
    if (entry.active && !m_timer.isActive()) m_timer.start();
    if (!entry.active) { stopIfIdle(); return 0.75; }
    return qreal(m_clock.elapsed() % 1750) / 1750.0;
}

void MeoStyleAnimationEngine::stopIfIdle()
{
    for (const auto &entry : m_entries) if (entry.active) return;
    m_timer.stop();
}

void MeoStyleAnimationEngine::repaintWatched()
{
    for (auto &entry : m_entries) if (entry.bar) {
        if (!eligible(entry.bar)) entry.active = false;
        entry.bar->update();
    }
    stopIfIdle();
}

bool MeoStyleAnimationEngine::eventFilter(QObject *object, QEvent *event)
{
    if (event->type() == QEvent::Hide) {
        if (auto *bar = qobject_cast<QProgressBar *>(object); m_entries.contains(bar)) {
            m_entries[bar].active = false; stopIfIdle();
        }
    } else if (event->type() == QEvent::Show || event->type() == QEvent::EnabledChange
               || event->type() == QEvent::DynamicPropertyChange) {
        if (object == QCoreApplication::instance()) repaintWatched();
        else if (auto *bar = qobject_cast<QProgressBar *>(object); m_entries.contains(bar)) {
            if (!eligible(bar) && m_entries.contains(bar)) m_entries[bar].active = false;
            bar->update(); stopIfIdle();
        }
    }
    return false; // Never consume application input or lifecycle events.
}
