#include "mediacontroller.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>

#include <algorithm>
#include <memory>

namespace
{
constexpr auto kMprisPrefix = "org.mpris.MediaPlayer2.";
constexpr auto kMprisPath = "/org/mpris/MediaPlayer2";
constexpr auto kPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kPlayerInterface = "org.mpris.MediaPlayer2.Player";
constexpr auto kRootInterface = "org.mpris.MediaPlayer2";
constexpr int kDbusTimeoutMs = 750;
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

QString safeArtworkUrl(const QVariant &value)
{
    const QUrl url = QUrl::fromUserInput(boundedText(value, 2048));
    // MPRIS http(s) art URLs must never make the lock screen initiate a
    // network request. Only a present, local, size-bounded file is allowed.
    if (!url.isLocalFile()) {
        return {};
    }
    const QFileInfo artwork(url.toLocalFile());
    if (!artwork.isFile() || artwork.size() < 0 || artwork.size() > kMaximumArtworkBytes) {
        return {};
    }
    return url.toString(QUrl::FullyEncoded);
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
QString MediaController::artUrl() const { return m_artUrl; }
bool MediaController::playing() const { return m_playing; }
bool MediaController::controllable() const { return m_controllable; }
bool MediaController::canGoNext() const { return m_canGoNext; }
bool MediaController::canGoPrevious() const { return m_canGoPrevious; }
QString MediaController::lastError() const { return m_lastError; }

void MediaController::refresh()
{
    const quint64 generation = ++m_refreshGeneration;
    auto *interface = QDBusConnection::sessionBus().interface();
    if (!interface) {
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
            clearMedia();
            setError(reply.error().message());
            return;
        }

        QStringList services = reply.value();
        services.erase(std::remove_if(services.begin(), services.end(), [](const QString &service) {
            return !service.startsWith(QLatin1String(kMprisPrefix));
        }), services.end());
        std::sort(services.begin(), services.end());
        if (services.isEmpty()) {
            clearMedia();
            return;
        }
        fetchPlayerProperties(services.constFirst(), generation);
    });
    QTimer::singleShot(kDbusTimeoutMs, watcher, [this, watcher, generation] {
        if (watcher->isFinished() || generation != m_refreshGeneration) {
            return;
        }
        ++m_refreshGeneration;
        clearMedia();
        setError(tr("The media service did not respond in time."));
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
                setError(tr("The media player is no longer available."));
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
            setError(tr("The media player did not respond in time."));
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
    const QString iconName = safeIconName(rootProperties.value(QStringLiteral("DesktopEntry")));
    const QString artUrl = safeArtworkUrl(metadata.value(QStringLiteral("mpris:artUrl")));
    const bool playing = unwrap(playerProperties.value(QStringLiteral("PlaybackStatus"))).toString() == QLatin1String("Playing");
    const bool controllable = unwrap(playerProperties.value(QStringLiteral("CanControl"))).toBool();
    const bool canGoNext = controllable && unwrap(playerProperties.value(QStringLiteral("CanGoNext"))).toBool();
    const bool canGoPrevious = controllable && unwrap(playerProperties.value(QStringLiteral("CanGoPrevious"))).toBool();
    const QString effectiveName = playerName.isEmpty()
            ? service.mid(QLatin1String(kMprisPrefix).size()) : playerName;

    if (m_service == service && m_playerName == effectiveName && m_title == title
        && m_artist == artist && m_iconName == iconName && m_artUrl == artUrl
        && m_playing == playing && m_controllable == controllable
        && m_canGoNext == canGoNext && m_canGoPrevious == canGoPrevious) {
        return;
    }
    m_service = service;
    m_playerName = effectiveName;
    m_title = title;
    m_artist = artist;
    m_iconName = iconName;
    m_artUrl = artUrl;
    m_playing = playing;
    m_controllable = controllable;
    m_canGoNext = canGoNext;
    m_canGoPrevious = canGoPrevious;
    clearError();
    Q_EMIT mediaChanged();
}

void MediaController::clearMedia()
{
    if (m_service.isEmpty() && m_playerName.isEmpty() && m_title.isEmpty() && m_artist.isEmpty()
        && m_iconName.isEmpty() && m_artUrl.isEmpty() && !m_playing && !m_controllable
        && !m_canGoNext && !m_canGoPrevious) {
        return;
    }
    m_service.clear();
    m_playerName.clear();
    m_title.clear();
    m_artist.clear();
    m_iconName.clear();
    m_artUrl.clear();
    m_playing = false;
    m_controllable = false;
    m_canGoNext = false;
    m_canGoPrevious = false;
    Q_EMIT mediaChanged();
}

void MediaController::callPlayerMethod(const QString &method)
{
    clearError();
    if (m_service.isEmpty() || !m_controllable) {
        setError(tr("No controllable media player is available."));
        return;
    }
    QDBusInterface player(m_service, QString::fromLatin1(kMprisPath), QString::fromLatin1(kPlayerInterface),
                          QDBusConnection::sessionBus());
    if (!player.isValid()) {
        setError(tr("The media player is no longer available."));
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
        setError(tr("The media player did not respond in time."));
        refresh();
    });
}

void MediaController::playPause() { callPlayerMethod(QStringLiteral("PlayPause")); }
void MediaController::next() { callPlayerMethod(QStringLiteral("Next")); }
void MediaController::previous() { callPlayerMethod(QStringLiteral("Previous")); }
void MediaController::clearError() { setError({}); }
void MediaController::setError(const QString &error) { if (m_lastError != error) { m_lastError = error; Q_EMIT errorChanged(); } }
