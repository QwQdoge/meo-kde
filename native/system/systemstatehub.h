#pragma once

#include <BluezQt/Manager>
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/Utils>
#include <NetworkManagerQt/WirelessDevice>
#include <PulseAudioQt/Context>
#include <PulseAudioQt/Sink>
#include <PulseAudioQt/Source>
#include <Solid/Battery>
#include <Solid/Device>

#include <QObject>
#include <QString>
#include <QVariantList>

class SystemStateHub final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool networkAvailable READ networkAvailable NOTIFY networkChanged)
    Q_PROPERTY(bool networkConnected READ networkConnected NOTIFY networkChanged)
    Q_PROPERTY(bool wirelessEnabled READ wirelessEnabled WRITE setWirelessEnabled NOTIFY networkChanged)
    Q_PROPERTY(QString networkName READ networkName NOTIFY networkChanged)
    Q_PROPERTY(QString networkStatus READ networkStatus NOTIFY networkChanged)
    Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)
    Q_PROPERTY(bool wifiScanning READ wifiScanning NOTIFY wifiScanningChanged)
    Q_PROPERTY(bool networkBusy READ networkBusy NOTIFY networkOperationChanged)

    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY bluetoothChanged)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothChanged)
    Q_PROPERTY(QVariantList bluetoothDevices READ bluetoothDevices NOTIFY bluetoothDevicesChanged)
    Q_PROPERTY(bool bluetoothDiscovering READ bluetoothDiscovering NOTIFY bluetoothChanged)
    Q_PROPERTY(bool bluetoothBusy READ bluetoothBusy NOTIFY bluetoothOperationChanged)

    Q_PROPERTY(bool batteryAvailable READ batteryAvailable NOTIFY batteryChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChanged)

    Q_PROPERTY(bool audioAvailable READ audioAvailable NOTIFY audioChanged)
    Q_PROPERTY(int volumePercent READ volumePercent WRITE setVolumePercent NOTIFY audioChanged)
    Q_PROPERTY(bool audioMuted READ audioMuted WRITE setAudioMuted NOTIFY audioChanged)
    Q_PROPERTY(QString audioDevice READ audioDevice NOTIFY audioChanged)
    Q_PROPERTY(QVariantList audioOutputDevices READ audioOutputDevices NOTIFY audioChanged)
    Q_PROPERTY(bool microphoneAvailable READ microphoneAvailable NOTIFY audioChanged)
    Q_PROPERTY(int microphoneVolumePercent READ microphoneVolumePercent WRITE setMicrophoneVolumePercent NOTIFY audioChanged)
    Q_PROPERTY(bool microphoneMuted READ microphoneMuted WRITE setMicrophoneMuted NOTIFY audioChanged)
    Q_PROPERTY(QString microphoneDevice READ microphoneDevice NOTIFY audioChanged)
    Q_PROPERTY(QVariantList audioInputDevices READ audioInputDevices NOTIFY audioChanged)

    Q_PROPERTY(bool operationBusy READ operationBusy NOTIFY operationChanged)
    Q_PROPERTY(QString operationError READ operationError NOTIFY operationChanged)

public:
    explicit SystemStateHub(QObject *parent = nullptr);

    bool networkAvailable() const;
    bool networkConnected() const;
    bool wirelessEnabled() const;
    QString networkName() const;
    QString networkStatus() const;
    QVariantList wifiNetworks() const;
    bool wifiScanning() const;
    bool networkBusy() const;
    void setWirelessEnabled(bool enabled);

    bool bluetoothAvailable() const;
    bool bluetoothEnabled() const;
    QVariantList bluetoothDevices() const;
    bool bluetoothDiscovering() const;
    bool bluetoothBusy() const;
    void setBluetoothEnabled(bool enabled);

    bool batteryAvailable() const;
    int batteryPercent() const;
    bool batteryCharging() const;

    bool audioAvailable() const;
    int volumePercent() const;
    bool audioMuted() const;
    QString audioDevice() const;
    QVariantList audioOutputDevices() const;
    bool microphoneAvailable() const;
    int microphoneVolumePercent() const;
    bool microphoneMuted() const;
    QString microphoneDevice() const;
    QVariantList audioInputDevices() const;
    void setVolumePercent(int percent);
    void setAudioMuted(bool muted);
    void setMicrophoneVolumePercent(int percent);
    void setMicrophoneMuted(bool muted);

    Q_INVOKABLE void requestWifiScan();
    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password = QString());
    Q_INVOKABLE void disconnectWifi();
    Q_INVOKABLE void startBluetoothDiscovery();
    Q_INVOKABLE void stopBluetoothDiscovery();
    Q_INVOKABLE void toggleBluetoothDevice(const QString &address);
    Q_INVOKABLE void forgetBluetoothDevice(const QString &address);
    Q_INVOKABLE void setDefaultAudioOutput(const QString &deviceId);
    Q_INVOKABLE void setDefaultAudioInput(const QString &deviceId);
    Q_INVOKABLE void clearOperationError();

    bool operationBusy() const;
    QString operationError() const;

Q_SIGNALS:
    void networkChanged();
    void wifiNetworksChanged();
    void wifiScanningChanged();
    void networkOperationChanged();
    void bluetoothChanged();
    void bluetoothDevicesChanged();
    void bluetoothOperationChanged();
    void batteryChanged();
    void audioChanged();
    void operationChanged();

private:
    void refreshWifiDevice();
    void bindWifiDevice();
    void refreshWifiState();
    void refreshBluetoothConnections();
    void refreshBluetoothState();
    void refreshBattery();
    void bindAudioSink();
    void bindAudioSource();
    void setNetworkBusy(bool busy);
    void setBluetoothBusy(bool busy);
    void setOperationError(const QString &error);
    NetworkManager::Connection::Ptr savedConnectionForSsid(const QString &ssid) const;
    QString securityLabel(NetworkManager::WirelessSecurityType security) const;
    QString bluetoothMaterialIcon(const BluezQt::DevicePtr &device) const;

    NetworkManager::WirelessDevice::Ptr m_wifiDevice;
    bool m_wifiScanning = false;
    bool m_networkBusy = false;
    BluezQt::Manager m_bluetoothManager;
    bool m_bluetoothBusy = false;
    Solid::Device m_batteryDevice;
    Solid::Battery *m_battery = nullptr;
    PulseAudioQt::Context *m_audioContext = nullptr;
    PulseAudioQt::Sink *m_sink = nullptr;
    PulseAudioQt::Source *m_source = nullptr;
    QString m_operationError;
};
