#include "mediacontroller.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QVariantMap>

#include <algorithm>

namespace
{
constexpr auto kMprisPrefix = "org.mpris.MediaPlayer2.";
constexpr auto kMprisPath = "/org/mpris/MediaPlayer2";
constexpr auto kPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kPlayerInterface = "org.mpris.MediaPlayer2.Player";
constexpr auto kRootInterface = "org.mpris.MediaPlayer2";

QVariant unwrap(const QVariant &value)
{
    return value.canConvert<QDBusVariant>() ? value.value<QDBusVariant>().variant() : value;
}

QStringList artistNames(const QVariant &value)
{
    const auto unwrapped = unwrap(value);
    if (unwrapped.canConvert<QStringList>()) {
        return unwrapped.toStringList();
    }
    const auto list = unwrapped.toList();
    QStringList names;
    for (const auto &item : list) {
        const QString name = unwrap(item).toString();
        if (!name.isEmpty()) {
            names.push_back(name);
        }
    }
    return names;
}
}

MediaController::MediaController(QObject *parent)
    : QObject(parent)
{
    auto bus = QDBusConnection::sessionBus();
    if (auto *interface = bus.interface()) {
        connect(interface, &QDBusConnectionInterface::serviceOwnerChanged, this,
                [this](const QString &service, const QString &, const QString &) {
                    if (service.startsWith(QLatin1String(kMprisPrefix))) {
                        refresh();
                    }
                });
    }
    bus.connect(QString(), QString::fromLatin1(kMprisPath), QString::fromLatin1(kPropertiesInterface),
                QStringLiteral("PropertiesChanged"), this, SLOT(refresh()));
    refresh();
}

bool MediaController::available() const { return !m_service.isEmpty(); }
QString MediaController::playerName() const { return m_playerName; }
QString MediaController::title() const { return m_title; }
QString MediaController::artist() const { return m_artist; }
QString MediaController::iconName() const { return m_iconName; }
bool MediaController::playing() const { return m_playing; }
bool MediaController::canGoNext() const { return m_canGoNext; }
bool MediaController::canGoPrevious() const { return m_canGoPrevious; }
QString MediaController::lastError() const { return m_lastError; }

void MediaController::refresh()
{
    QStringList services;
    if (auto *interface = QDBusConnection::sessionBus().interface()) {
        services = interface->registeredServiceNames();
    }
    services.erase(std::remove_if(services.begin(), services.end(), [](const QString &service) {
        return !service.startsWith(QLatin1String(kMprisPrefix));
    }), services.end());
    std::sort(services.begin(), services.end());

    const QString nextService = services.isEmpty() ? QString{} : services.constFirst();
    QVariantMap playerProperties;
    QVariantMap rootProperties;
    if (!nextService.isEmpty()) {
        QDBusInterface player(nextService, QString::fromLatin1(kMprisPath),
                              QString::fromLatin1(kPropertiesInterface), QDBusConnection::sessionBus());
        const QDBusReply<QVariantMap> playerReply = player.call(
            QStringLiteral("GetAll"), QString::fromLatin1(kPlayerInterface));
        const QDBusReply<QVariantMap> rootReply = player.call(
            QStringLiteral("GetAll"), QString::fromLatin1(kRootInterface));
        if (playerReply.isValid()) {
            playerProperties = playerReply.value();
        }
        if (rootReply.isValid()) {
            rootProperties = rootReply.value();
        }
    }
    const QVariantMap metadata = unwrap(playerProperties.value(QStringLiteral("Metadata"))).toMap();

    const QString playerName = unwrap(rootProperties.value(QStringLiteral("Identity"))).toString();
    const QString title = unwrap(metadata.value(QStringLiteral("xesam:title"))).toString();
    const QString artist = artistNames(metadata.value(QStringLiteral("xesam:artist"))).join(QStringLiteral(" · "));
    const QString iconName = unwrap(rootProperties.value(QStringLiteral("DesktopEntry"))).toString();
    const bool playing = unwrap(playerProperties.value(QStringLiteral("PlaybackStatus"))).toString() == QLatin1String("Playing");
    const bool canGoNext = unwrap(playerProperties.value(QStringLiteral("CanGoNext"))).toBool();
    const bool canGoPrevious = unwrap(playerProperties.value(QStringLiteral("CanGoPrevious"))).toBool();

    if (m_service == nextService && m_playerName == playerName && m_title == title
        && m_artist == artist && m_iconName == iconName && m_playing == playing
        && m_canGoNext == canGoNext && m_canGoPrevious == canGoPrevious) {
        return;
    }
    m_service = nextService;
    m_playerName = playerName.isEmpty() ? nextService.mid(QLatin1String(kMprisPrefix).size()) : playerName;
    m_title = title;
    m_artist = artist;
    m_iconName = iconName;
    m_playing = playing;
    m_canGoNext = canGoNext;
    m_canGoPrevious = canGoPrevious;
    Q_EMIT mediaChanged();
}

void MediaController::callPlayerMethod(const QString &method)
{
    clearError();
    if (m_service.isEmpty()) {
        setError(tr("No media player is available."));
        return;
    }
    QDBusInterface player(m_service, QString::fromLatin1(kMprisPath), QString::fromLatin1(kPlayerInterface),
                          QDBusConnection::sessionBus());
    if (!player.isValid()) {
        setError(tr("The media player is no longer available."));
        refresh();
        return;
    }
    auto *watcher = new QDBusPendingCallWatcher(player.asyncCall(method), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher](QDBusPendingCallWatcher *) {
        const QDBusPendingReply<> reply = *watcher;
        if (reply.isError()) {
            setError(reply.error().message());
        }
        watcher->deleteLater();
        refresh();
    });
}

void MediaController::playPause() { callPlayerMethod(QStringLiteral("PlayPause")); }
void MediaController::next() { callPlayerMethod(QStringLiteral("Next")); }
void MediaController::previous() { callPlayerMethod(QStringLiteral("Previous")); }
void MediaController::clearError() { setError({}); }
void MediaController::setError(const QString &error) { if (m_lastError != error) { m_lastError = error; Q_EMIT errorChanged(); } }
