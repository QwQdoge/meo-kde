#pragma once

#include <QObject>
#include <QVariantList>

class PlatformController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool brightnessAvailable READ brightnessAvailable NOTIFY brightnessChanged)
    Q_PROPERTY(QVariantList brightnessDisplays READ brightnessDisplays NOTIFY brightnessChanged)
    Q_PROPERTY(bool nightLightAvailable READ nightLightAvailable NOTIFY nightLightChanged)
    Q_PROPERTY(bool nightLightEnabled READ nightLightEnabled WRITE setNightLightEnabled NOTIFY nightLightChanged)
    Q_PROPERTY(bool nightLightRunning READ nightLightRunning NOTIFY nightLightChanged)
    Q_PROPERTY(int nightLightTemperature READ nightLightTemperature NOTIFY nightLightChanged)
    Q_PROPERTY(bool powerProfilesAvailable READ powerProfilesAvailable NOTIFY powerProfilesChanged)
    Q_PROPERTY(QStringList powerProfiles READ powerProfiles NOTIFY powerProfilesChanged)
    Q_PROPERTY(QString activePowerProfile READ activePowerProfile WRITE setActivePowerProfile NOTIFY powerProfilesChanged)
    Q_PROPERTY(QString powerProfileDegradedReason READ powerProfileDegradedReason NOTIFY powerProfilesChanged)
    Q_PROPERTY(bool keepAwake READ keepAwake WRITE setKeepAwake NOTIFY keepAwakeChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit PlatformController(QObject *parent = nullptr);

    bool brightnessAvailable() const;
    QVariantList brightnessDisplays() const;
    bool nightLightAvailable() const;
    bool nightLightEnabled() const;
    bool nightLightRunning() const;
    int nightLightTemperature() const;
    bool powerProfilesAvailable() const;
    QStringList powerProfiles() const;
    QString activePowerProfile() const;
    QString powerProfileDegradedReason() const;
    bool keepAwake() const;
    QString lastError() const;

    void setNightLightEnabled(bool enabled);
    void setActivePowerProfile(const QString &profile);
    void setKeepAwake(bool enabled);

    Q_INVOKABLE void setBrightness(const QString &displayId, int brightness);
    Q_INVOKABLE void lockScreen();
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void brightnessChanged();
    void nightLightChanged();
    void powerProfilesChanged();
    void keepAwakeChanged();
    void errorChanged();

private Q_SLOTS:
    void refreshBrightness();
    void refreshNightLight();
    void refreshPowerProfiles();

private:
    void setError(const QString &error);

    QVariantList m_brightnessDisplays;
    bool m_nightLightAvailable = false;
    bool m_nightLightEnabled = false;
    bool m_nightLightRunning = false;
    int m_nightLightTemperature = 0;
    QStringList m_powerProfiles;
    QString m_activePowerProfile;
    QString m_powerProfileDegradedReason;
    QObject *m_keepAwakeInhibitor = nullptr;
    QString m_lastError;
};
