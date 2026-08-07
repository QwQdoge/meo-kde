#pragma once

#include <BluezQt/Manager>
#include <NetworkManagerQt/Manager>
#include <PulseAudioQt/Context>
#include <PulseAudioQt/Sink>
#include <Solid/Battery>
#include <Solid/Device>

#include <QObject>
#include <QString>

class SystemStateHub final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool networkAvailable READ networkAvailable NOTIFY networkChanged)
    Q_PROPERTY(bool networkConnected READ networkConnected NOTIFY networkChanged)
    Q_PROPERTY(bool wirelessEnabled READ wirelessEnabled WRITE setWirelessEnabled NOTIFY networkChanged)
    Q_PROPERTY(QString networkName READ networkName NOTIFY networkChanged)
    Q_PROPERTY(QString networkStatus READ networkStatus NOTIFY networkChanged)

    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY bluetoothChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothChanged)

    Q_PROPERTY(bool batteryAvailable READ batteryAvailable NOTIFY batteryChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChanged)

    Q_PROPERTY(bool audioAvailable READ audioAvailable NOTIFY audioChanged)
    Q_PROPERTY(int volumePercent READ volumePercent WRITE setVolumePercent NOTIFY audioChanged)
    Q_PROPERTY(bool audioMuted READ audioMuted WRITE setAudioMuted NOTIFY audioChanged)
    Q_PROPERTY(QString audioDevice READ audioDevice NOTIFY audioChanged)

public:
    explicit SystemStateHub(QObject *parent = nullptr);

    bool networkAvailable() const;
    bool networkConnected() const;
    bool wirelessEnabled() const;
    QString networkName() const;
    QString networkStatus() const;
    void setWirelessEnabled(bool enabled);

    bool bluetoothAvailable() const;
    bool bluetoothEnabled() const;
    void setBluetoothEnabled(bool enabled);

    bool batteryAvailable() const;
    int batteryPercent() const;
    bool batteryCharging() const;

    bool audioAvailable() const;
    int volumePercent() const;
    bool audioMuted() const;
    QString audioDevice() const;
    void setVolumePercent(int percent);
    void setAudioMuted(bool muted);

Q_SIGNALS:
    void networkChanged();
    void bluetoothChanged();
    void batteryChanged();
    void audioChanged();

private:
    void refreshBluetoothConnections();
    void refreshBattery();
    void bindAudioSink();

    BluezQt::Manager m_bluetoothManager;
    Solid::Device m_batteryDevice;
    Solid::Battery *m_battery = nullptr;
    PulseAudioQt::Context *m_audioContext = nullptr;
    PulseAudioQt::Sink *m_sink = nullptr;
};
