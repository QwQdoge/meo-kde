#pragma once

#include <QObject>

class MediaController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY mediaChanged)
    Q_PROPERTY(QString playerName READ playerName NOTIFY mediaChanged)
    Q_PROPERTY(QString title READ title NOTIFY mediaChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY mediaChanged)
    Q_PROPERTY(QString iconName READ iconName NOTIFY mediaChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY mediaChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY mediaChanged)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY mediaChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit MediaController(QObject *parent = nullptr);

    bool available() const;
    QString playerName() const;
    QString title() const;
    QString artist() const;
    QString iconName() const;
    bool playing() const;
    bool canGoNext() const;
    bool canGoPrevious() const;
    QString lastError() const;

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void mediaChanged();
    void errorChanged();

private Q_SLOTS:
    void refresh();

private:
    void callPlayerMethod(const QString &method);
    void setError(const QString &error);

    QString m_service;
    QString m_playerName;
    QString m_title;
    QString m_artist;
    QString m_iconName;
    bool m_playing = false;
    bool m_canGoNext = false;
    bool m_canGoPrevious = false;
    QString m_lastError;
};
