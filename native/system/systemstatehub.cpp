#include "systemstatehub.h"

#include <BluezQt/Adapter>
#include <BluezQt/Battery>
#include <BluezQt/Device>
#include <BluezQt/InitManagerJob>
#include <BluezQt/Job>
#include <BluezQt/PendingCall>
#include <NetworkManagerQt/AccessPoint>
#include <NetworkManagerQt/ActiveConnection>
#include <NetworkManagerQt/Connection>
#include <NetworkManagerQt/ConnectionSettings>
#include <NetworkManagerQt/Settings>
#include <NetworkManagerQt/Utils>
#include <NetworkManagerQt/WirelessNetwork>
#include <NetworkManagerQt/WirelessSetting>
#include <PulseAudioQt/Server>
#include <Solid/DeviceNotifier>

#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QSharedPointer>
#include <QUuid>
#include <QtGlobal>

#include <algorithm>
#include <memory>

namespace
{
NetworkManager::WirelessDevice::Ptr firstWirelessDevice()
{
    const auto devices = NetworkManager::networkInterfaces();
    for (const auto &device : devices) {
        if (device && device->type() == NetworkManager::Device::Wifi) {
            return qSharedPointerDynamicCast<NetworkManager::WirelessDevice>(device);
        }
    }
    return {};
}

bool isSecuredAccessPoint(const NetworkManager::AccessPoint::Ptr &accessPoint)
{
    return accessPoint
        && (accessPoint->capabilities().testFlag(NetworkManager::AccessPoint::Privacy)
            || accessPoint->wpaFlags() != NetworkManager::AccessPoint::WpaFlags()
            || accessPoint->rsnFlags() != NetworkManager::AccessPoint::WpaFlags());
}
}

SystemStateHub::SystemStateHub(QObject *parent)
    : QObject(parent)
    , m_bluetoothManager(this)
    , m_audioContext(PulseAudioQt::Context::instance())
{
    auto *networkNotifier = NetworkManager::notifier();
    const auto refreshNetwork = [this] {
        refreshWifiDevice();
        refreshWifiState();
    };
    connect(networkNotifier, &NetworkManager::Notifier::statusChanged, this,
            [refreshNetwork](NetworkManager::Status) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::wirelessEnabledChanged, this,
            [refreshNetwork](bool) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::wirelessHardwareEnabledChanged, this,
            [refreshNetwork](bool) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::primaryConnectionChanged, this,
            [refreshNetwork](const QString &) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::connectivityChanged, this,
            [refreshNetwork](NetworkManager::Connectivity) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::deviceAdded, this,
            [refreshNetwork](const QString &) { refreshNetwork(); });
    connect(networkNotifier, &NetworkManager::Notifier::deviceRemoved, this,
            [refreshNetwork](const QString &) { refreshNetwork(); });
    refreshWifiDevice();
    refreshWifiState();

    connect(&m_bluetoothManager, &BluezQt::Manager::operationalChanged, this, [this] {
        refreshBluetoothConnections();
        refreshBluetoothState();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::usableAdapterChanged, this, [this] {
        refreshBluetoothConnections();
        refreshBluetoothState();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::adapterAdded, this, [this] {
        refreshBluetoothConnections();
        refreshBluetoothState();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::adapterRemoved, this, [this] {
        refreshBluetoothConnections();
        refreshBluetoothState();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::deviceAdded, this,
            [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); });
    connect(&m_bluetoothManager, &BluezQt::Manager::deviceChanged, this,
            [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); });
    connect(&m_bluetoothManager, &BluezQt::Manager::deviceRemoved, this,
            [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); });
    auto *bluezInit = m_bluetoothManager.init();
    connect(bluezInit, &BluezQt::InitManagerJob::result, this, [this] {
        refreshBluetoothConnections();
        refreshBluetoothState();
    });

    auto *deviceNotifier = Solid::DeviceNotifier::instance();
    connect(deviceNotifier, &Solid::DeviceNotifier::deviceAdded, this, [this] { refreshBattery(); });
    connect(deviceNotifier, &Solid::DeviceNotifier::deviceRemoved, this, [this] { refreshBattery(); });
    refreshBattery();

    connect(m_audioContext, &PulseAudioQt::Context::stateChanged, this, [this] {
        bindAudioSink();
        bindAudioSource();
        Q_EMIT audioChanged();
    });
    connect(m_audioContext->server(), &PulseAudioQt::Server::defaultSinkChanged, this, [this] {
        bindAudioSink();
        Q_EMIT audioChanged();
    });
    connect(m_audioContext->server(), &PulseAudioQt::Server::defaultSourceChanged, this, [this] {
        bindAudioSource();
        Q_EMIT audioChanged();
    });
    const auto refreshAudioDevices = [this] { Q_EMIT audioChanged(); };
    connect(m_audioContext, &PulseAudioQt::Context::sinkAdded, this, refreshAudioDevices);
    connect(m_audioContext, &PulseAudioQt::Context::sinkRemoved, this, refreshAudioDevices);
    connect(m_audioContext, &PulseAudioQt::Context::sourceAdded, this, refreshAudioDevices);
    connect(m_audioContext, &PulseAudioQt::Context::sourceRemoved, this, refreshAudioDevices);
    bindAudioSink();
    bindAudioSource();
}

bool SystemStateHub::networkAvailable() const
{
    return m_wifiDevice || !NetworkManager::networkInterfaces().isEmpty();
}

bool SystemStateHub::networkConnected() const
{
    return NetworkManager::status() >= NetworkManager::ConnectedLinkLocal;
}

bool SystemStateHub::wirelessEnabled() const
{
    return NetworkManager::isWirelessEnabled();
}

QString SystemStateHub::networkName() const
{
    if (m_wifiDevice) {
        const auto accessPoint = m_wifiDevice->activeAccessPoint();
        if (accessPoint && !accessPoint->ssid().isEmpty()) {
            return accessPoint->ssid();
        }
    }
    const auto connection = NetworkManager::primaryConnection();
    return connection ? connection->id() : QString();
}

QString SystemStateHub::networkStatus() const
{
    switch (NetworkManager::status()) {
    case NetworkManager::Connecting: return tr("Connecting");
    case NetworkManager::ConnectedLinkLocal: return tr("Link local");
    case NetworkManager::ConnectedSiteOnly: return tr("Limited");
    case NetworkManager::Connected: return tr("Connected");
    case NetworkManager::Disconnecting: return tr("Disconnecting");
    case NetworkManager::Disconnected: return tr("Disconnected");
    case NetworkManager::Asleep: return tr("Networking disabled");
    default: return tr("Unavailable");
    }
}

QVariantList SystemStateHub::wifiNetworks() const
{
    QVariantList result;
    if (!m_wifiDevice || !wirelessEnabled()) {
        return result;
    }

    const QString activeSsid = networkName();
    const auto activating = NetworkManager::activatingConnection();
    const QString activatingId = activating ? activating->id() : QString();
    const auto networks = m_wifiDevice->networks();
    result.reserve(networks.size());

    for (const auto &network : networks) {
        if (!network || network->ssid().isEmpty()) {
            continue;
        }
        const auto accessPoint = network->referenceAccessPoint();
        if (!accessPoint) {
            continue;
        }

        const auto security = NetworkManager::findBestWirelessSecurity(
            m_wifiDevice->wirelessCapabilities(), true, false,
            accessPoint->capabilities(), accessPoint->wpaFlags(), accessPoint->rsnFlags());
        const auto savedConnection = savedConnectionForSsid(network->ssid());

        QVariantMap item;
        item.insert(QStringLiteral("ssid"), network->ssid());
        item.insert(QStringLiteral("strength"), network->signalStrength());
        item.insert(QStringLiteral("secured"), isSecuredAccessPoint(accessPoint));
        item.insert(QStringLiteral("securityLabel"), securityLabel(security));
        item.insert(QStringLiteral("saved"), !savedConnection.isNull());
        item.insert(QStringLiteral("connected"), network->ssid() == activeSsid && networkConnected());
        item.insert(QStringLiteral("connecting"), network->ssid() == activatingId);
        result.push_back(item);
    }

    std::sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        const auto a = left.toMap();
        const auto b = right.toMap();
        if (a.value(QStringLiteral("connected")).toBool() != b.value(QStringLiteral("connected")).toBool()) {
            return a.value(QStringLiteral("connected")).toBool();
        }
        if (a.value(QStringLiteral("saved")).toBool() != b.value(QStringLiteral("saved")).toBool()) {
            return a.value(QStringLiteral("saved")).toBool();
        }
        return a.value(QStringLiteral("strength")).toInt() > b.value(QStringLiteral("strength")).toInt();
    });
    return result;
}

bool SystemStateHub::wifiScanning() const
{
    return m_wifiScanning;
}

bool SystemStateHub::networkBusy() const
{
    return m_networkBusy;
}

void SystemStateHub::setWirelessEnabled(bool enabled)
{
    clearOperationError();
    if (!NetworkManager::isWirelessHardwareEnabled()) {
        if (enabled) {
            setOperationError(tr("Wi-Fi is disabled by a hardware or rfkill switch."));
        }
        return;
    }
    if (enabled != wirelessEnabled()) {
        NetworkManager::setWirelessEnabled(enabled);
    }
}

void SystemStateHub::requestWifiScan()
{
    clearOperationError();
    if (!m_wifiDevice || !wirelessEnabled()) {
        setOperationError(tr("Wi-Fi is not available."));
        return;
    }
    if (m_wifiScanning) {
        return;
    }

    m_wifiScanning = true;
    Q_EMIT wifiScanningChanged();
    const auto reply = m_wifiDevice->requestScan();
    auto *watcher = new QDBusPendingCallWatcher(reply, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher](QDBusPendingCallWatcher *) {
                const QDBusPendingReply<> result = *watcher;
                if (result.isError()) {
                    setOperationError(result.error().message());
                }
                m_wifiScanning = false;
                Q_EMIT wifiScanningChanged();
                refreshWifiState();
                watcher->deleteLater();
            });
}

void SystemStateHub::connectWifi(const QString &ssid, const QString &password)
{
    clearOperationError();
    if (!m_wifiDevice || ssid.isEmpty()) {
        setOperationError(tr("Wi-Fi network is not available."));
        return;
    }

    const auto network = m_wifiDevice->findNetwork(ssid);
    if (!network || !network->referenceAccessPoint()) {
        setOperationError(tr("The selected Wi-Fi network is no longer visible."));
        return;
    }
    const auto accessPoint = network->referenceAccessPoint();

    if (const auto saved = savedConnectionForSsid(ssid)) {
        setNetworkBusy(true);
        const auto reply = NetworkManager::activateConnection(saved->path(), m_wifiDevice->uni(), accessPoint->uni());
        auto *watcher = new QDBusPendingCallWatcher(reply, this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this,
                [this, watcher](QDBusPendingCallWatcher *) {
                    const QDBusPendingReply<QDBusObjectPath> result = *watcher;
                    if (result.isError()) {
                        setOperationError(result.error().message());
                    }
                    setNetworkBusy(false);
                    refreshWifiState();
                    watcher->deleteLater();
                });
        return;
    }

    const auto security = NetworkManager::findBestWirelessSecurity(
        m_wifiDevice->wirelessCapabilities(), true, false,
        accessPoint->capabilities(), accessPoint->wpaFlags(), accessPoint->rsnFlags());
    NMVariantMapMap settings;
    settings.insert(QStringLiteral("connection"), QVariantMap{
        {QStringLiteral("id"), ssid},
        {QStringLiteral("uuid"), QUuid::createUuid().toString(QUuid::WithoutBraces)},
        {QStringLiteral("type"), QStringLiteral("802-11-wireless")},
        {QStringLiteral("autoconnect"), true},
    });
    QVariantMap wireless{
        {QStringLiteral("ssid"), ssid.toUtf8()},
        {QStringLiteral("mode"), QStringLiteral("infrastructure")},
    };
    QVariantMap securitySettings;
    switch (security) {
    case NetworkManager::NoneSecurity:
        break;
    case NetworkManager::WpaPsk:
    case NetworkManager::Wpa2Psk:
        if (password.isEmpty()) {
            setOperationError(tr("This Wi-Fi network requires a password."));
            return;
        }
        wireless.insert(QStringLiteral("security"), QStringLiteral("802-11-wireless-security"));
        securitySettings.insert(QStringLiteral("key-mgmt"), QStringLiteral("wpa-psk"));
        securitySettings.insert(QStringLiteral("psk"), password);
        break;
    case NetworkManager::SAE:
        if (password.isEmpty()) {
            setOperationError(tr("This Wi-Fi network requires a password."));
            return;
        }
        wireless.insert(QStringLiteral("security"), QStringLiteral("802-11-wireless-security"));
        securitySettings.insert(QStringLiteral("key-mgmt"), QStringLiteral("sae"));
        securitySettings.insert(QStringLiteral("psk"), password);
        break;
    case NetworkManager::OWE:
        wireless.insert(QStringLiteral("security"), QStringLiteral("802-11-wireless-security"));
        securitySettings.insert(QStringLiteral("key-mgmt"), QStringLiteral("owe"));
        break;
    default:
        setOperationError(tr("This Wi-Fi security type needs the advanced NetworkManager settings UI."));
        return;
    }
    settings.insert(QStringLiteral("802-11-wireless"), wireless);
    if (!securitySettings.isEmpty()) {
        settings.insert(QStringLiteral("802-11-wireless-security"), securitySettings);
    }
    settings.insert(QStringLiteral("ipv4"), QVariantMap{{QStringLiteral("method"), QStringLiteral("auto")}});
    settings.insert(QStringLiteral("ipv6"), QVariantMap{{QStringLiteral("method"), QStringLiteral("auto")}});

    setNetworkBusy(true);
    const auto reply = NetworkManager::addAndActivateConnection2(
        settings, m_wifiDevice->uni(), accessPoint->uni(),
        QVariantMap{{QStringLiteral("persist"), QStringLiteral("disk")}});
    auto *watcher = new QDBusPendingCallWatcher(reply, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher](QDBusPendingCallWatcher *) {
                const QDBusPendingReply<QDBusObjectPath, QDBusObjectPath, QVariantMap> result = *watcher;
                if (result.isError()) {
                    setOperationError(result.error().message());
                }
                setNetworkBusy(false);
                refreshWifiState();
                watcher->deleteLater();
            });
}

void SystemStateHub::disconnectWifi()
{
    clearOperationError();
    if (!m_wifiDevice || !m_wifiDevice->activeConnection()) {
        return;
    }
    setNetworkBusy(true);
    const auto reply = NetworkManager::deactivateConnection(m_wifiDevice->activeConnection()->path());
    auto *watcher = new QDBusPendingCallWatcher(reply, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher](QDBusPendingCallWatcher *) {
                const QDBusPendingReply<> result = *watcher;
                if (result.isError()) {
                    setOperationError(result.error().message());
                }
                setNetworkBusy(false);
                refreshWifiState();
                watcher->deleteLater();
            });
}

bool SystemStateHub::bluetoothAvailable() const
{
    return m_bluetoothManager.isOperational() && !m_bluetoothManager.adapters().isEmpty();
}

bool SystemStateHub::bluetoothEnabled() const
{
    return m_bluetoothManager.usableAdapter() != nullptr;
}

QVariantList SystemStateHub::bluetoothDevices() const
{
    QVariantList result;
    const auto devices = m_bluetoothManager.devices();
    result.reserve(devices.size());
    for (const auto &device : devices) {
        if (!device) {
            continue;
        }
        QVariantMap item;
        item.insert(QStringLiteral("name"), device->friendlyName().isEmpty() ? device->address() : device->friendlyName());
        item.insert(QStringLiteral("address"), device->address());
        item.insert(QStringLiteral("icon"), bluetoothMaterialIcon(device));
        item.insert(QStringLiteral("paired"), device->isPaired());
        item.insert(QStringLiteral("trusted"), device->isTrusted());
        item.insert(QStringLiteral("connected"), device->isConnected());
        const auto battery = device->battery();
        item.insert(QStringLiteral("batteryAvailable"), !battery.isNull());
        item.insert(QStringLiteral("batteryPercent"), battery ? battery->percentage() : -1);
        result.push_back(item);
    }
    std::sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        const auto a = left.toMap();
        const auto b = right.toMap();
        if (a.value(QStringLiteral("connected")).toBool() != b.value(QStringLiteral("connected")).toBool()) {
            return a.value(QStringLiteral("connected")).toBool();
        }
        if (a.value(QStringLiteral("paired")).toBool() != b.value(QStringLiteral("paired")).toBool()) {
            return a.value(QStringLiteral("paired")).toBool();
        }
        return a.value(QStringLiteral("name")).toString().localeAwareCompare(
                   b.value(QStringLiteral("name")).toString()) < 0;
    });
    return result;
}

bool SystemStateHub::bluetoothDiscovering() const
{
    const auto adapter = m_bluetoothManager.usableAdapter();
    return adapter && adapter->isDiscovering();
}

bool SystemStateHub::bluetoothBusy() const
{
    return m_bluetoothBusy;
}

void SystemStateHub::setBluetoothEnabled(bool enabled)
{
    clearOperationError();
    const auto adapters = m_bluetoothManager.adapters();
    if (adapters.isEmpty()) {
        if (enabled) {
            setOperationError(tr("No Bluetooth adapter is available."));
        }
        return;
    }

    auto pending = std::make_shared<int>(0);
    for (const auto &adapter : adapters) {
        if (adapter && adapter->isPowered() != enabled) {
            ++(*pending);
        }
    }
    if (*pending == 0) {
        refreshBluetoothState();
        return;
    }
    setBluetoothBusy(true);
    for (const auto &adapter : m_bluetoothManager.adapters()) {
        if (adapter && adapter->isPowered() != enabled) {
            auto *call = adapter->setPowered(enabled);
            connect(call, &BluezQt::PendingCall::finished, this,
                    [this, pending](BluezQt::PendingCall *finishedCall) {
                        if (finishedCall->error() != BluezQt::PendingCall::NoError) {
                            setOperationError(finishedCall->errorText());
                        }
                        if (--(*pending) == 0) {
                            setBluetoothBusy(false);
                            refreshBluetoothState();
                        }
                    });
        }
    }
}

void SystemStateHub::startBluetoothDiscovery()
{
    clearOperationError();
    const auto adapter = m_bluetoothManager.usableAdapter();
    if (!adapter) {
        setOperationError(tr("Turn Bluetooth on before scanning."));
        return;
    }
    if (adapter->isDiscovering()) {
        return;
    }
    setBluetoothBusy(true);
    auto *call = adapter->startDiscovery();
    connect(call, &BluezQt::PendingCall::finished, this, [this](BluezQt::PendingCall *finishedCall) {
        if (finishedCall->error() != BluezQt::PendingCall::NoError) {
            setOperationError(finishedCall->errorText());
        }
        setBluetoothBusy(false);
        refreshBluetoothState();
    });
}

void SystemStateHub::stopBluetoothDiscovery()
{
    const auto adapter = m_bluetoothManager.usableAdapter();
    if (!adapter || !adapter->isDiscovering()) {
        return;
    }
    setBluetoothBusy(true);
    auto *call = adapter->stopDiscovery();
    connect(call, &BluezQt::PendingCall::finished, this, [this](BluezQt::PendingCall *finishedCall) {
        if (finishedCall->error() != BluezQt::PendingCall::NoError) {
            setOperationError(finishedCall->errorText());
        }
        setBluetoothBusy(false);
        refreshBluetoothState();
    });
}

void SystemStateHub::toggleBluetoothDevice(const QString &address)
{
    clearOperationError();
    const auto device = m_bluetoothManager.deviceForAddress(address);
    if (!device) {
        setOperationError(tr("Bluetooth device is no longer available."));
        return;
    }
    setBluetoothBusy(true);
    if (device->isConnected()) {
        auto *call = device->disconnectFromDevice();
        connect(call, &BluezQt::PendingCall::finished, this, [this](BluezQt::PendingCall *finishedCall) {
            if (finishedCall->error() != BluezQt::PendingCall::NoError
                && finishedCall->error() != BluezQt::PendingCall::NotConnected) {
                setOperationError(finishedCall->errorText());
            }
            setBluetoothBusy(false);
            refreshBluetoothState();
        });
        return;
    }

    const auto connectDevice = [this, device] {
        auto *connectCall = device->connectToDevice();
        connect(connectCall, &BluezQt::PendingCall::finished, this,
                [this](BluezQt::PendingCall *finishedCall) {
                    if (finishedCall->error() != BluezQt::PendingCall::NoError
                        && finishedCall->error() != BluezQt::PendingCall::AlreadyConnected) {
                        setOperationError(finishedCall->errorText());
                    }
                    setBluetoothBusy(false);
                    refreshBluetoothState();
                });
    };
    if (device->isPaired()) {
        connectDevice();
        return;
    }

    auto *pairCall = device->pair();
    connect(pairCall, &BluezQt::PendingCall::finished, this,
            [this, device, connectDevice](BluezQt::PendingCall *finishedCall) {
                if (finishedCall->error() != BluezQt::PendingCall::NoError
                    && finishedCall->error() != BluezQt::PendingCall::AlreadyExists) {
                    setOperationError(finishedCall->errorText());
                    setBluetoothBusy(false);
                    refreshBluetoothState();
                    return;
                }
                if (!device->isTrusted()) {
                    auto *trustCall = device->setTrusted(true);
                    connect(trustCall, &BluezQt::PendingCall::finished, this,
                            [this, connectDevice](BluezQt::PendingCall *trustFinished) {
                                if (trustFinished->error() != BluezQt::PendingCall::NoError) {
                                    setOperationError(trustFinished->errorText());
                                    setBluetoothBusy(false);
                                    refreshBluetoothState();
                                    return;
                                }
                                connectDevice();
                            });
                    return;
                }
                connectDevice();
            });
}

void SystemStateHub::forgetBluetoothDevice(const QString &address)
{
    clearOperationError();
    const auto device = m_bluetoothManager.deviceForAddress(address);
    if (!device) {
        return;
    }
    const auto adapter = device->adapter();
    if (!adapter) {
        setOperationError(tr("Bluetooth adapter is unavailable."));
        return;
    }
    setBluetoothBusy(true);
    auto *call = adapter->removeDevice(device);
    connect(call, &BluezQt::PendingCall::finished, this, [this](BluezQt::PendingCall *finishedCall) {
        if (finishedCall->error() != BluezQt::PendingCall::NoError) {
            setOperationError(finishedCall->errorText());
        }
        setBluetoothBusy(false);
        refreshBluetoothState();
    });
}

bool SystemStateHub::batteryAvailable() const
{
    return m_battery && m_battery->isPresent();
}

int SystemStateHub::batteryPercent() const
{
    return m_battery ? m_battery->chargePercent() : 0;
}

bool SystemStateHub::batteryCharging() const
{
    return m_battery && (m_battery->chargeState() == Solid::Battery::Charging
                         || m_battery->chargeState() == Solid::Battery::FullyCharged);
}

bool SystemStateHub::audioAvailable() const
{
    return m_sink != nullptr;
}

int SystemStateHub::volumePercent() const
{
    return m_sink ? qRound(100.0 * m_sink->volume() / PulseAudioQt::normalVolume()) : 0;
}

bool SystemStateHub::audioMuted() const
{
    return m_sink ? m_sink->isMuted() : false;
}

QString SystemStateHub::audioDevice() const
{
    return m_sink ? m_sink->description() : QString();
}

QVariantList SystemStateHub::audioOutputDevices() const
{
    QVariantList result;
    if (!m_audioContext) {
        return result;
    }
    const auto devices = m_audioContext->sinks();
    result.reserve(devices.size());
    for (const auto *device : devices) {
        if (!device) {
            continue;
        }
        result.push_back(QVariantMap{
            {QStringLiteral("id"), device->name()},
            {QStringLiteral("name"), device->description()},
            {QStringLiteral("formFactor"), device->formFactor()},
            {QStringLiteral("active"), device == m_sink},
        });
    }
    return result;
}

bool SystemStateHub::microphoneAvailable() const
{
    return m_source != nullptr;
}

int SystemStateHub::microphoneVolumePercent() const
{
    return m_source ? qRound(100.0 * m_source->volume() / PulseAudioQt::normalVolume()) : 0;
}

bool SystemStateHub::microphoneMuted() const
{
    return m_source ? m_source->isMuted() : false;
}

QString SystemStateHub::microphoneDevice() const
{
    return m_source ? m_source->description() : QString();
}

QVariantList SystemStateHub::audioInputDevices() const
{
    QVariantList result;
    if (!m_audioContext) {
        return result;
    }
    const auto devices = m_audioContext->sources();
    result.reserve(devices.size());
    for (const auto *device : devices) {
        // PipeWire/PulseAudio exposes one monitor source per output. These
        // record the speaker mix and must not appear as microphone choices.
        if (!device || device->name().endsWith(QStringLiteral(".monitor"))) {
            continue;
        }
        result.push_back(QVariantMap{
            {QStringLiteral("id"), device->name()},
            {QStringLiteral("name"), device->description()},
            {QStringLiteral("formFactor"), device->formFactor()},
            {QStringLiteral("active"), device == m_source},
        });
    }
    return result;
}

void SystemStateHub::setVolumePercent(int percent)
{
    if (m_sink) {
        m_sink->setVolume(qRound64(PulseAudioQt::normalVolume() * qBound(0, percent, 150) / 100.0));
    }
}

void SystemStateHub::setAudioMuted(bool muted)
{
    if (m_sink && muted != m_sink->isMuted()) {
        m_sink->setMuted(muted);
    }
}

void SystemStateHub::setMicrophoneVolumePercent(int percent)
{
    if (m_source) {
        m_source->setVolume(qRound64(PulseAudioQt::normalVolume() * qBound(0, percent, 150) / 100.0));
    }
}

void SystemStateHub::setMicrophoneMuted(bool muted)
{
    if (m_source && muted != m_source->isMuted()) {
        m_source->setMuted(muted);
    }
}

void SystemStateHub::setDefaultAudioOutput(const QString &deviceId)
{
    if (!m_audioContext || deviceId.isEmpty()) {
        setOperationError(tr("Audio output is unavailable."));
        return;
    }
    for (auto *device : m_audioContext->sinks()) {
        if (device && device->name() == deviceId) {
            // Use PulseAudioQt's KDE-backed context rather than a shell
            // command.  switchStreams keeps currently playing apps on the
            // newly selected output, matching Plasma's device chooser.
            m_audioContext->server()->setDefaultSink(device);
            device->switchStreams();
            return;
        }
    }
    setOperationError(tr("The selected audio output is no longer available."));
}

void SystemStateHub::setDefaultAudioInput(const QString &deviceId)
{
    if (!m_audioContext || deviceId.isEmpty()) {
        setOperationError(tr("Microphone input is unavailable."));
        return;
    }
    for (auto *device : m_audioContext->sources()) {
        if (device && !device->name().endsWith(QStringLiteral(".monitor"))
            && device->name() == deviceId) {
            m_audioContext->server()->setDefaultSource(device);
            device->switchStreams();
            return;
        }
    }
    setOperationError(tr("The selected microphone is no longer available."));
}

bool SystemStateHub::operationBusy() const
{
    return m_networkBusy || m_bluetoothBusy;
}

QString SystemStateHub::operationError() const
{
    return m_operationError;
}

void SystemStateHub::clearOperationError()
{
    if (!m_operationError.isEmpty()) {
        m_operationError.clear();
        Q_EMIT operationChanged();
    }
}

void SystemStateHub::refreshWifiDevice()
{
    const auto next = firstWirelessDevice();
    if (next == m_wifiDevice) {
        return;
    }
    if (m_wifiDevice) {
        disconnect(m_wifiDevice.data(), nullptr, this, nullptr);
    }
    m_wifiDevice = next;
    bindWifiDevice();
    Q_EMIT networkChanged();
    Q_EMIT wifiNetworksChanged();
}

void SystemStateHub::bindWifiDevice()
{
    if (!m_wifiDevice) {
        return;
    }
    connect(m_wifiDevice.data(), &NetworkManager::WirelessDevice::networkAppeared,
            this, [this](const QString &) { refreshWifiState(); });
    connect(m_wifiDevice.data(), &NetworkManager::WirelessDevice::networkDisappeared,
            this, [this](const QString &) { refreshWifiState(); });
    connect(m_wifiDevice.data(), &NetworkManager::WirelessDevice::activeAccessPointChanged,
            this, [this](const QString &) { refreshWifiState(); });
    connect(m_wifiDevice.data(), &NetworkManager::WirelessDevice::lastScanChanged,
            this, [this](const QDateTime &) {
                if (m_wifiScanning) {
                    m_wifiScanning = false;
                    Q_EMIT wifiScanningChanged();
                }
                refreshWifiState();
            });
    connect(m_wifiDevice.data(), &NetworkManager::Device::connectionStateChanged,
            this, [this] { refreshWifiState(); });
}

void SystemStateHub::refreshWifiState()
{
    Q_EMIT networkChanged();
    Q_EMIT wifiNetworksChanged();
}

void SystemStateHub::refreshBluetoothConnections()
{
    for (const auto &adapter : m_bluetoothManager.adapters()) {
        if (adapter) {
            connect(adapter.data(), &BluezQt::Adapter::poweredChanged, this,
                    [this](bool) { refreshBluetoothState(); }, Qt::UniqueConnection);
            connect(adapter.data(), &BluezQt::Adapter::discoveringChanged, this,
                    [this](bool) { refreshBluetoothState(); }, Qt::UniqueConnection);
            connect(adapter.data(), &BluezQt::Adapter::deviceAdded, this,
                    [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); }, Qt::UniqueConnection);
            connect(adapter.data(), &BluezQt::Adapter::deviceChanged, this,
                    [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); }, Qt::UniqueConnection);
            connect(adapter.data(), &BluezQt::Adapter::deviceRemoved, this,
                    [this](const BluezQt::DevicePtr &) { refreshBluetoothState(); }, Qt::UniqueConnection);
        }
    }
}

void SystemStateHub::refreshBluetoothState()
{
    Q_EMIT bluetoothChanged();
    Q_EMIT bluetoothDevicesChanged();
}

void SystemStateHub::refreshBattery()
{
    if (m_battery) {
        disconnect(m_battery, nullptr, this, nullptr);
    }
    m_battery = nullptr;
    const auto devices = Solid::Device::listFromType(Solid::DeviceInterface::Battery);
    for (const auto &device : devices) {
        auto candidate = device;
        auto *battery = candidate.as<Solid::Battery>();
        if (battery && battery->type() == Solid::Battery::PrimaryBattery) {
            m_batteryDevice = candidate;
            m_battery = m_batteryDevice.as<Solid::Battery>();
            break;
        }
    }
    if (m_battery) {
        connect(m_battery, &Solid::Battery::chargePercentChanged, this, &SystemStateHub::batteryChanged);
        connect(m_battery, &Solid::Battery::chargeStateChanged, this, &SystemStateHub::batteryChanged);
        connect(m_battery, &Solid::Battery::presentStateChanged, this, &SystemStateHub::batteryChanged);
    }
    Q_EMIT batteryChanged();
}

void SystemStateHub::bindAudioSink()
{
    if (m_sink) {
        disconnect(m_sink, nullptr, this, nullptr);
    }
    m_sink = m_audioContext->server()->defaultSink();
    if (m_sink) {
        connect(m_sink, &PulseAudioQt::Sink::volumeChanged, this, &SystemStateHub::audioChanged);
        connect(m_sink, &PulseAudioQt::Sink::mutedChanged, this, &SystemStateHub::audioChanged);
        connect(m_sink, &PulseAudioQt::Sink::descriptionChanged, this, &SystemStateHub::audioChanged);
    }
}

void SystemStateHub::bindAudioSource()
{
    if (m_source) {
        disconnect(m_source, nullptr, this, nullptr);
    }
    m_source = m_audioContext->server()->defaultSource();
    if (m_source) {
        connect(m_source, &PulseAudioQt::Source::volumeChanged, this, &SystemStateHub::audioChanged);
        connect(m_source, &PulseAudioQt::Source::mutedChanged, this, &SystemStateHub::audioChanged);
        connect(m_source, &PulseAudioQt::Source::descriptionChanged, this, &SystemStateHub::audioChanged);
    }
}

void SystemStateHub::setNetworkBusy(bool busy)
{
    if (m_networkBusy == busy) {
        return;
    }
    m_networkBusy = busy;
    Q_EMIT networkOperationChanged();
    Q_EMIT operationChanged();
}

void SystemStateHub::setBluetoothBusy(bool busy)
{
    if (m_bluetoothBusy == busy) {
        return;
    }
    m_bluetoothBusy = busy;
    Q_EMIT bluetoothOperationChanged();
    Q_EMIT operationChanged();
}

void SystemStateHub::setOperationError(const QString &error)
{
    if (m_operationError == error) {
        return;
    }
    m_operationError = error;
    Q_EMIT operationChanged();
}

NetworkManager::Connection::Ptr SystemStateHub::savedConnectionForSsid(const QString &ssid) const
{
    const auto connections = NetworkManager::listConnections();
    for (const auto &connection : connections) {
        if (!connection) {
            continue;
        }
        const auto settings = connection->settings();
        if (!settings || settings->connectionType() != NetworkManager::ConnectionSettings::Wireless) {
            continue;
        }
        const auto genericWireless = settings->setting(NetworkManager::Setting::Wireless);
        const auto wireless = qSharedPointerDynamicCast<NetworkManager::WirelessSetting>(genericWireless);
        if (wireless && QString::fromUtf8(wireless->ssid()) == ssid) {
            return connection;
        }
    }
    return {};
}

QString SystemStateHub::securityLabel(NetworkManager::WirelessSecurityType security) const
{
    switch (security) {
    case NetworkManager::NoneSecurity: return tr("Open");
    case NetworkManager::WpaPsk: return tr("WPA");
    case NetworkManager::Wpa2Psk: return tr("WPA2");
    case NetworkManager::SAE: return tr("WPA3");
    case NetworkManager::OWE: return tr("Enhanced Open");
    case NetworkManager::WpaEap:
    case NetworkManager::Wpa2Eap:
    case NetworkManager::Wpa3SuiteB192: return tr("Enterprise");
    case NetworkManager::StaticWep:
    case NetworkManager::DynamicWep: return tr("WEP");
    default: return tr("Secured");
    }
}

QString SystemStateHub::bluetoothMaterialIcon(const BluezQt::DevicePtr &device) const
{
    if (!device) {
        return QStringLiteral("bluetooth");
    }
    switch (device->type()) {
    case BluezQt::Device::Headset:
    case BluezQt::Device::Headphones: return QStringLiteral("headphones");
    case BluezQt::Device::AudioVideo: return QStringLiteral("speaker");
    case BluezQt::Device::Keyboard: return QStringLiteral("keyboard");
    case BluezQt::Device::Mouse: return QStringLiteral("mouse");
    case BluezQt::Device::Joypad: return QStringLiteral("sports_esports");
    case BluezQt::Device::Phone: return QStringLiteral("smartphone");
    case BluezQt::Device::Computer: return QStringLiteral("computer");
    default: return QStringLiteral("bluetooth");
    }
}
