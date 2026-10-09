#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <KConfigWatcher>

class PlatformController final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("QML.Element", "Platform")
    Q_CLASSINFO("QML.Singleton", "true")
    Q_PROPERTY(QVariantMap screenLockPolicy READ screenLockPolicy NOTIFY screenLockPolicyChanged)
    Q_PROPERTY(bool screenLockPolicyBusy READ screenLockPolicyBusy NOTIFY screenLockPolicyChanged)
    Q_PROPERTY(bool brightnessAvailable READ brightnessAvailable NOTIFY brightnessChanged)
    Q_PROPERTY(QVariantList brightnessDisplays READ brightnessDisplays NOTIFY brightnessChanged)
    Q_PROPERTY(bool nightLightAvailable READ nightLightAvailable NOTIFY nightLightChanged)
    Q_PROPERTY(bool nightLightEnabled READ nightLightEnabled WRITE setNightLightEnabled NOTIFY nightLightChanged)
    Q_PROPERTY(bool nightLightRunning READ nightLightRunning NOTIFY nightLightChanged)
    Q_PROPERTY(int nightLightTemperature READ nightLightTemperature NOTIFY nightLightChanged)
    Q_PROPERTY(QVariantMap nightLightSettings READ nightLightSettings NOTIFY nightLightChanged)
    Q_PROPERTY(bool powerProfilesAvailable READ powerProfilesAvailable NOTIFY powerProfilesChanged)
    Q_PROPERTY(QStringList powerProfiles READ powerProfiles NOTIFY powerProfilesChanged)
    Q_PROPERTY(QString activePowerProfile READ activePowerProfile WRITE setActivePowerProfile NOTIFY powerProfilesChanged)
    Q_PROPERTY(QString powerProfileDegradedReason READ powerProfileDegradedReason NOTIFY powerProfilesChanged)
    Q_PROPERTY(bool keepAwake READ keepAwake WRITE setKeepAwake NOTIFY keepAwakeChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit PlatformController(QObject *parent = nullptr);
    QVariantMap screenLockPolicy() const;
    bool screenLockPolicyBusy() const { return m_screenLockPolicyBusy; }
    Q_INVOKABLE void configureScreenLock(bool automatic, qreal minutes, bool onResume, bool onStart, int graceSeconds);

    bool brightnessAvailable() const;
    QVariantList brightnessDisplays() const;
    bool nightLightAvailable() const;
    bool nightLightEnabled() const;
    bool nightLightRunning() const;
    int nightLightTemperature() const;
    QVariantMap nightLightSettings() const;
    Q_INVOKABLE void configureNightLight(int mode, int dayTemperature, int nightTemperature);
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
    Q_INVOKABLE bool openSystemAbout();
    Q_INVOKABLE bool openTaskManager();
    Q_INVOKABLE void clearError();

Q_SIGNALS:
    void brightnessChanged();
    void screenLockPolicyChanged();
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
    KConfigWatcher::Ptr m_nightLightWatcher;
    KConfigWatcher::Ptr m_screenLockWatcher;
    bool m_screenLockPolicyBusy = false;
};
