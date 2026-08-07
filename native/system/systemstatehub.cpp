#include "systemstatehub.h"

#include <BluezQt/Adapter>
#include <BluezQt/InitManagerJob>
#include <BluezQt/Job>
#include <NetworkManagerQt/ActiveConnection>
#include <PulseAudioQt/Server>
#include <Solid/DeviceNotifier>

#include <QtGlobal>

SystemStateHub::SystemStateHub(QObject *parent)
    : QObject(parent)
    , m_bluetoothManager(this)
    , m_audioContext(PulseAudioQt::Context::instance())
{
    auto *networkNotifier = NetworkManager::notifier();
    connect(networkNotifier, &NetworkManager::Notifier::statusChanged, this, &SystemStateHub::networkChanged);
    connect(networkNotifier, &NetworkManager::Notifier::wirelessEnabledChanged, this, &SystemStateHub::networkChanged);
    connect(networkNotifier, &NetworkManager::Notifier::wirelessHardwareEnabledChanged, this, &SystemStateHub::networkChanged);
    connect(networkNotifier, &NetworkManager::Notifier::primaryConnectionChanged, this, &SystemStateHub::networkChanged);
    connect(networkNotifier, &NetworkManager::Notifier::connectivityChanged, this, &SystemStateHub::networkChanged);

    connect(&m_bluetoothManager, &BluezQt::Manager::operationalChanged, this, [this] {
        refreshBluetoothConnections();
        Q_EMIT bluetoothChanged();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::usableAdapterChanged, this, [this] {
        refreshBluetoothConnections();
        Q_EMIT bluetoothChanged();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::adapterAdded, this, [this] {
        refreshBluetoothConnections();
        Q_EMIT bluetoothChanged();
    });
    connect(&m_bluetoothManager, &BluezQt::Manager::adapterRemoved, this, [this] {
        refreshBluetoothConnections();
        Q_EMIT bluetoothChanged();
    });
    auto *bluezInit = m_bluetoothManager.init();
    connect(bluezInit, &BluezQt::InitManagerJob::result, this, [this] {
        refreshBluetoothConnections();
        Q_EMIT bluetoothChanged();
    });

    auto *deviceNotifier = Solid::DeviceNotifier::instance();
    connect(deviceNotifier, &Solid::DeviceNotifier::deviceAdded, this, [this] { refreshBattery(); });
    connect(deviceNotifier, &Solid::DeviceNotifier::deviceRemoved, this, [this] { refreshBattery(); });
    refreshBattery();

    connect(m_audioContext, &PulseAudioQt::Context::stateChanged, this, [this] {
        bindAudioSink();
        Q_EMIT audioChanged();
    });
    connect(m_audioContext->server(), &PulseAudioQt::Server::defaultSinkChanged, this, [this] {
        bindAudioSink();
        Q_EMIT audioChanged();
    });
    bindAudioSink();
}

bool SystemStateHub::networkAvailable() const
{
    return !NetworkManager::networkInterfaces().isEmpty();
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

void SystemStateHub::setWirelessEnabled(bool enabled)
{
    if (enabled != wirelessEnabled() && NetworkManager::isWirelessHardwareEnabled()) {
        NetworkManager::setWirelessEnabled(enabled);
    }
}

bool SystemStateHub::bluetoothAvailable() const
{
    return m_bluetoothManager.isOperational() && !m_bluetoothManager.adapters().isEmpty();
}

bool SystemStateHub::bluetoothEnabled() const
{
    return m_bluetoothManager.usableAdapter() != nullptr;
}

void SystemStateHub::setBluetoothEnabled(bool enabled)
{
    for (const auto &adapter : m_bluetoothManager.adapters()) {
        if (adapter && adapter->isPowered() != enabled) {
            adapter->setPowered(enabled);
        }
    }
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

void SystemStateHub::refreshBluetoothConnections()
{
    for (const auto &adapter : m_bluetoothManager.adapters()) {
        if (adapter) {
            connect(adapter.data(), &BluezQt::Adapter::poweredChanged, this, &SystemStateHub::bluetoothChanged, Qt::UniqueConnection);
        }
    }
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
