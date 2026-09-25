#pragma once

#include <QDateTime>
#include <QFileSystemWatcher>
#include <QObject>
#include <QVariantList>

// Read-only weather cache projection for session entry. A separate MeoKDE
// provider may refresh this cache in the user session; the lock-screen bridge
// deliberately has no network code or provider credentials.
class WeatherCache final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Weather")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(bool available READ available NOTIFY weatherChanged)
    Q_PROPERTY(bool stale READ stale NOTIFY weatherChanged)
    Q_PROPERTY(QString temperatureText READ temperatureText NOTIFY weatherChanged)
    Q_PROPERTY(QString condition READ condition NOTIFY weatherChanged)
    Q_PROPERTY(QString iconName READ iconName NOTIFY weatherChanged)
    Q_PROPERTY(QString location READ location NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList forecast READ forecast NOTIFY weatherChanged)
    Q_PROPERTY(QDateTime updatedAt READ updatedAt NOTIFY weatherChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit WeatherCache(QObject *parent = nullptr);

    bool available() const;
    bool stale() const;
    QString temperatureText() const;
    QString condition() const;
    QString iconName() const;
    QString location() const;
    QVariantList forecast() const;
    QDateTime updatedAt() const;
    QString lastError() const;

    static QString cachePath();
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void weatherChanged();
    void errorChanged();

private:
    void reload();
    void updateWatchPaths();
    void clearWeather(const QString &error = {});
    void setError(const QString &error);

    QFileSystemWatcher m_watcher;
    bool m_available = false;
    bool m_stale = false;
    QString m_temperatureText;
    QString m_condition;
    QString m_iconName;
    QString m_location;
    QVariantList m_forecast;
    QDateTime m_updatedAt;
    QString m_lastError;
};
