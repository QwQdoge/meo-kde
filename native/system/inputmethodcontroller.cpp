#include "inputmethodcontroller.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QPointer>
#include <QSet>
#include <QVariantMap>

namespace
{
constexpr auto kFcitxService = "org.fcitx.Fcitx5";
constexpr auto kFcitxControllerPath = "/controller";
constexpr auto kFcitxControllerInterface = "org.fcitx.Fcitx.Controller1";

struct GroupEntry {
    QString inputMethodId;
    QString layout;
};
using GroupEntryList = QList<GroupEntry>;

struct AvailableEntry {
    QString inputMethodId;
    QString name;
    QString nativeName;
    QString icon;
    QString label;
    QString language;
    bool configurable = false;
};
using AvailableEntryList = QList<AvailableEntry>;

QDBusArgument &operator<<(QDBusArgument &argument, const GroupEntry &entry)
{
    argument.beginStructure();
    argument << entry.inputMethodId << entry.layout;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, GroupEntry &entry)
{
    argument.beginStructure();
    argument >> entry.inputMethodId >> entry.layout;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const AvailableEntry &entry)
{
    argument.beginStructure();
    argument << entry.inputMethodId
             << entry.name
             << entry.nativeName
             << entry.icon
             << entry.label
             << entry.language
             << entry.configurable;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, AvailableEntry &entry)
{
    argument.beginStructure();
    argument >> entry.inputMethodId
             >> entry.name
             >> entry.nativeName
             >> entry.icon
             >> entry.label
             >> entry.language
             >> entry.configurable;
    argument.endStructure();
    return argument;
}

void registerDbusTypes()
{
    static const bool registered = [] {
        qDBusRegisterMetaType<GroupEntry>();
        qDBusRegisterMetaType<GroupEntryList>();
        qDBusRegisterMetaType<AvailableEntry>();
        qDBusRegisterMetaType<AvailableEntryList>();
        return true;
    }();
    Q_UNUSED(registered)
}

QDBusInterface controllerInterface()
{
    return QDBusInterface(QString::fromLatin1(kFcitxService),
                          QString::fromLatin1(kFcitxControllerPath),
                          QString::fromLatin1(kFcitxControllerInterface),
                          QDBusConnection::sessionBus());
}

QString operationError(const QString &operation, const QString &detail)
{
    return QObject::tr("%1 failed: %2").arg(operation, detail);
}
}

Q_DECLARE_METATYPE(GroupEntry)
Q_DECLARE_METATYPE(GroupEntryList)
Q_DECLARE_METATYPE(AvailableEntry)
Q_DECLARE_METATYPE(AvailableEntryList)

InputMethodController::InputMethodController(QObject *parent)
    : QObject(parent)
{
    registerDbusTypes();

    const QDBusConnection bus = QDBusConnection::sessionBus();
    m_serviceWatcher = new QDBusServiceWatcher(QString::fromLatin1(kFcitxService),
                                                bus,
                                                QDBusServiceWatcher::WatchForRegistration
                                                    | QDBusServiceWatcher::WatchForUnregistration,
                                                this);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceRegistered,
            this, [this](const QString &) { refresh(); });
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, [this](const QString &) {
                ++m_refreshGeneration;
                m_pendingRefreshCalls = 0;
                setBusy(false);
                const bool stateWasPopulated = m_available || m_active || m_canRestart
                    || !m_currentUi.isEmpty();
                const bool inventoryWasPopulated = !m_groups.isEmpty()
                    || !m_currentGroup.isEmpty()
                    || !m_currentInputMethod.isEmpty()
                    || !m_activeInputMethods.isEmpty()
                    || !m_availableInputMethods.isEmpty();
                clearRuntimeState();
                if (stateWasPopulated) {
                    Q_EMIT stateChanged();
                }
                if (inventoryWasPopulated) {
                    Q_EMIT inventoryChanged();
                }
            });

    refresh();
}

bool InputMethodController::available() const
{
    return m_available;
}

bool InputMethodController::active() const
{
    return m_active;
}

bool InputMethodController::busy() const
{
    return m_busy;
}

QStringList InputMethodController::groups() const
{
    return m_groups;
}

QString InputMethodController::currentGroup() const
{
    return m_currentGroup;
}

QString InputMethodController::currentInputMethod() const
{
    return m_currentInputMethod;
}

QString InputMethodController::currentUi() const
{
    return m_currentUi;
}

bool InputMethodController::canRestart() const
{
    return m_canRestart;
}

QVariantList InputMethodController::activeInputMethods() const
{
    return m_activeInputMethods;
}

QVariantList InputMethodController::availableInputMethods() const
{
    return m_availableInputMethods;
}

QString InputMethodController::lastError() const
{
    return m_lastError;
}

void InputMethodController::refresh()
{
    const quint64 generation = ++m_refreshGeneration;
    m_pendingRefreshCalls = 0;

    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()) {
        const bool hadState = m_available || m_active || !m_groups.isEmpty()
            || !m_currentGroup.isEmpty() || !m_currentInputMethod.isEmpty();
        clearRuntimeState();
        setBusy(false);
        setError(tr("The user session D-Bus is unavailable."));
        if (hadState) {
            Q_EMIT stateChanged();
            Q_EMIT inventoryChanged();
        }
        return;
    }

    const QDBusReply<bool> registered = bus.interface()->isServiceRegistered(
        QString::fromLatin1(kFcitxService));
    if (!registered.isValid()) {
        clearRuntimeState();
        setBusy(false);
        setError(tr("Cannot query Fcitx 5 service state: %1").arg(registered.error().message()));
        Q_EMIT stateChanged();
        Q_EMIT inventoryChanged();
        return;
    }

    if (!registered.value()) {
        const bool hadState = m_available || m_active || !m_groups.isEmpty()
            || !m_currentGroup.isEmpty() || !m_currentInputMethod.isEmpty()
            || !m_availableInputMethods.isEmpty() || !m_activeInputMethods.isEmpty();
        clearRuntimeState();
        setBusy(false);
        clearError();
        if (hadState) {
            Q_EMIT stateChanged();
            Q_EMIT inventoryChanged();
        }
        return;
    }

    if (!m_available) {
        m_available = true;
        Q_EMIT stateChanged();
    }
    clearError();
    setBusy(true);

    startRefreshCall(QStringLiteral("InputMethodGroups"), {}, generation,
                     &InputMethodController::acceptGroups);
    startRefreshCall(QStringLiteral("CurrentInputMethodGroup"), {}, generation,
                     &InputMethodController::acceptCurrentGroup);
    startRefreshCall(QStringLiteral("CurrentInputMethod"), {}, generation,
                     &InputMethodController::acceptCurrentInputMethod);
    startRefreshCall(QStringLiteral("CurrentUI"), {}, generation,
                     &InputMethodController::acceptCurrentUi);
    startRefreshCall(QStringLiteral("State"), {}, generation,
                     &InputMethodController::acceptState);
    startRefreshCall(QStringLiteral("CanRestart"), {}, generation,
                     &InputMethodController::acceptCanRestart);
    startRefreshCall(QStringLiteral("AvailableInputMethods"), {}, generation,
                     &InputMethodController::acceptAvailableInputMethods);
}

bool InputMethodController::setCurrentInputMethod(const QString &inputMethodId)
{
    if (!safeIdentifier(inputMethodId)) {
        setError(tr("Input method identifier is invalid."));
        return false;
    }
    if (!hasActiveInputMethod(inputMethodId)) {
        setError(tr("The requested input method is not in the active Fcitx group."));
        return false;
    }
    return startMutationCall(QStringLiteral("SetCurrentIM"),
                             {inputMethodId},
                             tr("Changing the current input method"));
}

bool InputMethodController::switchGroup(const QString &groupName)
{
    if (!safeIdentifier(groupName) || !m_groups.contains(groupName)) {
        setError(tr("The requested Fcitx input-method group is unavailable."));
        return false;
    }
    return startMutationCall(QStringLiteral("SwitchInputMethodGroup"),
                             {groupName},
                             tr("Switching the input-method group"));
}

bool InputMethodController::applyCurrentGroup(const QStringList &inputMethodIds,
                                              const QStringList &layouts,
                                              const QString &defaultLayout)
{
    if (m_currentGroup.isEmpty() || !m_groups.contains(m_currentGroup)) {
        setError(tr("No authoritative current Fcitx group is available."));
        return false;
    }
    if (inputMethodIds.isEmpty() || inputMethodIds.size() > 64
        || inputMethodIds.size() != layouts.size()) {
        setError(tr("The input-method group must contain 1 to 64 entries with one layout value per entry."));
        return false;
    }
    if (!safeLayout(defaultLayout)) {
        setError(tr("The default keyboard layout value is invalid."));
        return false;
    }

    QSet<QString> uniqueIds;
    GroupEntryList entries;
    entries.reserve(inputMethodIds.size());
    for (qsizetype index = 0; index < inputMethodIds.size(); ++index) {
        const QString &id = inputMethodIds.at(index);
        const QString &layout = layouts.at(index);
        if (!safeIdentifier(id) || !hasAvailableInputMethod(id)) {
            setError(tr("Input method '%1' is not in the authoritative Fcitx inventory.").arg(id));
            return false;
        }
        if (uniqueIds.contains(id)) {
            setError(tr("An input method may appear only once in a group."));
            return false;
        }
        if (!safeLayout(layout)) {
            setError(tr("The keyboard layout value for '%1' is invalid.").arg(id));
            return false;
        }
        uniqueIds.insert(id);
        entries.push_back({id, layout});
    }

    return startMutationCall(QStringLiteral("SetInputMethodGroupInfo"),
                             {m_currentGroup,
                              defaultLayout,
                              QVariant::fromValue(entries)},
                             tr("Updating the current input-method group"));
}

bool InputMethodController::reload()
{
    return startMutationCall(QStringLiteral("ReloadConfig"), {}, tr("Reloading Fcitx configuration"));
}

bool InputMethodController::restart()
{
    if (!m_canRestart) {
        setError(tr("This Fcitx instance does not advertise safe restart support."));
        return false;
    }
    return startMutationCall(QStringLiteral("Restart"), {}, tr("Restarting Fcitx"));
}

void InputMethodController::clearError()
{
    if (m_lastError.isEmpty()) {
        return;
    }
    m_lastError.clear();
    Q_EMIT errorChanged();
}

void InputMethodController::setError(const QString &error)
{
    if (m_lastError == error) {
        return;
    }
    m_lastError = error;
    Q_EMIT errorChanged();
}

void InputMethodController::clearRuntimeState()
{
    m_available = false;
    m_active = false;
    m_canRestart = false;
    m_groups.clear();
    m_currentGroup.clear();
    m_currentInputMethod.clear();
    m_currentUi.clear();
    m_activeInputMethods.clear();
    m_availableInputMethods.clear();
}

void InputMethodController::setBusy(bool busy)
{
    if (m_busy == busy) {
        return;
    }
    m_busy = busy;
    Q_EMIT busyChanged();
}

void InputMethodController::finishRefreshPart(quint64 generation)
{
    if (generation != m_refreshGeneration) {
        return;
    }
    if (m_pendingRefreshCalls > 0) {
        --m_pendingRefreshCalls;
    }
    if (m_pendingRefreshCalls == 0) {
        setBusy(false);
    }
}

void InputMethodController::startRefreshCall(const QString &method,
                                             const QList<QVariant> &arguments,
                                             quint64 generation,
                                             ReplyHandler handler)
{
    ++m_pendingRefreshCalls;
    QDBusInterface controller = controllerInterface();
    auto *watcher = new QDBusPendingCallWatcher(
        controller.asyncCallWithArgumentList(method, arguments), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, generation, handler, method](QDBusPendingCallWatcher *) {
                watcher->deleteLater();
                if (generation != m_refreshGeneration) {
                    return;
                }

                if (watcher->isError()) {
                    setError(operationError(method, watcher->error().message()));
                    finishRefreshPart(generation);
                    return;
                }

                const QList<QVariant> arguments = watcher->reply().arguments();
                (this->*handler)(arguments);
                if (handler == &InputMethodController::acceptCurrentGroup) {
                    refreshCurrentGroupInfo(generation);
                }
                finishRefreshPart(generation);
            });
}

bool InputMethodController::startMutationCall(const QString &method,
                                              const QList<QVariant> &arguments,
                                              const QString &operationName)
{
    if (!m_available) {
        setError(tr("Fcitx 5 is not running in this user session."));
        return false;
    }
    if (m_busy) {
        setError(tr("Another input-method operation is still in progress."));
        return false;
    }

    clearError();
    setBusy(true);
    QDBusInterface controller = controllerInterface();
    auto *watcher = new QDBusPendingCallWatcher(
        controller.asyncCallWithArgumentList(method, arguments), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, operationName](QDBusPendingCallWatcher *) {
                watcher->deleteLater();
                setBusy(false);
                if (watcher->isError()) {
                    setError(operationError(operationName, watcher->error().message()));
                    return;
                }
                refresh();
            });
    return true;
}

void InputMethodController::refreshCurrentGroupInfo(quint64 generation)
{
    if (generation != m_refreshGeneration || m_currentGroup.isEmpty()) {
        return;
    }
    startRefreshCall(QStringLiteral("InputMethodGroupInfo"),
                     {m_currentGroup},
                     generation,
                     &InputMethodController::acceptActiveInputMethods);
}

void InputMethodController::acceptGroups(const QList<QVariant> &arguments)
{
    const QStringList next = arguments.isEmpty() ? QStringList{} : arguments.first().toStringList();
    if (next == m_groups) {
        return;
    }
    m_groups = next;
    Q_EMIT inventoryChanged();
}

void InputMethodController::acceptCurrentGroup(const QList<QVariant> &arguments)
{
    const QString next = arguments.isEmpty() ? QString{} : arguments.first().toString();
    if (next == m_currentGroup) {
        return;
    }
    m_currentGroup = next;
    m_activeInputMethods.clear();
    Q_EMIT inventoryChanged();
}

void InputMethodController::acceptCurrentInputMethod(const QList<QVariant> &arguments)
{
    const QString next = arguments.isEmpty() ? QString{} : arguments.first().toString();
    if (next == m_currentInputMethod) {
        return;
    }
    m_currentInputMethod = next;
    Q_EMIT inventoryChanged();
}

void InputMethodController::acceptCurrentUi(const QList<QVariant> &arguments)
{
    const QString next = arguments.isEmpty() ? QString{} : arguments.first().toString();
    if (next == m_currentUi) {
        return;
    }
    m_currentUi = next;
    Q_EMIT stateChanged();
}

void InputMethodController::acceptState(const QList<QVariant> &arguments)
{
    const bool next = !arguments.isEmpty() && arguments.first().toInt() != 0;
    if (next == m_active) {
        return;
    }
    m_active = next;
    Q_EMIT stateChanged();
}

void InputMethodController::acceptCanRestart(const QList<QVariant> &arguments)
{
    const bool next = !arguments.isEmpty() && arguments.first().toBool();
    if (next == m_canRestart) {
        return;
    }
    m_canRestart = next;
    Q_EMIT stateChanged();
}

void InputMethodController::acceptActiveInputMethods(const QList<QVariant> &arguments)
{
    if (arguments.size() < 2) {
        setError(tr("Fcitx returned an incomplete input-method group response."));
        return;
    }

    const GroupEntryList entries = qdbus_cast<GroupEntryList>(arguments.at(1));
    QVariantList next;
    next.reserve(entries.size());
    for (const GroupEntry &entry : entries) {
        if (!safeIdentifier(entry.inputMethodId) || !safeLayout(entry.layout)) {
            continue;
        }
        QVariantMap item;
        item.insert(QStringLiteral("id"), entry.inputMethodId);
        item.insert(QStringLiteral("layout"), entry.layout);
        item.insert(QStringLiteral("current"), entry.inputMethodId == m_currentInputMethod);
        next.push_back(item);
    }
    if (next == m_activeInputMethods) {
        return;
    }
    m_activeInputMethods = next;
    Q_EMIT inventoryChanged();
}

void InputMethodController::acceptAvailableInputMethods(const QList<QVariant> &arguments)
{
    if (arguments.isEmpty()) {
        setError(tr("Fcitx returned an incomplete available-input-method response."));
        return;
    }

    const AvailableEntryList entries = qdbus_cast<AvailableEntryList>(arguments.first());
    QVariantList next;
    next.reserve(entries.size());
    QSet<QString> seen;
    for (const AvailableEntry &entry : entries) {
        if (!safeIdentifier(entry.inputMethodId) || seen.contains(entry.inputMethodId)) {
            continue;
        }
        seen.insert(entry.inputMethodId);
        QVariantMap item;
        item.insert(QStringLiteral("id"), entry.inputMethodId);
        item.insert(QStringLiteral("name"), entry.name);
        item.insert(QStringLiteral("nativeName"), entry.nativeName);
        item.insert(QStringLiteral("icon"), entry.icon);
        item.insert(QStringLiteral("label"), entry.label);
        item.insert(QStringLiteral("language"), entry.language);
        item.insert(QStringLiteral("configurable"), entry.configurable);
        next.push_back(item);
    }
    if (next == m_availableInputMethods) {
        return;
    }
    m_availableInputMethods = next;
    Q_EMIT inventoryChanged();
}

bool InputMethodController::hasAvailableInputMethod(const QString &inputMethodId) const
{
    for (const QVariant &value : m_availableInputMethods) {
        if (value.toMap().value(QStringLiteral("id")).toString() == inputMethodId) {
            return true;
        }
    }
    return false;
}

bool InputMethodController::hasActiveInputMethod(const QString &inputMethodId) const
{
    for (const QVariant &value : m_activeInputMethods) {
        if (value.toMap().value(QStringLiteral("id")).toString() == inputMethodId) {
            return true;
        }
    }
    return false;
}

bool InputMethodController::safeIdentifier(const QString &value, int maximumLength)
{
    if (value.isEmpty() || value.size() > maximumLength) {
        return false;
    }
    for (const QChar character : value) {
        const ushort code = character.unicode();
        if (code < 0x20 || code == 0x7f) {
            return false;
        }
    }
    return true;
}

bool InputMethodController::safeLayout(const QString &value)
{
    if (value.size() > 128) {
        return false;
    }
    for (const QChar character : value) {
        const ushort code = character.unicode();
        if (code < 0x20 || code == 0x7f) {
            return false;
        }
    }
    return true;
}
