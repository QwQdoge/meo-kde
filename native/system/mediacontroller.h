#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class MediaController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Media")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool available READ available NOTIFY mediaChanged)
    Q_PROPERTY(int playerCount READ playerCount NOTIFY mediaChanged)
    Q_PROPERTY(QString playerName READ playerName NOTIFY mediaChanged)
    Q_PROPERTY(QString title READ title NOTIFY mediaChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY mediaChanged)
    Q_PROPERTY(QString album READ album NOTIFY mediaChanged)
    Q_PROPERTY(QString iconName READ iconName NOTIFY mediaChanged)
    // artUrl is deliberately local-only so privacy-sensitive hosts such as
    // the lock screen never initiate a network request.
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY mediaChanged)
    // Desktop/session surfaces may opt into the original HTTPS artwork.
    Q_PROPERTY(QString remoteArtUrl READ remoteArtUrl NOTIFY mediaChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY mediaChanged)
    Q_PROPERTY(qint64 durationMs READ durationMs NOTIFY mediaChanged)
    Q_PROPERTY(qint64 positionMs READ positionMs NOTIFY positionChanged)
    Q_PROPERTY(bool controllable READ controllable NOTIFY mediaChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY mediaChanged)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY mediaChanged)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY mediaChanged)
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY mediaChanged)
    Q_PROPERTY(bool shuffleSupported READ shuffleSupported NOTIFY mediaChanged)
    Q_PROPERTY(QString repeatMode READ repeatMode NOTIFY mediaChanged)
    Q_PROPERTY(bool repeatSupported READ repeatSupported NOTIFY mediaChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit MediaController(QObject *parent = nullptr);

    bool available() const;
    int playerCount() const;
    QString playerName() const;
    QString title() const;
    QString artist() const;
    QString album() const;
    QString iconName() const;
    QString artUrl() const;
    QString remoteArtUrl() const;
    bool playing() const;
    qint64 durationMs() const;
    qint64 positionMs() const;
    bool controllable() const;
    bool canGoNext() const;
    bool canGoPrevious() const;
    bool canSeek() const;
    bool shuffle() const;
    bool shuffleSupported() const;
    QString repeatMode() const;
    bool repeatSupported() const;
    QString lastError() const;

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seekTo(qint64 positionMs);
    Q_INVOKABLE void setShuffle(bool enabled);
    Q_INVOKABLE void setRepeatMode(const QString &mode);
    Q_INVOKABLE void selectNextPlayer();
    Q_INVOKABLE void selectPreviousPlayer();
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void mediaChanged();
    void positionChanged();
    void errorChanged();

private Q_SLOTS:
    void refresh();
    void refreshPosition();

private:
    void callPlayerMethod(const QString &method);
    void setPlayerProperty(const QString &property, const QVariant &value);
    void fetchPlayerProperties(const QString &service, quint64 generation);
    void applyPlayerProperties(const QString &service,
                               const QVariantMap &playerProperties,
                               const QVariantMap &rootProperties);
    void selectRelativePlayer(int delta);
    void clearMedia();
    void setError(const QString &error);

    QStringList m_services;
    QString m_service;
    QString m_playerName;
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_iconName;
    QString m_artUrl;
    QString m_remoteArtUrl;
    bool m_playing = false;
    qint64 m_durationMs = 0;
    qint64 m_positionMs = 0;
    bool m_controllable = false;
    bool m_canGoNext = false;
    bool m_canGoPrevious = false;
    bool m_canSeek = false;
    bool m_shuffle = false;
    bool m_shuffleSupported = false;
    QString m_repeatMode = QStringLiteral("off");
    bool m_repeatSupported = false;
    QString m_lastError;
    QTimer m_positionTimer;
    quint64 m_refreshGeneration = 0;
};
