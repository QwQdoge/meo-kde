#include "inputdevicescontroller.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QRegularExpression>
#include <QDBusArgument>
#include <QFile>
#include <QXmlStreamReader>
#include <KSharedConfig>
#include <KConfigGroup>
#include <QtMath>
#include <memory>

namespace {
const QString service = QStringLiteral("org.kde.KWin");
const QString manager = QStringLiteral("/org/kde/KWin/InputDevice");
const QString deviceInterface = QStringLiteral("org.kde.KWin.InputDevice");
const QString properties = QStringLiteral("org.freedesktop.DBus.Properties");
const QMap<QString, QString> booleanCapabilities{
    {"enabled", "supportsDisableEvents"}, {"naturalScroll", "supportsNaturalScroll"}, {"leftHanded", "supportsLeftHanded"},
    {"disableWhileTyping", "supportsDisableWhileTyping"},
    {"disableEventsOnExternalMouse", "supportsDisableEventsOnExternalMouse"},
    {"middleEmulation", "supportsMiddleEmulation"}, {"scrollTwoFinger", "supportsScrollTwoFinger"},
    {"scrollEdge", "supportsScrollEdge"}, {"clickMethodAreas", "supportsClickMethodAreas"},
    {"clickMethodClickfinger", "supportsClickMethodClickfinger"},
    {"pointerAccelerationProfileAdaptive", "supportsPointerAccelerationProfileAdaptive"},
    {"pointerAccelerationProfileFlat", "supportsPointerAccelerationProfileFlat"},
    {"tapToClick", "tapFingerCount"}, {"tapAndDrag", "tapFingerCount"}, {"tapDragLock", "tapFingerCount"}
};
QDBusMessage getProperties(const QString &path, const QString &interface)
{
    auto message = QDBusMessage::createMethodCall(service, path, properties, QStringLiteral("GetAll"));
    message << interface;
    return message;
}
}

InputDevicesController::InputDevicesController(QObject *parent) : QObject(parent)
{
    m_inputWatcher = KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("kcminputrc")));
    connect(m_inputWatcher.data(), &KConfigWatcher::configChanged, this,
        [this](const KConfigGroup &group, const QByteArrayList &) { if (group.name() == QStringLiteral("Keyboard")) Q_EMIT changed(); });
    m_refreshTimer.setSingleShot(true); m_refreshTimer.setInterval(75);
    connect(&m_refreshTimer, &QTimer::timeout, this, &InputDevicesController::refresh);
    auto *watcher = new QDBusServiceWatcher(service, QDBusConnection::sessionBus(),
        QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &InputDevicesController::scheduleRefresh);
    auto bus = QDBusConnection::sessionBus();
    bus.connect(service, manager, QStringLiteral("org.kde.KWin.InputDeviceManager"), QStringLiteral("deviceAdded"), this, SLOT(scheduleRefresh()));
    bus.connect(service, manager, QStringLiteral("org.kde.KWin.InputDeviceManager"), QStringLiteral("deviceRemoved"), this, SLOT(scheduleRefresh()));
    bus.connect(service, QString(), properties, QStringLiteral("PropertiesChanged"), this, SLOT(scheduleRefresh()));
    QFile registry(QStringLiteral("/usr/share/X11/xkb/rules/evdev.xml"));
    if (registry.open(QIODevice::ReadOnly)) {
        QXmlStreamReader xml(&registry);
        QString layout, layoutDescription;
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement() && xml.name() == QLatin1String("layout")) {
                layout.clear(); layoutDescription.clear();
                while (xml.readNextStartElement()) {
                    if (xml.name() == QLatin1String("configItem")) {
                        while (xml.readNextStartElement()) {
                            if (xml.name() == QLatin1String("name")) layout = xml.readElementText();
                            else if (xml.name() == QLatin1String("description")) layoutDescription = xml.readElementText();
                            else xml.skipCurrentElement();
                        }
                        if (!layout.isEmpty()) m_layoutChoices.append(QVariantMap{{"id", layout + '+'}, {"layout", layout}, {"variant", ""}, {"label", layoutDescription}});
                    } else if (xml.name() == QLatin1String("variantList")) {
                        while (xml.readNextStartElement()) {
                            if (xml.name() != QLatin1String("variant")) { xml.skipCurrentElement(); continue; }
                            QString variant, description;
                            while (xml.readNextStartElement()) {
                                if (xml.name() != QLatin1String("configItem")) { xml.skipCurrentElement(); continue; }
                                while (xml.readNextStartElement()) {
                                    if (xml.name() == QLatin1String("name")) variant = xml.readElementText();
                                    else if (xml.name() == QLatin1String("description")) description = xml.readElementText();
                                    else xml.skipCurrentElement();
                                }
                            }
                            if (!layout.isEmpty() && !variant.isEmpty()) m_layoutChoices.append(QVariantMap{{"id", layout + '+' + variant}, {"layout", layout}, {"variant", variant}, {"label", description}});
                        }
                    } else xml.skipCurrentElement();
                }
            }
        }
        if (xml.hasError()) m_layoutChoices.clear();
    }
    bus.connect(QStringLiteral("org.kde.keyboard"), QStringLiteral("/Layouts"), QStringLiteral("org.kde.KeyboardLayouts"), QStringLiteral("layoutChanged"), this, SLOT(scheduleRefresh()));
    bus.connect(QStringLiteral("org.kde.keyboard"), QStringLiteral("/Layouts"), QStringLiteral("org.kde.KeyboardLayouts"), QStringLiteral("layoutListChanged"), this, SLOT(scheduleRefresh()));
    refresh();
}

void InputDevicesController::scheduleRefresh() { m_refreshTimer.start(); }

void InputDevicesController::refresh()
{
    if (m_busy) { scheduleRefresh(); return; }
    refreshKeyboardLayouts();
    const int generation = ++m_generation;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(
        getProperties(manager, QStringLiteral("org.kde.KWin.InputDeviceManager")), 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<QVariantMap> reply = *call; call->deleteLater();
        if (generation != m_generation) return;
        if (reply.isError()) { m_available = false; m_devices.clear(); m_error = reply.error().message(); Q_EMIT changed(); return; }
        m_available = true;
        const auto ids = reply.value().value("devicesSysNames").toStringList();
        auto results = std::make_shared<QMap<QString, QVariantMap>>();
        auto remaining = std::make_shared<int>(0);
        for (const auto &id : ids) {
            if (!QRegularExpression(QStringLiteral("^event[0-9]+$")).match(id).hasMatch()) continue;
            ++*remaining;
            auto *deviceCall = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(getProperties(manager + '/' + id, deviceInterface), 3000), this);
            connect(deviceCall, &QDBusPendingCallWatcher::finished, this, [this, generation, id, results, remaining](QDBusPendingCallWatcher *finished) {
                const QDBusPendingReply<QVariantMap> values = *finished; finished->deleteLater();
                if (generation != m_generation) return;
                if (!values.isError()) {
                    const auto state = values.value();
                    if (state.value("pointer").toBool() || state.value("touchpad").toBool()) {
                        QVariantMap capabilities;
                        for (auto it = booleanCapabilities.begin(); it != booleanCapabilities.end(); ++it)
                            capabilities.insert(it.key(), state.contains(it.key()) && state.value(it.value()).toBool());
                        capabilities.insert("pointerAcceleration", state.value("supportsPointerAcceleration").toBool());
                        capabilities.insert("scrollFactor", state.contains("scrollFactor"));
                        results->insert(id, {{"id", id}, {"name", state.value("name")},
                            {"touchpad", state.value("touchpad")}, {"values", state}, {"capabilities", capabilities}});
                    }
                }
                if (--*remaining == 0) {
                    m_devices.clear();
                    for (const auto &result : *results) m_devices.append(result);
                    Q_EMIT changed();
                }
            });
        }
        if (*remaining == 0) { m_devices.clear(); Q_EMIT changed(); }
    });
}

void InputDevicesController::setValue(const QString &id, const QString &property, const QVariant &value)
{
    if (m_busy) return;
    QVariantMap selected;
    for (const auto &device : m_devices) if (device.toMap().value("id").toString() == id) selected = device.toMap();
    if (selected.isEmpty() || !selected.value("capabilities").toMap().value(property).toBool()) {
        m_error = tr("This input device does not support the requested setting."); Q_EMIT changed(); return;
    }
    if (booleanCapabilities.contains(property)) {
        if (value.metaType().id() != QMetaType::Bool) { m_error = tr("Invalid input setting."); Q_EMIT changed(); return; }
    } else if (property == "pointerAcceleration" || property == "scrollFactor") {
        bool valid = false; const double number = value.toDouble(&valid);
        const double minimum = property == "pointerAcceleration" ? -1.0 : 0.1;
        const double maximum = property == "pointerAcceleration" ? 1.0 : 10.0;
        if (!valid || !qIsFinite(number) || number < minimum || number > maximum) {
            m_error = tr("Input speed is outside the supported range."); Q_EMIT changed(); return;
        }
    } else { m_error = tr("Unsupported input setting."); Q_EMIT changed(); return; }
    m_busy = true; m_error.clear(); ++m_generation; Q_EMIT changed();
    auto request = QDBusMessage::createMethodCall(service, manager + '/' + id, properties, QStringLiteral("Set"));
    request << deviceInterface << property << QVariant::fromValue(QDBusVariant(value));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(request, 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<> result = *call;
        if (result.isError()) m_error = result.error().message();
        call->deleteLater(); m_busy = false; Q_EMIT changed(); refresh();
    });
}

void InputDevicesController::refreshKeyboardLayouts()
{
    const int generation = ++m_keyboardGeneration;
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc")); config->reparseConfiguration();
    const KConfigGroup group(config, QStringLiteral("Layout"));
    const auto layouts = group.readEntry("LayoutList", QStringList());
    const auto variants = group.readEntry("VariantList", QStringList());
    m_configuredLayouts.clear();
    for (int index = 0; index < layouts.size(); ++index) m_configuredLayouts.append(layouts[index] + '+' + variants.value(index));
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.keyboard"), QStringLiteral("/Layouts"),
        QStringLiteral("org.kde.KeyboardLayouts"), QStringLiteral("getLayoutsList"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        if (generation != m_keyboardGeneration) { call->deleteLater(); return; }
        const QDBusMessage result = call->reply();
        m_keyboardLayouts.clear();
        if (result.type() != QDBusMessage::ErrorMessage && !result.arguments().isEmpty()) {
            const auto argument = qvariant_cast<QDBusArgument>(result.arguments().first()); argument.beginArray();
            while (!argument.atEnd()) {
                QString shortName, displayName, longName;
                argument.beginStructure(); argument >> shortName >> displayName >> longName; argument.endStructure();
                m_keyboardLayouts.append(QVariantMap{{"label", longName.isEmpty() ? displayName : longName}, {"shortName", shortName}});
            }
            argument.endArray();
        }
        call->deleteLater(); Q_EMIT changed();
    });
    auto current = QDBusMessage::createMethodCall(QStringLiteral("org.kde.keyboard"), QStringLiteral("/Layouts"),
        QStringLiteral("org.kde.KeyboardLayouts"), QStringLiteral("getLayout"));
    auto *active = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(current, 3000), this);
    connect(active, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *call) {
        if (generation != m_keyboardGeneration) { call->deleteLater(); return; }
        const QDBusPendingReply<uint> result = *call;
        m_activeKeyboardLayout = result.isError() ? -1 : int(result.value());
        call->deleteLater(); Q_EMIT changed();
    });
}

void InputDevicesController::activateKeyboardLayout(int index)
{
    if (m_busy || index < 0 || index >= m_keyboardLayouts.size()) return;
    m_busy = true; m_error.clear(); ++m_keyboardGeneration; Q_EMIT changed();
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.keyboard"), QStringLiteral("/Layouts"),
        QStringLiteral("org.kde.KeyboardLayouts"), QStringLiteral("setLayout"));
    message << uint(index);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<bool> result = *call;
        if (result.isError() || !result.value()) m_error = result.isError() ? result.error().message() : tr("The layout could not be activated.");
        call->deleteLater(); m_busy = false; Q_EMIT changed(); refresh();
    });
}

void InputDevicesController::configureKeyboardLayouts(const QVariantList &ids)
{
    if (m_busy) return;
    if (ids.isEmpty() || ids.size() > 4) { m_error = tr("Choose between one and four keyboard layouts."); Q_EMIT changed(); return; }
    QStringList layouts, variants;
    for (const auto &id : ids) {
        QVariantMap choice;
        for (const auto &candidate : m_layoutChoices) if (candidate.toMap().value("id") == id) choice = candidate.toMap();
        if (choice.isEmpty() || ids.count(id) != 1) { m_error = tr("Choose a unique supported keyboard layout."); Q_EMIT changed(); return; }
        layouts.append(choice.value("layout").toString()); variants.append(choice.value("variant").toString());
    }
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc"));
    KConfigGroup group(config, QStringLiteral("Layout"));
    group.writeEntry("LayoutList", layouts, KConfig::Notify);
    group.writeEntry("VariantList", variants.size() == 1 && variants.first().isEmpty() ? QStringList() : variants, KConfig::Notify);
    group.writeEntry("Use", true, KConfig::Notify);
    if (!group.sync()) m_error = tr("Keyboard layouts could not be saved."); else m_error.clear();
    // KWin observes kxkbrc through KConfigWatcher; no session restart/reload.
    refresh();
}

QVariantMap InputDevicesController::keyRepeat() const
{
    const auto config = KSharedConfig::openConfig(QStringLiteral("kcminputrc")); config->reparseConfiguration();
    const auto group = config->group(QStringLiteral("Keyboard"));
    const bool accentDefault = qEnvironmentVariable("QT_IM_MODULE") == QStringLiteral("plasmaim");
    const QString mode = group.readEntry("KeyRepeat", accentDefault ? QStringLiteral("accent") : QStringLiteral("repeat"));
    return {{"mode", mode}, {"accentAvailable", accentDefault || mode == QStringLiteral("accent")},
        {"delay", group.readEntry("RepeatDelay", 600)}, {"rate", group.readEntry("RepeatRate", 25.0)},
        {"available", m_available && qEnvironmentVariable("XDG_SESSION_TYPE") == QStringLiteral("wayland")},
        {"writable", !group.isEntryImmutable("KeyRepeat") && !group.isEntryImmutable("RepeatDelay") && !group.isEntryImmutable("RepeatRate")}};
}
void InputDevicesController::configureKeyRepeat(const QString &mode, int delay, double rate)
{
    if (!keyRepeat().value("available").toBool() || !keyRepeat().value("writable").toBool()
        || !QStringList{QStringLiteral("repeat"), QStringLiteral("none"), QStringLiteral("accent")}.contains(mode)
        || (mode == QStringLiteral("accent") && !keyRepeat().value("accentAvailable").toBool())
        || delay < 100 || delay > 5000 || !qIsFinite(rate) || rate < 0.2 || rate > 200) {
        m_error = tr("Choose a supported key repeat mode, delay from 100 to 5000 ms, and rate from 0.2 to 200 per second."); Q_EMIT changed(); return;
    }
    const auto config = KSharedConfig::openConfig(QStringLiteral("kcminputrc"));
    auto group = config->group(QStringLiteral("Keyboard"));
    group.writeEntry("KeyRepeat", mode, KConfig::Notify);
    group.writeEntry("RepeatDelay", delay, KConfig::Notify);
    group.writeEntry("RepeatRate", rate, KConfig::Notify);
    if (!config->sync()) m_error = tr("The keyboard repeat preference could not be saved."); else m_error.clear();
    // KWin observes this exact group and publishes the new repeat information
    // to Wayland clients. No compositor restart or synthetic key event.
    Q_EMIT changed();
}
