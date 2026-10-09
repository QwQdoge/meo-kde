#include "inputmethodcontroller.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QSet>

struct InputMethodPair { QString id, layout; };
using InputMethodPairs = QList<InputMethodPair>;
Q_DECLARE_METATYPE(InputMethodPair)
Q_DECLARE_METATYPE(InputMethodPairs)
QDBusArgument &operator<<(QDBusArgument &argument, const InputMethodPair &pair)
{
    argument.beginStructure(); argument << pair.id << pair.layout; argument.endStructure(); return argument;
}
const QDBusArgument &operator>>(const QDBusArgument &argument, InputMethodPair &pair)
{
    argument.beginStructure(); argument >> pair.id >> pair.layout; argument.endStructure(); return argument;
}

namespace {
const QString service = QStringLiteral("org.fcitx.Fcitx5");
const QString path = QStringLiteral("/controller");
const QString interface = QStringLiteral("org.fcitx.Fcitx.Controller1");
QDBusMessage request(const QString &method) { auto message = QDBusMessage::createMethodCall(service, path, interface, method); message.setAutoStartService(false); return message; }
}

InputMethodController::InputMethodController(QObject *parent) : QObject(parent)
{
    qDBusRegisterMetaType<InputMethodPair>(); qDBusRegisterMetaType<InputMethodPairs>();
    m_refreshTimer.setSingleShot(true); m_refreshTimer.setInterval(100);
    connect(&m_refreshTimer, &QTimer::timeout, this, &InputMethodController::refresh);
    auto *watcher = new QDBusServiceWatcher(service, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &InputMethodController::scheduleRefresh);
    auto bus = QDBusConnection::sessionBus();
    bus.connect(service, path, interface, QStringLiteral("InputMethodGroupsChanged"), this, SLOT(scheduleRefresh()));
    refresh();
}

void InputMethodController::scheduleRefresh() { m_refreshTimer.start(); }

void InputMethodController::refresh()
{
    if (m_busy) { scheduleRefresh(); return; }
    const int generation = ++m_generation;
    auto bus = QDBusConnection::sessionBus();
    auto *current = new QDBusPendingCallWatcher(bus.asyncCall(request(QStringLiteral("CurrentInputMethod")), 3000), this);
    connect(current, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QString> result = *call; call->deleteLater();
        if (generation != m_generation) return;
        m_available = !result.isError(); m_current = m_available ? result.value() : QString();
        if (!m_available) { m_groups.clear(); m_methods.clear(); m_configured.clear(); m_group.clear(); }
        Q_EMIT changed();
    });
    auto *methods = new QDBusPendingCallWatcher(bus.asyncCall(request(QStringLiteral("AvailableInputMethods")), 3000), this);
    connect(methods, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        const auto reply = call->reply(); call->deleteLater();
        if (generation != m_generation) return;
        m_methods.clear();
        if (reply.type() != QDBusMessage::ErrorMessage && !reply.arguments().isEmpty()) {
            const auto list = qvariant_cast<QDBusArgument>(reply.arguments().first()); list.beginArray();
            while (!list.atEnd()) {
                QString id, name, nativeName, icon, label, language; bool configurable = false;
                list.beginStructure(); list >> id >> name >> nativeName >> icon >> label >> language >> configurable; list.endStructure();
                m_methods.append(QVariantMap{{"id", id}, {"label", nativeName.isEmpty() ? name : nativeName}, {"language", language}, {"icon", icon}});
            }
            list.endArray();
        }
        Q_EMIT changed();
    });
    auto *groups = new QDBusPendingCallWatcher(bus.asyncCall(request(QStringLiteral("InputMethodGroups")), 3000), this);
    connect(groups, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QStringList> reply = *call; call->deleteLater();
        if (generation != m_generation) return;
        m_groups = reply.isError() ? QStringList() : reply.value(); Q_EMIT changed();
    });
    auto *group = new QDBusPendingCallWatcher(bus.asyncCall(request(QStringLiteral("CurrentInputMethodGroup")), 3000), this);
    connect(group, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QString> reply = *call; call->deleteLater();
        if (generation != m_generation) return;
        m_group = reply.isError() ? QString() : reply.value();
        if (m_group.isEmpty()) { m_configured.clear(); Q_EMIT changed(); return; }
        auto message = request(QStringLiteral("InputMethodGroupInfo")); message << m_group;
        auto *info = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 3000), this);
        connect(info, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *finished) {
            const QDBusPendingReply<QString, InputMethodPairs> result = *finished; finished->deleteLater();
            if (generation != m_generation) return;
            m_configured.clear(); m_layout.clear();
            if (!result.isError()) {
                m_layout = result.argumentAt<0>();
                for (const auto &pair : result.argumentAt<1>()) m_configured.append(QVariantMap{{"id", pair.id}, {"layout", pair.layout}});
            }
            Q_EMIT changed();
        });
    });
}

void InputMethodController::performRequest(const QString &method, const QVariantList &arguments)
{
    m_busy = true; m_error.clear(); ++m_generation; Q_EMIT changed();
    auto message = request(method); message.setArguments(arguments);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 5000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<> result = *call;
        if (result.isError()) m_error = result.error().message();
        call->deleteLater(); m_busy = false; Q_EMIT changed(); refresh();
    });
}

void InputMethodController::selectGroup(const QString &group)
{
    if (m_busy) return;
    if (!m_available || !m_groups.contains(group)) { m_error = tr("Choose an existing input method group."); Q_EMIT changed(); return; }
    performRequest(QStringLiteral("SwitchInputMethodGroup"), {group});
}

void InputMethodController::activateMethod(const QString &id)
{
    if (m_busy) return;
    bool found = false; for (const auto &entry : m_configured) if (entry.toMap().value("id").toString() == id) found = true;
    if (!m_available || !found) { m_error = tr("Choose an input method in the active group."); Q_EMIT changed(); return; }
    performRequest(QStringLiteral("SetCurrentIM"), {id});
}

void InputMethodController::configureMethods(const QVariantList &ids)
{
    if (m_busy) return;
    if (!m_available || m_group.isEmpty() || ids.isEmpty() || ids.size() > 32) { m_error = tr("Choose one to 32 input methods for the active group."); Q_EMIT changed(); return; }
    QSet<QString> supported, seen;
    for (const auto &entry : m_methods) supported.insert(entry.toMap().value("id").toString());
    InputMethodPairs entries; bool hasKeyboard = false;
    for (const auto &value : ids) {
        const QString id = value.toString();
        if (!supported.contains(id) || seen.contains(id)) { m_error = tr("Choose unique installed input methods."); Q_EMIT changed(); return; }
        seen.insert(id); hasKeyboard |= id.startsWith(QStringLiteral("keyboard-"));
        QString layout;
        for (const auto &current : m_configured) if (current.toMap().value("id").toString() == id) layout = current.toMap().value("layout").toString();
        entries.append({id, layout});
    }
    if (!hasKeyboard) { m_error = tr("Keep at least one keyboard layout in the group."); Q_EMIT changed(); return; }
    // The owner validates and persists group membership; existing per-engine layout overrides are retained.
    performRequest(QStringLiteral("SetInputMethodGroupInfo"), {m_group, m_layout, QVariant::fromValue(entries)});
}
