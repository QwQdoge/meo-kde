#include "mediacontroller.h"

#include <KLocalizedString>

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QFileInfo>
#include <QRegularExpression>
#include <QUrl>

#include <algorithm>
#include <limits>
#include <memory>

namespace
{
constexpr auto kMprisPrefix = "org.mpris.MediaPlayer2.";
constexpr auto kMprisPath = "/org/mpris/MediaPlayer2";
constexpr auto kPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kPlayerInterface = "org.mpris.MediaPlayer2.Player";
constexpr auto kRootInterface = "org.mpris.MediaPlayer2";
constexpr int kDbusTimeoutMs = 750;
constexpr int kPositionRefreshMs = 1000;
constexpr qint64 kMaximumArtworkBytes = 5 * 1024 * 1024;

struct RefreshState {
    quint64 generation = 0;
    QString service;
    QVariantMap playerProperties;
    QVariantMap rootProperties;
    int completedCalls = 0;
    bool terminal = false;
};

QVariant unwrap(const QVariant &value)
{
    return value.canConvert<QDBusVariant>() ? value.value<QDBusVariant>().variant() : value;
}

QString boundedText(const QVariant &value, qsizetype maximumLength)
{
    QString result = unwrap(value).toString();
    result.remove(QRegularExpression(QStringLiteral("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F\\u202A-\\u202E\\u2066-\\u2069]")));
    return result.left(maximumLength).trimmed();
}

QStringList artistNames(const QVariant &value)
{
    const auto unwrapped = unwrap(value);
    QVariantList values = unwrapped.toList();
    if (unwrapped.canConvert<QStringList>()) {
        values.clear();
        for (const QString &name : unwrapped.toStringList()) {
            values.push_back(name);
        }
    }
    QStringList names;
    for (const auto &item : values) {
        const QString name = boundedText(item, 128);
        if (!name.isEmpty()) {
            names.push_back(name);
        }
    }
    return names;
}

QString safeIconName(const QVariant &value)
{
    const QString candidate = boundedText(value, 128);
    static const QRegularExpression validIconName(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+\\-]*$"));
    return validIconName.match(candidate).hasMatch() ? candidate : QString{};
}

QString safeLocalArtworkUrl(const QVariant &value)
{
    const QUrl url = QUrl::fromUserInput(boundedText(value, 2048));
    if (!url.isLocalFile()) {
        return {};
    }
    const QFileInfo artwork(url.toLocalFile());
    if (!artwork.isFile() || artwork.size() < 0 || artwork.size() > kMaximumArtworkBytes) {
        return {};
    }
    return url.toString(QUrl::FullyEncoded);
}

QString safeSessionArtworkUrl(const QVariant &value)
{
    const QString raw = boundedText(value, 2048);
    const QString local = safeLocalArtworkUrl(raw);
    if (!local.isEmpty()) {
        return local;
    }

    const QUrl url(raw);
    if (!url.isValid() || url.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) != 0
        || url.host().isEmpty() || !url.userInfo().isEmpty()) {
        return {};
    }
    return url.toString(QUrl::FullyEncoded);
}

qint64 millisecondsFromMicroseconds(const QVariant &value)
{
    bool ok = false;
    const qint64 microseconds = unwrap(value).toLongLong(&ok);
    return ok && microseconds > 0 ? microseconds / 1000 : 0;
}

QString repeatModeForMpris(const QString &loopStatus)
{
    if (loopStatus == QLatin1String("Track")) {
        return QStringLiteral("one");
    }
    if (loopStatus == QLatin1String("Playlist")) {
        return QStringLiteral("all");
    }
    return QStringLiteral("off");
}

QString mprisLoopStatus(const QString &mode)
{
    if (mode == QLatin1String("one")) {
        return QStringLiteral("Track");
    }
    if (mode == QLatin1String("all")) {
        return QStringLiteral("Playlist");
    }
    return QStringLiteral("None");
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

    m_positionTimer.setInterval(kPositionRefreshMs);
    m_positionTimer.setTimerType(Qt::CoarseTimer);
    connect(&m_positionTimer, &QTimer::timeout, this, &MediaController::refreshPosition);

    refresh();
}

bool MediaController::available() const { return !m_service.isEmpty(); }
int MediaController::playerCount() const { return m_services.size(); }
QString MediaController::playerName() const { return m_playerName; }
QString MediaController::title() const { return m_title; }
QString MediaController::artist() const { return m_artist; }
QString MediaController::album() const { return m_album; }
QString MediaController::iconName() const { return m_iconName; }
QString MediaController::artUrl() const { return m_artUrl; }
QString MediaController::remoteArtUrl() const { return m_remoteArtUrl; }
bool MediaController::playing() const { return m_playing; }
qint64 MediaController::durationMs() const { return m_durationMs; }
qint64 MediaController::positionMs() const { return m_positionMs; }
bool MediaController::controllable() const { return m_controllable; }
bool MediaController::canGoNext() const { return m_canGoNext; }
bool MediaController::canGoPrevious() const { return m_canGoPrevious; }
bool MediaController::canSeek() const { return m_canSeek; }
bool MediaController::shuffle() const { return m_shuffle; }
bool MediaController::shuffleSupported() const { return m_shuffleSupported; }
QString MediaController::repeatMode() const { return m_repeatMode; }
bool MediaController::repeatSupported() const { return m_repeatSupported; }
QString MediaController::lastError() const { return m_lastError; }

void MediaController::refresh()
{
    const quint64 generation = ++m_refreshGeneration;
    auto *interface = QDBusConnection::sessionBus().interface();
    if (!interface) {
        if (!m_services.isEmpty()) {
            m_services.clear();
        }
        clearMedia();
        return;
    }

    auto *watcher = new QDBusPendingCallWatcher(interface->asyncCall(QStringLiteral("ListNames")), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, generation](QDBusPendingCallWatcher *) {
        const QDBusPendingReply<QStringList> reply = *watcher;
        watcher->deleteLater();
        if (generation != m_refreshGeneration) {
            return;
        }
        if (reply.isError()) {
            if (!m_services.isEmpty()) {
                m_services.clear();
                Q_EMIT mediaChanged();
            }
            clearMedia();
            setError(reply.error().message());
            return;
        }

        QStringList services = reply.value();
        services.erase(std::remove_if(services.begin(), services.end(), [](const QString &service) {
            return !service.startsWith(QLatin1String(kMprisPrefix));
        }), services.end());
        std::sort(services.begin(), services.end());

        const bool servicesChanged = services != m_services;
        m_services = services;
        if (m_services.isEmpty()) {
            clearMedia();
            if (servicesChanged) {
                Q_EMIT mediaChanged();
            }
            return;
        }

        const QString service = m_services.contains(m_service) ? m_service : m_services.constFirst();
        if (servicesChanged) {
            Q_EMIT mediaChanged();
        }
        fetchPlayerProperties(service, generation);
    });
    QTimer::singleShot(kDbusTimeoutMs, watcher, [this, watcher, generation] {
        if (watcher->isFinished() || generation != m_refreshGeneration) {
            return;
        }
        ++m_refreshGeneration;
        clearMedia();
        setError(i18nd("meo-desktop", "The media service did not respond in time."));
    });
}

void MediaController::fetchPlayerProperties(const QString &service, quint64 generation)
{
    auto state = std::make_shared<RefreshState>();
    state->generation = generation;
    state->service = service;

    const auto requestProperties = [this, state](const QString &interfaceName, bool playerProperties) {
        QDBusInterface properties(state->service, QString::fromLatin1(kMprisPath),
                                  QString::fromLatin1(kPropertiesInterface), QDBusConnection::sessionBus());
        if (!properties.isValid()) {
            if (state->generation == m_refreshGeneration) {
                clearMedia();
                setError(i18nd("meo-desktop", "The media player is no longer available."));
            }
            state->terminal = true;
            return;
        }

        auto *watcher = new QDBusPendingCallWatcher(properties.asyncCall(QStringLiteral("GetAll"), interfaceName), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this,
                [this, state, watcher, playerProperties](QDBusPendingCallWatcher *) {
            const QDBusPendingReply<QVariantMap> reply = *watcher;
            watcher->deleteLater();
            if (state->terminal || state->generation != m_refreshGeneration) {
                return;
            }
            if (reply.isError()) {
                state->terminal = true;
                clearMedia();
                setError(reply.error().message());
                return;
            }
            if (playerProperties) {
                state->playerProperties = reply.value();
            } else {
                state->rootProperties = reply.value();
            }
            ++state->completedCalls;
            if (state->completedCalls == 2) {
                state->terminal = true;
                applyPlayerProperties(state->service, state->playerProperties, state->rootProperties);
            }
        });
        QTimer::singleShot(kDbusTimeoutMs, watcher, [this, state, watcher] {
            if (watcher->isFinished() || state->terminal || state->generation != m_refreshGeneration) {
                return;
            }
            state->terminal = true;
            clearMedia();
            setError(i18nd("meo-desktop", "The media player did not respond in time."));
        });
    };

    requestProperties(QString::fromLatin1(kPlayerInterface), true);
    if (!state->terminal) {
        requestProperties(QString::fromLatin1(kRootInterface), false);
    }
}

void MediaController::applyPlayerProperties(const QString &service,
                                            const QVariantMap &playerProperties,
                                            const QVariantMap &rootProperties)
{
    const QVariantMap metadata = unwrap(playerProperties.value(QStringLiteral("Metadata"))).toMap();
    const QString playerName = boundedText(rootProperties.value(QStringLiteral("Identity")), 128);
    const QString title = boundedText(metadata.value(QStringLiteral("xesam:title")), 256);
    const QString artist = artistNames(metadata.value(QStringLiteral("xesam:artist"))).join(QStringLiteral(" · ")).left(384);
    const QString album = boundedText(metadata.value(QStringLiteral("xesam:album")), 256);
    const QString iconName = safeIconName(rootProperties.value(QStringLiteral("DesktopEntry")));
    const QString artUrl = safeLocalArtworkUrl(metadata.value(QStringLiteral("mpris:artUrl")));
    const QString remoteArtUrl = safeSessionArtworkUrl(metadata.value(QStringLiteral("mpris:artUrl")));
    const bool playing = unwrap(playerProperties.value(QStringLiteral("PlaybackStatus"))).toString() == QLatin1String("Playing");
    const qint64 durationMs = millisecondsFromMicroseconds(metadata.value(QStringLiteral("mpris:length")));
    const qint64 positionMs = std::min(durationMs > 0 ? durationMs : std::numeric_limits<qint64>::max(),
                                       millisecondsFromMicroseconds(playerProperties.value(QStringLiteral("Position"))));
    const bool controllable = unwrap(playerProperties.value(QStringLiteral("CanControl"))).toBool();
    const bool canGoNext = controllable && unwrap(playerProperties.value(QStringLiteral("CanGoNext"))).toBool();
    const bool canGoPrevious = controllable && unwrap(playerProperties.value(QStringLiteral("CanGoPrevious"))).toBool();
    const bool canSeek = controllable && unwrap(playerProperties.value(QStringLiteral("CanSeek"))).toBool();
    const bool shuffleSupported = controllable && playerProperties.contains(QStringLiteral("Shuffle"));
    const bool shuffle = shuffleSupported && unwrap(playerProperties.value(QStringLiteral("Shuffle"))).toBool();
    const bool repeatSupported = controllable && playerProperties.contains(QStringLiteral("LoopStatus"));
    const QString repeatMode = repeatSupported
            ? repeatModeForMpris(unwrap(playerProperties.value(QStringLiteral("LoopStatus"))).toString())
            : QStringLiteral("off");
    const QString effectiveName = playerName.isEmpty()
            ? service.mid(QLatin1String(kMprisPrefix).size()) : playerName;

    const bool positionChanged = m_positionMs != positionMs;
    const bool stateChanged = m_service != service || m_playerName != effectiveName || m_title != title
            || m_artist != artist || m_album != album || m_iconName != iconName || m_artUrl != artUrl
            || m_remoteArtUrl != remoteArtUrl || m_playing != playing || m_durationMs != durationMs
            || m_controllable != controllable || m_canGoNext != canGoNext || m_canGoPrevious != canGoPrevious
            || m_canSeek != canSeek || m_shuffle != shuffle || m_shuffleSupported != shuffleSupported
            || m_repeatMode != repeatMode || m_repeatSupported != repeatSupported;

    m_service = service;
    m_playerName = effectiveName;
    m_title = title;
    m_artist = artist;
    m_album = album;
    m_iconName = iconName;
    m_artUrl = artUrl;
    m_remoteArtUrl = remoteArtUrl;
    m_playing = playing;
    m_durationMs = durationMs;
    m_positionMs = positionMs;
    m_controllable = controllable;
    m_canGoNext = canGoNext;
    m_canGoPrevious = canGoPrevious;
    m_canSeek = canSeek;
    m_shuffle = shuffle;
    m_shuffleSupported = shuffleSupported;
    m_repeatMode = repeatMode;
    m_repeatSupported = repeatSupported;

    if (m_playing && m_durationMs > 0) {
        if (!m_positionTimer.isActive()) {
            m_positionTimer.start();
        }
    } else {
        m_positionTimer.stop();
    }

    clearError();
    if (stateChanged) {
        Q_EMIT mediaChanged();
    }
    if (positionChanged) {
        Q_EMIT positionChanged();
    }
}

void MediaController::refreshPosition()
{
    if (m_service.isEmpty() || !m_playing || m_durationMs <= 0) {
        return;
    }

    const QString service = m_service;
    QDBusInterface properties(service, QString::fromLatin1(kMprisPath),
                              QString::fromLatin1(kPropertiesInterface), QDBusConnection::sessionBus());
    if (!properties.isValid()) {
        return;
    }

    auto *watcher = new QDBusPendingCallWatcher(
            properties.asyncCall(QStringLiteral("Get"), QString::fromLatin1(kPlayerInterface),
                                 QStringLiteral("Position")), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, service](QDBusPendingCallWatcher *) {
        const QDBusPendingReply<QDBusVariant> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError() || service != m_service) {
            return;
        }
        const qint64 rawMs = millisecondsFromMicroseconds(reply.value().variant());
        const qint64 nextPosition = std::max<qint64>(0, std::min(m_durationMs, rawMs));
        if (nextPosition != m_positionMs) {
            m_positionMs = nextPosition;
            Q_EMIT positionChanged();
        }
    });
}

void MediaController::callPlayerMethod(const QString &method)
{
    clearError();
    if (m_service.isEmpty() || !m_controllable) {
        setError(i18nd("meo-desktop", "No controllable media player is available."));
        return;
    }
    QDBusInterface player(m_service, QString::fromLatin1(kMprisPath), QString::fromLatin1(kPlayerInterface),
                          QDBusConnection::sessionBus());
    if (!player.isValid()) {
        setError(i18nd("meo-desktop", "The media player is no longer available."));
        refresh();
        return;
    }

    auto completed = std::make_shared<bool>(false);
    auto *watcher = new QDBusPendingCallWatcher(player.asyncCall(method), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, completed](QDBusPendingCallWatcher *) {
        if (*completed) {
            watcher->deleteLater();
            return;
        }
        *completed = true;
        const QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            setError(reply.error().message());
        }
        refresh();
    });
    QTimer::singleShot(kDbusTimeoutMs, watcher, [this, watcher, completed] {
        if (watcher->isFinished() || *completed) {
            return;
        }
        *completed = true;
        setError(i18nd("meo-desktop", "The media player did not respond in time."));
        refresh();
    });
}

void MediaController::setPlayerProperty(const QString &property, const QVariant &value)
{
    clearError();
    if (m_service.isEmpty() || !m_controllable) {
        setError(i18nd("meo-desktop", "No controllable media player is available."));
        return;
    }

    QDBusInterface properties(m_service, QString::fromLatin1(kMprisPath),
                              QString::fromLatin1(kPropertiesInterface), QDBusConnection::sessionBus());
    if (!properties.isValid()) {
        setError(i18nd("meo-desktop", "The media player is no longer available."));
        refresh();
        return;
    }

    auto *watcher = new QDBusPendingCallWatcher(
            properties.asyncCall(QStringLiteral("Set"), QString::fromLatin1(kPlayerInterface), property,
                                 QVariant::fromValue(QDBusVariant(value))), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher](QDBusPendingCallWatcher *) {
        const QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            setError(reply.error().message());
        }
        refresh();
    });
}

void MediaController::seekTo(qint64 positionMs)
{
    clearError();
    if (m_service.isEmpty() || !m_controllable || !m_canSeek || m_durationMs <= 0) {
        return;
    }

    const qint64 bounded = std::max<qint64>(0, std::min(m_durationMs, positionMs));
    const qint64 offsetUs = (bounded - m_positionMs) * 1000;

    QDBusInterface player(m_service, QString::fromLatin1(kMprisPath), QString::fromLatin1(kPlayerInterface),
                          QDBusConnection::sessionBus());
    if (!player.isValid()) {
        setError(i18nd("meo-desktop", "The media player is no longer available."));
        refresh();
        return;
    }

    auto *watcher = new QDBusPendingCallWatcher(
            player.asyncCall(QStringLiteral("Seek"), QVariant::fromValue<qlonglong>(offsetUs)), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, bounded](QDBusPendingCallWatcher *) {
        const QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            setError(reply.error().message());
            return;
        }
        if (m_positionMs != bounded) {
            m_positionMs = bounded;
            Q_EMIT positionChanged();
        }
        refreshPosition();
    });
}

void MediaController::setShuffle(bool enabled)
{
    if (!m_shuffleSupported) {
        return;
    }
    setPlayerProperty(QStringLiteral("Shuffle"), enabled);
}

void MediaController::setRepeatMode(const QString &mode)
{
    if (!m_repeatSupported) {
        return;
    }
    setPlayerProperty(QStringLiteral("LoopStatus"), mprisLoopStatus(mode));
}

void MediaController::selectRelativePlayer(int delta)
{
    if (m_services.size() < 2) {
        return;
    }
    int index = m_services.indexOf(m_service);
    if (index < 0) {
        index = 0;
    }
    const int count = m_services.size();
    index = (index + delta) % count;
    if (index < 0) {
        index += count;
    }

    const quint64 generation = ++m_refreshGeneration;
    fetchPlayerProperties(m_services.at(index), generation);
}

void MediaController::selectNextPlayer()
{
    selectRelativePlayer(1);
}

void MediaController::selectPreviousPlayer()
{
    selectRelativePlayer(-1);
}

void MediaController::playPause() { callPlayerMethod(QStringLiteral("PlayPause")); }
void MediaController::next() { callPlayerMethod(QStringLiteral("Next")); }
void MediaController::previous() { callPlayerMethod(QStringLiteral("Previous")); }

void MediaController::clearMedia()
{
    m_positionTimer.stop();
    const bool positionChanged = m_positionMs != 0;
    const bool hadMedia = !m_service.isEmpty() || !m_playerName.isEmpty() || !m_title.isEmpty()
            || !m_artist.isEmpty() || !m_album.isEmpty() || !m_iconName.isEmpty() || !m_artUrl.isEmpty()
            || !m_remoteArtUrl.isEmpty() || m_playing || m_durationMs != 0 || m_controllable
            || m_canGoNext || m_canGoPrevious || m_canSeek || m_shuffle || m_shuffleSupported
            || m_repeatMode != QLatin1String("off") || m_repeatSupported;

    m_service.clear();
    m_playerName.clear();
    m_title.clear();
    m_artist.clear();
    m_album.clear();
    m_iconName.clear();
    m_artUrl.clear();
    m_remoteArtUrl.clear();
    m_playing = false;
    m_durationMs = 0;
    m_positionMs = 0;
    m_controllable = false;
    m_canGoNext = false;
    m_canGoPrevious = false;
    m_canSeek = false;
    m_shuffle = false;
    m_shuffleSupported = false;
    m_repeatMode = QStringLiteral("off");
    m_repeatSupported = false;

    if (hadMedia) {
        Q_EMIT mediaChanged();
    }
    if (positionChanged) {
        Q_EMIT positionChanged();
    }
}

void MediaController::clearError()
{
    setError({});
}

void MediaController::setError(const QString &error)
{
    if (m_lastError != error) {
        m_lastError = error;
        Q_EMIT errorChanged();
    }
}
