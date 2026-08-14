#include "wifimanager.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QPointer>
#include <QUuid>

#include <algorithm>
#include <memory>

namespace {

QString errorMessage(const GError *error, const QString &fallback)
{
    if (!error)
        return fallback;

    const auto message = [](const char *text) {
        return QCoreApplication::translate("WifiManager", text);
    };
    if (error->domain == NM_MANAGER_ERROR) {
        switch (static_cast<NMManagerError>(error->code)) {
        case NM_MANAGER_ERROR_PERMISSION_DENIED:
            return message("You do not have permission to change this Wi-Fi setting.");
        case NM_MANAGER_ERROR_UNKNOWN_CONNECTION:
            return message("The saved Wi-Fi profile no longer exists.");
        case NM_MANAGER_ERROR_UNKNOWN_DEVICE:
            return message("The Wi-Fi adapter is no longer available.");
        case NM_MANAGER_ERROR_CONNECTION_NOT_AVAILABLE:
            return message("This Wi-Fi network is not available right now.");
        case NM_MANAGER_ERROR_CONNECTION_NOT_ACTIVE:
            return message("This Wi-Fi network is not currently connected.");
        case NM_MANAGER_ERROR_CONNECTION_ALREADY_ACTIVE:
            return message("This Wi-Fi network is already connected.");
        case NM_MANAGER_ERROR_DEPENDENCY_FAILED:
            return message("A required network service is unavailable.");
        case NM_MANAGER_ERROR_MISSING_PLUGIN:
            return message("Required Wi-Fi support is not installed.");
        case NM_MANAGER_ERROR_INVALID_ARGUMENTS:
            return message("The Wi-Fi settings are invalid.");
        default:
            break;
        }
    }

    if (error->domain == NM_DEVICE_ERROR) {
        switch (static_cast<NMDeviceError>(error->code)) {
        case NM_DEVICE_ERROR_INVALID_CONNECTION:
        case NM_DEVICE_ERROR_INCOMPATIBLE_CONNECTION:
            return message("This saved Wi-Fi profile is not compatible with the adapter.");
        case NM_DEVICE_ERROR_NOT_ACTIVE:
            return message("This Wi-Fi network is not currently connected.");
        case NM_DEVICE_ERROR_NOT_ALLOWED:
            return message("The Wi-Fi adapter is not ready. Try again in a moment.");
        case NM_DEVICE_ERROR_SPECIFIC_OBJECT_NOT_FOUND:
            return message("The Wi-Fi network is no longer in range.");
        case NM_DEVICE_ERROR_MISSING_DEPENDENCIES:
            return message("A required Wi-Fi component is unavailable.");
        case NM_DEVICE_ERROR_INVALID_ARGUMENT:
            return message("The Wi-Fi settings are invalid.");
        default:
            break;
        }
    }

    if (error->domain == NM_CONNECTION_ERROR) {
        switch (static_cast<NMConnectionError>(error->code)) {
        case NM_CONNECTION_ERROR_PROPERTY_NOT_SECRET:
            return message("The saved Wi-Fi credentials are invalid.");
        case NM_CONNECTION_ERROR_SETTING_NOT_FOUND:
        case NM_CONNECTION_ERROR_PROPERTY_NOT_FOUND:
        case NM_CONNECTION_ERROR_MISSING_SETTING:
        case NM_CONNECTION_ERROR_INVALID_SETTING:
        case NM_CONNECTION_ERROR_MISSING_PROPERTY:
        case NM_CONNECTION_ERROR_INVALID_PROPERTY:
            return message("The saved Wi-Fi profile is incomplete or invalid.");
        default:
            break;
        }
    }

    if (error->domain == G_IO_ERROR) {
        switch (static_cast<GIOErrorEnum>(error->code)) {
        case G_IO_ERROR_CANCELLED:
            return message("The Wi-Fi operation was cancelled.");
        case G_IO_ERROR_TIMED_OUT:
            return message("The Wi-Fi operation timed out. Try again.");
        case G_IO_ERROR_PERMISSION_DENIED:
            return message("You do not have permission to change this Wi-Fi setting.");
        case G_IO_ERROR_BUSY:
            return message("The Wi-Fi adapter is busy. Try again in a moment.");
        case G_IO_ERROR_NETWORK_UNREACHABLE:
        case G_IO_ERROR_HOST_UNREACHABLE:
            return message("The Wi-Fi service could not be reached.");
        default:
            break;
        }
    }

    // Some NetworkManager D-Bus failures arrive through a generic GIO code.
    // Use the structured domain/code mappings above first, then recognize only
    // stable concepts. Never surface the daemon's raw message in the UI.
    const QString detail = error->message ? QString::fromUtf8(error->message).toLower() : QString();
    if (detail.contains(QStringLiteral("secrets were required"))
        || detail.contains(QStringLiteral("no secrets"))
        || detail.contains(QStringLiteral("wrong password"))
        || detail.contains(QStringLiteral("invalid password"))
        || detail.contains(QStringLiteral("authentication failed"))) {
        return message("Could not authenticate. Check the password and try again.");
    }
    if (detail.contains(QStringLiteral("not allowed while unavailable")))
        return message("The Wi-Fi adapter is still starting. Try again in a moment.");
    if (detail.contains(QStringLiteral("not authorized")) || detail.contains(QStringLiteral("permission denied")))
        return message("You do not have permission to change this Wi-Fi setting.");
    if (detail.contains(QStringLiteral("timed out")) || detail.contains(QStringLiteral("timeout")))
        return message("The Wi-Fi operation timed out. Try again.");

    return fallback;
}

QString activationFailureMessage(NMDeviceStateReason reason)
{
    const auto message = [](const char *text) {
        return QCoreApplication::translate("WifiManager", text);
    };

    switch (reason) {
    case NM_DEVICE_STATE_REASON_NO_SECRETS:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_DISCONNECT:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_CONFIG_FAILED:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_FAILED:
    case NM_DEVICE_STATE_REASON_SUPPLICANT_TIMEOUT:
        return message("Could not authenticate. Check the password and try again.");
    case NM_DEVICE_STATE_REASON_SSID_NOT_FOUND:
        return message("The Wi-Fi network is no longer in range.");
    case NM_DEVICE_STATE_REASON_IP_CONFIG_UNAVAILABLE:
    case NM_DEVICE_STATE_REASON_IP_CONFIG_EXPIRED:
    case NM_DEVICE_STATE_REASON_DHCP_START_FAILED:
    case NM_DEVICE_STATE_REASON_DHCP_ERROR:
    case NM_DEVICE_STATE_REASON_DHCP_FAILED:
        return message("Could not obtain a network address. Try again.");
    case NM_DEVICE_STATE_REASON_IP_ADDRESS_DUPLICATE:
        return message("Another device is already using this network address.");
    case NM_DEVICE_STATE_REASON_FIRMWARE_MISSING:
        return message("Required firmware for the Wi-Fi adapter is missing.");
    case NM_DEVICE_STATE_REASON_DEPENDENCY_FAILED:
        return message("A required network service is unavailable.");
    case NM_DEVICE_STATE_REASON_CONNECTION_REMOVED:
        return message("The saved Wi-Fi profile was removed.");
    case NM_DEVICE_STATE_REASON_SLEEPING:
    case NM_DEVICE_STATE_REASON_NETWORKING_OFF:
        return message("Wi-Fi was turned off before the connection completed.");
    case NM_DEVICE_STATE_REASON_USER_REQUESTED:
        return message("The connection attempt was cancelled.");
    case NM_DEVICE_STATE_REASON_CONFIG_FAILED:
        return message("Could not configure this Wi-Fi connection.");
    default:
        return message("Could not connect to the Wi-Fi network.");
    }
}

bool deviceIsConnecting(NMDeviceState state)
{
    return state >= NM_DEVICE_STATE_PREPARE && state < NM_DEVICE_STATE_ACTIVATED;
}

QByteArray bytesFromSsid(GBytes *ssid)
{
    if (!ssid)
        return {};

    gsize size = 0;
    const auto *data = static_cast<const char *>(g_bytes_get_data(ssid, &size));
    return QByteArray(data, static_cast<qsizetype>(size));
}

QString fromCString(const char *text)
{
    return text ? QString::fromUtf8(text) : QString();
}

} // namespace

struct WifiManager::AsyncContext
{
    QPointer<WifiManager> manager;
    QString networkId;
    QString ssid;
    quint64 operationGeneration = 0;
    bool requestedAutoconnect = false;
};

WifiManager::WifiManager(QObject *parent)
    : QObject(parent)
    , m_networks(this)
    , m_savedNetworks(this)
{
    m_refreshTimer.setInterval(1000);
    m_refreshTimer.setTimerType(Qt::CoarseTimer);
    connect(&m_refreshTimer, &QTimer::timeout, this, &WifiManager::refresh);

    m_operationTimeout.setSingleShot(true);
    m_operationTimeout.setInterval(60000);
    connect(&m_operationTimeout, &QTimer::timeout, this, [this] {
        failOperation(tr("The Wi-Fi operation timed out. Try again."));
    });

    initializeClient();
}

WifiManager::~WifiManager()
{
    m_refreshTimer.stop();
    m_operationTimeout.stop();

    if (m_scanCancellable) {
        g_cancellable_cancel(m_scanCancellable);
        g_object_unref(m_scanCancellable);
        m_scanCancellable = nullptr;
    }
    if (m_operationCancellable) {
        g_cancellable_cancel(m_operationCancellable);
        g_object_unref(m_operationCancellable);
        m_operationCancellable = nullptr;
    }

    for (const auto &[object, handler] : std::as_const(m_clientSignalHandlers))
        g_signal_handler_disconnect(object, handler);
    m_clientSignalHandlers.clear();

    if (m_client) {
        g_object_unref(m_client);
        m_client = nullptr;
    }
}

void WifiManager::initializeClient()
{
    GError *error = nullptr;
    m_client = nm_client_new(nullptr, &error);
    if (!m_client) {
        setLastError(errorMessage(error, tr("The Wi-Fi service could not be started.")));
        g_clear_error(&error);
        return;
    }

    connectClientSignals();
    refresh();
    m_refreshTimer.start();
}

void WifiManager::connectClientSignals()
{
    if (!m_client)
        return;

    auto connectNotify = [this](const char *signal) {
        const gulong handler = g_signal_connect(m_client,
                                                signal,
                                                G_CALLBACK(WifiManager::handleClientChanged),
                                                this);
        if (handler != 0)
            m_clientSignalHandlers.append({ G_OBJECT(m_client), handler });
    };
    auto connectObjectSignal = [this](const char *signal) {
        if (g_signal_lookup(signal, G_OBJECT_TYPE(m_client)) == 0)
            return;
        const gulong handler = g_signal_connect(m_client,
                                                signal,
                                                G_CALLBACK(WifiManager::handleObjectChanged),
                                                this);
        if (handler != 0)
            m_clientSignalHandlers.append({ G_OBJECT(m_client), handler });
    };

    connectNotify("notify::nm-running");
    connectNotify("notify::wireless-enabled");
    connectNotify("notify::wireless-hardware-enabled");
    connectNotify("notify::connectivity");
    connectNotify("notify::primary-connection");
    connectObjectSignal("device-added");
    connectObjectSignal("device-removed");
    connectObjectSignal("connection-added");
    connectObjectSignal("connection-removed");
    connectObjectSignal("active-connection-added");
    connectObjectSignal("active-connection-removed");
}

void WifiManager::handleClientChanged(GObject *, GParamSpec *, gpointer userData)
{
    static_cast<WifiManager *>(userData)->scheduleRefresh();
}

void WifiManager::handleObjectChanged(GObject *, gpointer, gpointer userData)
{
    static_cast<WifiManager *>(userData)->scheduleRefresh();
}

void WifiManager::scheduleRefresh()
{
    if (m_refreshScheduled)
        return;

    m_refreshScheduled = true;
    QTimer::singleShot(0, this, [this] {
        m_refreshScheduled = false;
        refresh();
    });
}

QList<NMDeviceWifi *> WifiManager::wifiDeviceObjects() const
{
    QList<NMDeviceWifi *> result;
    if (!m_client)
        return result;

    const GPtrArray *devices = nm_client_get_devices(m_client);
    if (!devices)
        return result;

    for (guint i = 0; i < devices->len; ++i) {
        auto *device = NM_DEVICE(g_ptr_array_index(devices, i));
        if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_WIFI)
            result.append(NM_DEVICE_WIFI(device));
    }
    return result;
}

NMDeviceWifi *WifiManager::selectedWifiDevice() const
{
    const QList<NMDeviceWifi *> devices = wifiDeviceObjects();
    for (NMDeviceWifi *device : devices) {
        if (fromCString(nm_device_get_iface(NM_DEVICE(device))) == m_selectedDevice)
            return device;
    }
    return nullptr;
}

void WifiManager::refresh()
{
    if (!m_client)
        return;

    const bool oldConnected = connected();
    const bool oldWifiConnected = m_wifiConnected;
    const bool oldWiredConnected = m_wiredConnected;

    const bool newAvailable = nm_client_get_nm_running(m_client);
    if (m_available != newAvailable) {
        m_available = newAvailable;
        emit availableChanged();
    }

    const bool newWifiEnabled = nm_client_wireless_get_enabled(m_client);
    if (m_wifiEnabled != newWifiEnabled) {
        m_wifiEnabled = newWifiEnabled;
        emit wifiEnabledChanged();
    }

    const bool newHardwareEnabled = nm_client_wireless_hardware_get_enabled(m_client);
    if (m_wifiHardwareEnabled != newHardwareEnabled) {
        m_wifiHardwareEnabled = newHardwareEnabled;
        emit wifiHardwareEnabledChanged();
    }

    const bool newCanCheck = nm_client_connectivity_check_get_available(m_client);
    if (m_canCheckConnectivity != newCanCheck) {
        m_canCheckConnectivity = newCanCheck;
        emit canCheckConnectivityChanged();
    }

    const int newConnectivity = nm_client_get_connectivity(m_client);
    if (m_connectivity != newConnectivity) {
        m_connectivity = newConnectivity;
        emit connectivityChanged();
    }

    const QList<NMDeviceWifi *> wifiDevices = wifiDeviceObjects();
    QVariantList deviceValues;
    QString automaticDevice;
    for (NMDeviceWifi *wifi : wifiDevices) {
        NMDevice *device = NM_DEVICE(wifi);
        const QString interfaceName = fromCString(nm_device_get_iface(device));
        const NMDeviceState state = nm_device_get_state(device);
        QVariantMap value;
        value.insert(QStringLiteral("interfaceName"), interfaceName);
        value.insert(QStringLiteral("description"), fromCString(nm_device_get_description(device)));
        value.insert(QStringLiteral("driver"), fromCString(nm_device_get_driver(device)));
        value.insert(QStringLiteral("hardwareAddress"), fromCString(nm_device_wifi_get_permanent_hw_address(wifi)));
        value.insert(QStringLiteral("state"), static_cast<int>(state));
        value.insert(QStringLiteral("connected"), state == NM_DEVICE_STATE_ACTIVATED);
        deviceValues.append(value);

        if (automaticDevice.isEmpty() || state == NM_DEVICE_STATE_ACTIVATED)
            automaticDevice = interfaceName;
    }
    if (m_wifiDevices != deviceValues) {
        m_wifiDevices = deviceValues;
        emit wifiDevicesChanged();
    }

    QString selected = m_preferredDevice;
    const bool preferredExists = std::any_of(wifiDevices.cbegin(), wifiDevices.cend(), [&selected](NMDeviceWifi *device) {
        return fromCString(nm_device_get_iface(NM_DEVICE(device))) == selected;
    });
    if (selected.isEmpty() || !preferredExists)
        selected = automaticDevice;
    if (m_selectedDevice != selected) {
        m_selectedDevice = selected;
        emit selectedDeviceChanged();
    }

    m_wifiConnected = false;
    m_wiredConnected = false;
    const GPtrArray *allDevices = nm_client_get_devices(m_client);
    if (allDevices) {
        for (guint i = 0; i < allDevices->len; ++i) {
            auto *device = NM_DEVICE(g_ptr_array_index(allDevices, i));
            if (nm_device_get_state(device) != NM_DEVICE_STATE_ACTIVATED)
                continue;
            if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_WIFI)
                m_wifiConnected = true;
            if (nm_device_get_device_type(device) == NM_DEVICE_TYPE_ETHERNET)
                m_wiredConnected = true;
        }
    }

    NMDeviceWifi *selectedWifi = selectedWifiDevice();
    QString activeSsid;
    int activeStrength = 0;
    if (selectedWifi) {
        if (NMAccessPoint *accessPoint = nm_device_wifi_get_active_access_point(selectedWifi)) {
            activeSsid = displaySsid(nm_access_point_get_ssid(accessPoint));
            activeStrength = nm_access_point_get_strength(accessPoint);
        }
        refreshNetworks(selectedWifi);
        updateActivationState(selectedWifi);
    } else {
        m_networks.replace({});
    }
    refreshSavedNetworks(selectedWifi);

    if (m_connectedSsid != activeSsid) {
        m_connectedSsid = activeSsid;
        emit connectedSsidChanged();
    }
    if (m_connectedStrength != activeStrength) {
        m_connectedStrength = activeStrength;
        emit connectedStrengthChanged();
    }

    emitConnectedSignals(oldWifiConnected, oldWiredConnected);
    if (oldConnected != connected())
        emit connectedChanged();
}

void WifiManager::emitConnectedSignals(bool oldWifiConnected, bool oldWiredConnected)
{
    if (oldWifiConnected != m_wifiConnected)
        emit wifiConnectedChanged();
    if (oldWiredConnected != m_wiredConnected)
        emit wiredConnectedChanged();
}

WifiManager::Security WifiManager::securityForAccessPoint(NMAccessPoint *accessPoint) const
{
    if (!accessPoint)
        return UnknownSecurity;

    const NM80211ApFlags flags = nm_access_point_get_flags(accessPoint);
    const NM80211ApSecurityFlags wpa = nm_access_point_get_wpa_flags(accessPoint);
    const NM80211ApSecurityFlags rsn = nm_access_point_get_rsn_flags(accessPoint);
    const guint32 security = static_cast<guint32>(wpa) | static_cast<guint32>(rsn);

    if (security & NM_802_11_AP_SEC_KEY_MGMT_SAE)
        return Wpa3Personal;
    if (security & (NM_802_11_AP_SEC_KEY_MGMT_OWE | NM_802_11_AP_SEC_KEY_MGMT_OWE_TM))
        return Owe;
    if (security & NM_802_11_AP_SEC_KEY_MGMT_802_1X)
        return Enterprise;
    if (security & NM_802_11_AP_SEC_KEY_MGMT_PSK)
        return WpaPersonal;
    if (flags & NM_802_11_AP_FLAGS_PRIVACY)
        return Wep;
    return Open;
}

WifiManager::Security WifiManager::securityForConnection(NMConnection *connection) const
{
    if (!connection)
        return UnknownSecurity;

    auto *security = nm_connection_get_setting_wireless_security(connection);
    if (!security)
        return Open;

    const QString keyManagement = fromCString(nm_setting_wireless_security_get_key_mgmt(security));
    if (keyManagement == QStringLiteral("sae"))
        return Wpa3Personal;
    if (keyManagement == QStringLiteral("owe"))
        return Owe;
    if (keyManagement == QStringLiteral("wpa-eap") || keyManagement == QStringLiteral("ieee8021x"))
        return Enterprise;
    if (keyManagement == QStringLiteral("wpa-psk"))
        return WpaPersonal;
    if (nm_setting_wireless_security_get_wep_key(security, 0))
        return Wep;
    return UnknownSecurity;
}

QString WifiManager::displaySsid(GBytes *ssid) const
{
    if (!ssid)
        return {};

    gsize size = 0;
    const auto *data = static_cast<const guint8 *>(g_bytes_get_data(ssid, &size));
    char *utf8 = nm_utils_ssid_to_utf8(data, size);
    const QString result = fromCString(utf8);
    g_free(utf8);
    return result;
}

QString WifiManager::networkId(GBytes *ssid, Security security) const
{
    QByteArray value = bytesFromSsid(ssid);
    value.append(':');
    value.append(QByteArray::number(static_cast<int>(security)));
    return QString::fromLatin1(QCryptographicHash::hash(value, QCryptographicHash::Sha256).toHex().left(24));
}

void WifiManager::refreshNetworks(NMDeviceWifi *device)
{
    QList<WifiNetworkEntry> entries;
    QHash<QString, int> entryById;
    const GPtrArray *accessPoints = nm_device_wifi_get_access_points(device);
    NMAccessPoint *activeAccessPoint = nm_device_wifi_get_active_access_point(device);
    const NMDeviceState deviceState = nm_device_get_state(NM_DEVICE(device));

    if (accessPoints) {
        for (guint i = 0; i < accessPoints->len; ++i) {
            auto *accessPoint = NM_ACCESS_POINT(g_ptr_array_index(accessPoints, i));
            GBytes *ssid = nm_access_point_get_ssid(accessPoint);
            const QByteArray rawSsid = bytesFromSsid(ssid);
            const QString visibleSsid = displaySsid(ssid);
            if (rawSsid.isEmpty() || visibleSsid.isEmpty())
                continue;

            const Security security = securityForAccessPoint(accessPoint);
            const QString id = networkId(ssid, security);
            const int strength = nm_access_point_get_strength(accessPoint);
            auto existing = entryById.constFind(id);
            if (existing != entryById.cend()) {
                WifiNetworkEntry &entry = entries[*existing];
                if (strength > entry.strength) {
                    entry.strength = strength;
                    entry.frequency = static_cast<int>(nm_access_point_get_frequency(accessPoint));
                    entry.bssid = fromCString(nm_access_point_get_bssid(accessPoint));
                    entry.accessPoint = accessPoint;
                }
                continue;
            }

            WifiNetworkEntry entry;
            entry.id = id;
            entry.ssid = visibleSsid;
            entry.ssidBytes = rawSsid;
            entry.strength = strength;
            entry.security = security;
            entry.securityName = securityLabel(security);
            entry.frequency = static_cast<int>(nm_access_point_get_frequency(accessPoint));
            entry.bssid = fromCString(nm_access_point_get_bssid(accessPoint));
            entry.deviceName = fromCString(nm_device_get_iface(NM_DEVICE(device)));
            entry.accessPoint = accessPoint;
            entry.hidden = false;
            entryById.insert(id, entries.size());
            entries.append(entry);
        }
    }

    const GPtrArray *connections = nm_client_get_connections(m_client);
    const QString activeUuid = [&] {
        NMActiveConnection *active = nm_device_get_active_connection(NM_DEVICE(device));
        return active ? fromCString(nm_active_connection_get_uuid(active)) : QString();
    }();

    for (WifiNetworkEntry &entry : entries) {
        NMRemoteConnection *selectedConnection = nullptr;
        if (entry.accessPoint && connections) {
            for (guint i = 0; i < connections->len; ++i) {
                auto *candidate = NM_REMOTE_CONNECTION(g_ptr_array_index(connections, i));
                if (!nm_access_point_connection_valid(entry.accessPoint, NM_CONNECTION(candidate)))
                    continue;
                const QString uuid = fromCString(nm_connection_get_uuid(NM_CONNECTION(candidate)));
                if (!selectedConnection || uuid == activeUuid)
                    selectedConnection = candidate;
                if (uuid == activeUuid)
                    break;
            }
        }

        entry.connection = selectedConnection;
        entry.known = selectedConnection != nullptr;
        if (selectedConnection) {
            entry.profileUuid = fromCString(nm_connection_get_uuid(NM_CONNECTION(selectedConnection)));
            if (auto *setting = nm_connection_get_setting_connection(NM_CONNECTION(selectedConnection)))
                entry.autoconnect = nm_setting_connection_get_autoconnect(setting);
        }

        if (activeAccessPoint) {
            const QString activeId = networkId(nm_access_point_get_ssid(activeAccessPoint),
                                               securityForAccessPoint(activeAccessPoint));
            entry.connected = deviceState == NM_DEVICE_STATE_ACTIVATED && entry.id == activeId;
            entry.connecting = deviceIsConnecting(deviceState) && entry.id == activeId;
        }
        if (m_operationBusy && m_currentOperation == QStringLiteral("connect")
            && entry.id == m_pendingNetworkId) {
            entry.connecting = true;
        }
    }

    std::sort(entries.begin(), entries.end(), [](const WifiNetworkEntry &left, const WifiNetworkEntry &right) {
        if (left.connected != right.connected)
            return left.connected;
        if (left.connecting != right.connecting)
            return left.connecting;
        if (left.known != right.known)
            return left.known;
        if (left.strength != right.strength)
            return left.strength > right.strength;
        return QString::localeAwareCompare(left.ssid, right.ssid) < 0;
    });

    m_networks.replace(std::move(entries));
}

void WifiManager::refreshSavedNetworks(NMDeviceWifi *device)
{
    QList<WifiNetworkEntry> entries;
    if (!m_client) {
        m_savedNetworks.replace({});
        return;
    }

    QHash<QString, NMDeviceState> activeProfiles;
    for (NMDeviceWifi *wifiDevice : wifiDeviceObjects()) {
        NMActiveConnection *active = nm_device_get_active_connection(NM_DEVICE(wifiDevice));
        if (!active)
            continue;
        activeProfiles.insert(fromCString(nm_active_connection_get_uuid(active)),
                              nm_device_get_state(NM_DEVICE(wifiDevice)));
    }

    const GPtrArray *connections = nm_client_get_connections(m_client);
    if (!connections) {
        m_savedNetworks.replace({});
        return;
    }

    const GPtrArray *accessPoints = device ? nm_device_wifi_get_access_points(device) : nullptr;
    for (guint connectionIndex = 0; connectionIndex < connections->len; ++connectionIndex) {
        auto *connection = NM_REMOTE_CONNECTION(g_ptr_array_index(connections, connectionIndex));
        NMConnection *baseConnection = NM_CONNECTION(connection);
        auto *wireless = nm_connection_get_setting_wireless(baseConnection);
        auto *connectionSetting = nm_connection_get_setting_connection(baseConnection);
        if (!wireless || !connectionSetting)
            continue;
        const char *mode = nm_setting_wireless_get_mode(wireless);
        if (mode && g_strcmp0(mode, NM_SETTING_WIRELESS_MODE_INFRA) != 0)
            continue;

        GBytes *ssid = nm_setting_wireless_get_ssid(wireless);
        const QByteArray rawSsid = bytesFromSsid(ssid);
        const QString visibleSsid = displaySsid(ssid);
        const QString uuid = fromCString(nm_setting_connection_get_uuid(connectionSetting));
        if (rawSsid.isEmpty() || visibleSsid.isEmpty() || uuid.isEmpty())
            continue;

        WifiNetworkEntry entry;
        entry.id = QStringLiteral("profile:") + uuid;
        entry.ssid = visibleSsid;
        entry.ssidBytes = rawSsid;
        entry.security = securityForConnection(baseConnection);
        entry.securityName = securityLabel(entry.security);
        entry.known = true;
        entry.autoconnect = nm_setting_connection_get_autoconnect(connectionSetting);
        entry.hidden = nm_setting_wireless_get_hidden(wireless);
        entry.deviceName = device ? fromCString(nm_device_get_iface(NM_DEVICE(device))) : QString();
        entry.profileUuid = uuid;
        entry.connection = connection;

        const auto active = activeProfiles.constFind(uuid);
        if (active != activeProfiles.cend()) {
            entry.connected = *active == NM_DEVICE_STATE_ACTIVATED;
            entry.connecting = deviceIsConnecting(*active);
        }
        if (m_operationBusy && m_currentOperation == QStringLiteral("connect")
            && entry.id == m_pendingNetworkId) {
            entry.connecting = true;
        }

        if (accessPoints) {
            for (guint accessPointIndex = 0; accessPointIndex < accessPoints->len; ++accessPointIndex) {
                auto *accessPoint = NM_ACCESS_POINT(g_ptr_array_index(accessPoints, accessPointIndex));
                if (!nm_access_point_connection_valid(accessPoint, baseConnection)
                    || nm_access_point_get_strength(accessPoint) <= entry.strength) {
                    continue;
                }

                entry.strength = nm_access_point_get_strength(accessPoint);
                entry.frequency = static_cast<int>(nm_access_point_get_frequency(accessPoint));
                entry.bssid = fromCString(nm_access_point_get_bssid(accessPoint));
                entry.accessPoint = accessPoint;
            }
        }

        entries.append(entry);
    }

    std::sort(entries.begin(), entries.end(), [](const WifiNetworkEntry &left, const WifiNetworkEntry &right) {
        if (left.connected != right.connected)
            return left.connected;
        if (left.connecting != right.connecting)
            return left.connecting;
        return QString::localeAwareCompare(left.ssid, right.ssid) < 0;
    });
    m_savedNetworks.replace(std::move(entries));
}

const WifiNetworkEntry *WifiManager::network(const QString &networkIdValue) const
{
    if (const WifiNetworkEntry *entry = m_networks.find(networkIdValue))
        return entry;
    return m_savedNetworks.find(networkIdValue);
}

bool WifiManager::setWifiEnabled(bool enabled)
{
    if (!m_client || !m_available) {
        setLastError(tr("The Wi-Fi service is unavailable."));
        return false;
    }
    if (enabled && !m_wifiHardwareEnabled) {
        setLastError(tr("Wi-Fi is disabled by a hardware switch."));
        return false;
    }

    clearLastError();
    g_object_set(G_OBJECT(m_client), NM_CLIENT_WIRELESS_ENABLED, enabled, nullptr);
    scheduleRefresh();
    return true;
}

bool WifiManager::selectDevice(const QString &interfaceName)
{
    const QList<NMDeviceWifi *> devices = wifiDeviceObjects();
    const bool exists = std::any_of(devices.cbegin(), devices.cend(), [&interfaceName](NMDeviceWifi *device) {
        return fromCString(nm_device_get_iface(NM_DEVICE(device))) == interfaceName;
    });
    if (!exists) {
        setLastError(tr("Wi-Fi adapter %1 is unavailable.").arg(interfaceName));
        return false;
    }

    m_preferredDevice = interfaceName;
    clearLastError();
    refresh();
    return true;
}

bool WifiManager::requestScan()
{
    NMDeviceWifi *device = selectedWifiDevice();
    if (!device || !m_wifiEnabled || m_scanInFlight)
        return false;

    // NetworkManager reports wireless-enabled before the device finishes
    // moving out of UNAVAILABLE. Queueing a scan during that transition
    // produces a noisy "Scanning not allowed while unavailable" failure.
    // Let the QML retry loop call us again once the device is scan-ready.
    if (nm_device_get_state(NM_DEVICE(device)) < NM_DEVICE_STATE_DISCONNECTED) {
        clearLastError();
        return false;
    }

    clearLastError();
    m_scanCancellable = g_cancellable_new();
    m_scanInFlight = true;
    emit scanningChanged();
    auto *context = new AsyncContext { QPointer<WifiManager>(this), {}, {}, 0 };
    nm_device_wifi_request_scan_async(device,
                                      m_scanCancellable,
                                      WifiManager::handleScanFinished,
                                      context);
    return true;
}

void WifiManager::handleScanFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    const bool success = nm_device_wifi_request_scan_finish(NM_DEVICE_WIFI(source), result, &error);
    if (!context->manager) {
        g_clear_error(&error);
        return;
    }

    WifiManager *manager = context->manager;
    if (manager->m_scanCancellable) {
        g_object_unref(manager->m_scanCancellable);
        manager->m_scanCancellable = nullptr;
    }
    manager->m_scanInFlight = false;
    emit manager->scanningChanged();
    const QString message = success ? QString() : errorMessage(error, manager->tr("Could not scan for Wi-Fi networks."));
    if (!success && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
        manager->setLastError(message);
    emit manager->scanFinished(success, message);
    manager->scheduleRefresh();
    g_clear_error(&error);
}

bool WifiManager::checkConnectivity()
{
    if (!m_client || !m_canCheckConnectivity)
        return false;

    auto *context = new AsyncContext { QPointer<WifiManager>(this), {}, {}, 0 };
    nm_client_check_connectivity_async(m_client, nullptr, WifiManager::handleConnectivityFinished, context);
    return true;
}

void WifiManager::handleConnectivityFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    nm_client_check_connectivity_finish(NM_CLIENT(source), result, &error);
    if (context->manager) {
        if (error)
            context->manager->setLastError(errorMessage(error, context->manager->tr("Could not check internet connectivity.")));
        context->manager->scheduleRefresh();
    }
    g_clear_error(&error);
}

QString WifiManager::validatePassword(int securityValue, const QString &password) const
{
    if (password.contains(u'\n') || password.contains(u'\r'))
        return tr("The password cannot contain a newline");

    const Security security = static_cast<Security>(securityValue);
    if (security == WpaPersonal) {
        const bool passphrase = password.size() >= 8 && password.size() <= 63;
        const bool rawKey = password.size() == 64
            && std::all_of(password.cbegin(), password.cend(), [](QChar character) {
                   const ushort value = character.unicode();
                   return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f')
                       || (value >= 'A' && value <= 'F');
               });
        if (!passphrase && !rawKey)
            return tr("A WPA password must contain 8–63 characters or be a 64-digit hexadecimal key");
    } else if (security == Wpa3Personal) {
        if (password.isEmpty() || password.size() > 63)
            return tr("A WPA3 password must contain 1–63 characters");
    } else if (security == Wep) {
        const int size = password.size();
        const bool asciiKey = size == 5 || size == 13;
        const bool hexKey = (size == 10 || size == 26)
            && std::all_of(password.cbegin(), password.cend(), [](QChar character) {
                   const ushort value = character.unicode();
                   return (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f')
                       || (value >= 'A' && value <= 'F');
               });
        if (!asciiKey && !hexKey)
            return tr("A WEP key must contain 5 or 13 characters, or 10 or 26 hexadecimal digits");
    }
    return {};
}

QString WifiManager::securityLabel(int securityValue) const
{
    switch (static_cast<Security>(securityValue)) {
    case Open:
        return tr("Open");
    case Wep:
        return tr("WEP");
    case WpaPersonal:
        return tr("WPA/WPA2 Personal");
    case Wpa3Personal:
        return tr("WPA3 Personal");
    case Owe:
        return tr("Enhanced Open");
    case Enterprise:
        return tr("Enterprise");
    case UnknownSecurity:
        return tr("Unknown security");
    }
    return tr("Unknown security");
}

NMConnection *WifiManager::createConnection(const QString &ssid,
                                             const QByteArray &ssidBytes,
                                             const QString &password,
                                             Security security,
                                             bool hidden) const
{
    NMConnection *connection = nm_simple_connection_new();

    auto *connectionSetting = NM_SETTING_CONNECTION(nm_setting_connection_new());
    const QByteArray connectionId = ssid.toUtf8();
    const QByteArray uuid = QUuid::createUuid().toString(QUuid::WithoutBraces).toUtf8();
    g_object_set(G_OBJECT(connectionSetting),
                 NM_SETTING_CONNECTION_ID,
                 connectionId.constData(),
                 NM_SETTING_CONNECTION_UUID,
                 uuid.constData(),
                 NM_SETTING_CONNECTION_TYPE,
                 NM_SETTING_WIRELESS_SETTING_NAME,
                 NM_SETTING_CONNECTION_AUTOCONNECT,
                 TRUE,
                 nullptr);
    const char *userName = g_get_user_name();
    if (userName && *userName)
        nm_setting_connection_add_permission(connectionSetting, "user", userName, nullptr);
    nm_connection_add_setting(connection, NM_SETTING(connectionSetting));

    auto *wirelessSetting = NM_SETTING_WIRELESS(nm_setting_wireless_new());
    GBytes *ssidValue = g_bytes_new(ssidBytes.constData(), static_cast<gsize>(ssidBytes.size()));
    g_object_set(G_OBJECT(wirelessSetting),
                 NM_SETTING_WIRELESS_SSID,
                 ssidValue,
                 NM_SETTING_WIRELESS_MODE,
                 NM_SETTING_WIRELESS_MODE_INFRA,
                 NM_SETTING_WIRELESS_HIDDEN,
                 hidden,
                 nullptr);
    g_bytes_unref(ssidValue);
    nm_connection_add_setting(connection, NM_SETTING(wirelessSetting));

    if (security != Open) {
        auto *securitySetting = NM_SETTING_WIRELESS_SECURITY(nm_setting_wireless_security_new());
        const QByteArray encodedPassword = password.toUtf8();
        switch (security) {
        case Wep:
            g_object_set(G_OBJECT(securitySetting),
                         NM_SETTING_WIRELESS_SECURITY_KEY_MGMT,
                         "none",
                         NM_SETTING_WIRELESS_SECURITY_WEP_KEY_TYPE,
                         NM_WEP_KEY_TYPE_KEY,
                         nullptr);
            nm_setting_wireless_security_set_wep_key(securitySetting, 0, encodedPassword.constData());
            break;
        case WpaPersonal:
            g_object_set(G_OBJECT(securitySetting),
                         NM_SETTING_WIRELESS_SECURITY_KEY_MGMT,
                         "wpa-psk",
                         NM_SETTING_WIRELESS_SECURITY_PSK,
                         encodedPassword.constData(),
                         nullptr);
            break;
        case Wpa3Personal:
            g_object_set(G_OBJECT(securitySetting),
                         NM_SETTING_WIRELESS_SECURITY_KEY_MGMT,
                         "sae",
                         NM_SETTING_WIRELESS_SECURITY_PSK,
                         encodedPassword.constData(),
                         nullptr);
            break;
        case Owe:
            g_object_set(G_OBJECT(securitySetting), NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, "owe", nullptr);
            break;
        case Enterprise:
        case UnknownSecurity:
        case Open:
            g_object_unref(securitySetting);
            g_object_unref(connection);
            return nullptr;
        }
        nm_connection_add_setting(connection, NM_SETTING(securitySetting));
    }

    auto *ipv4 = NM_SETTING_IP_CONFIG(nm_setting_ip4_config_new());
    g_object_set(G_OBJECT(ipv4), NM_SETTING_IP_CONFIG_METHOD, NM_SETTING_IP4_CONFIG_METHOD_AUTO, nullptr);
    nm_connection_add_setting(connection, NM_SETTING(ipv4));

    auto *ipv6 = NM_SETTING_IP_CONFIG(nm_setting_ip6_config_new());
    g_object_set(G_OBJECT(ipv6), NM_SETTING_IP_CONFIG_METHOD, NM_SETTING_IP6_CONFIG_METHOD_AUTO, nullptr);
    nm_connection_add_setting(connection, NM_SETTING(ipv6));
    return connection;
}

bool WifiManager::connectNetwork(const QString &networkIdValue)
{
    const WifiNetworkEntry *entry = network(networkIdValue);
    if (!entry) {
        setLastError(tr("The Wi-Fi network is no longer available."));
        return false;
    }
    if (entry->connected)
        return true;
    if (!entry->known && entry->security != Open && entry->security != Owe) {
        emit credentialsRequired(entry->id, entry->ssid, entry->security);
        return true;
    }
    return activateEntry(*entry, {});
}

bool WifiManager::connectNetworkWithPassword(const QString &networkIdValue, const QString &password)
{
    const WifiNetworkEntry *entry = network(networkIdValue);
    if (!entry) {
        setLastError(tr("The Wi-Fi network is no longer available."));
        return false;
    }
    const QString validationError = validatePassword(entry->security, password);
    if (!validationError.isEmpty()) {
        setLastError(validationError);
        return false;
    }
    return activateEntry(*entry, password);
}

bool WifiManager::activateEntry(const WifiNetworkEntry &entry, const QString &password)
{
    NMDeviceWifi *device = selectedWifiDevice();
    if (!device) {
        setLastError(tr("No Wi-Fi adapter is available."));
        return false;
    }
    if (entry.connection && password.isEmpty()) {
        if (!beginOperation(QStringLiteral("connect"), entry.id, entry.ssid))
            return false;
        auto *context = new AsyncContext {
            QPointer<WifiManager>(this), entry.id, entry.ssid, m_operationGeneration
        };
        const char *specific = entry.accessPoint ? nm_object_get_path(NM_OBJECT(entry.accessPoint)) : nullptr;
        nm_client_activate_connection_async(m_client,
                                            NM_CONNECTION(entry.connection),
                                            NM_DEVICE(device),
                                            specific,
                                            m_operationCancellable,
                                            WifiManager::handleActivationFinished,
                                            context);
        return true;
    }
    return activateNew(entry.id,
                       entry.ssid,
                       entry.ssidBytes,
                       password,
                       static_cast<Security>(entry.security),
                       false,
                       entry.accessPoint);
}

bool WifiManager::activateNew(const QString &id,
                              const QString &ssid,
                              const QByteArray &ssidBytes,
                              const QString &password,
                              Security security,
                              bool hidden,
                              NMAccessPoint *accessPoint)
{
    NMDeviceWifi *device = selectedWifiDevice();
    if (!device) {
        setLastError(tr("No Wi-Fi adapter is available."));
        return false;
    }
    if (security == Enterprise || security == UnknownSecurity) {
        setLastError(tr("Enterprise Wi-Fi networks must be configured in system network settings."));
        return false;
    }
    const QString validationError = validatePassword(security, password);
    if (!validationError.isEmpty()) {
        setLastError(validationError);
        return false;
    }

    NMConnection *connection = createConnection(ssid, ssidBytes, password, security, hidden);
    if (!connection) {
        setLastError(tr("Could not create the Wi-Fi settings."));
        return false;
    }
    if (!beginOperation(QStringLiteral("connect"), id, ssid)) {
        g_object_unref(connection);
        return false;
    }

    auto *context = new AsyncContext { QPointer<WifiManager>(this), id, ssid, m_operationGeneration };
    const char *specific = accessPoint ? nm_object_get_path(NM_OBJECT(accessPoint)) : nullptr;
    nm_client_add_and_activate_connection_async(m_client,
                                                connection,
                                                NM_DEVICE(device),
                                                specific,
                                                m_operationCancellable,
                                                WifiManager::handleAddActivationFinished,
                                                context);
    g_object_unref(connection);
    return true;
}

bool WifiManager::addAndConnect(const QString &ssid,
                                const QString &password,
                                int securityValue,
                                bool hidden)
{
    if (ssid.trimmed().isEmpty()) {
        setLastError(tr("The network name cannot be empty."));
        return false;
    }
    if (ssid.contains(u'\n') || ssid.contains(u'\r')) {
        setLastError(tr("The network name cannot contain a newline."));
        return false;
    }
    const QByteArray bytes = ssid.toUtf8();
    if (bytes.size() > 32) {
        setLastError(tr("A Wi-Fi network name cannot exceed 32 bytes."));
        return false;
    }

    if (securityValue < Open || securityValue >= UnknownSecurity) {
        setLastError(tr("The selected Wi-Fi security type is not supported."));
        return false;
    }

    const Security security = static_cast<Security>(securityValue);
    GBytes *ssidBytes = g_bytes_new(bytes.constData(), static_cast<gsize>(bytes.size()));
    const QString id = networkId(ssidBytes, security);
    g_bytes_unref(ssidBytes);
    return activateNew(id, ssid, bytes, password, security, hidden, nullptr);
}

void WifiManager::handleActivationFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    NMActiveConnection *active = nm_client_activate_connection_finish(NM_CLIENT(source), result, &error);
    if (active)
        g_object_unref(active);
    if (context->manager
        && context->operationGeneration == context->manager->m_operationGeneration) {
        if (error)
            context->manager->failOperation(errorMessage(error, context->manager->tr("Could not connect to the Wi-Fi network.")));
        else
            context->manager->markActivationAccepted();
    }
    g_clear_error(&error);
}

void WifiManager::handleAddActivationFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    NMActiveConnection *active = nm_client_add_and_activate_connection_finish(NM_CLIENT(source), result, &error);
    if (active)
        g_object_unref(active);
    if (context->manager
        && context->operationGeneration == context->manager->m_operationGeneration) {
        if (error)
            context->manager->failOperation(errorMessage(error, context->manager->tr("Could not save and connect to the Wi-Fi network.")));
        else
            context->manager->markActivationAccepted();
    }
    g_clear_error(&error);
}

bool WifiManager::disconnectNetwork(const QString &networkIdValue)
{
    const WifiNetworkEntry *entry = network(networkIdValue);
    NMDeviceWifi *device = selectedWifiDevice();
    if (!entry || !device || !entry->connected) {
        setLastError(tr("The selected Wi-Fi network is not connected."));
        return false;
    }
    if (!beginOperation(QStringLiteral("disconnect"), entry->id, entry->ssid))
        return false;

    auto *context = new AsyncContext {
        QPointer<WifiManager>(this), entry->id, entry->ssid, m_operationGeneration
    };
    nm_device_disconnect_async(NM_DEVICE(device),
                               m_operationCancellable,
                               WifiManager::handleDisconnectFinished,
                               context);
    return true;
}

void WifiManager::handleDisconnectFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    const bool success = nm_device_disconnect_finish(NM_DEVICE(source), result, &error);
    if (context->manager
        && context->operationGeneration == context->manager->m_operationGeneration) {
        WifiManager *manager = context->manager;
        if (!success)
            manager->failOperation(errorMessage(error, manager->tr("Could not disconnect from the Wi-Fi network.")));
        else {
            const QString id = manager->m_pendingNetworkId;
            manager->finishOperation();
            emit manager->networkDisconnected(id);
            manager->scheduleRefresh();
        }
    }
    g_clear_error(&error);
}

bool WifiManager::forgetNetwork(const QString &networkIdValue)
{
    const WifiNetworkEntry *entry = network(networkIdValue);
    if (!entry || !entry->connection) {
        setLastError(tr("This Wi-Fi network is not saved."));
        return false;
    }
    if (!beginOperation(QStringLiteral("forget"), entry->id, entry->ssid))
        return false;

    auto *context = new AsyncContext {
        QPointer<WifiManager>(this), entry->id, entry->ssid, m_operationGeneration
    };
    nm_remote_connection_delete_async(entry->connection,
                                      m_operationCancellable,
                                      WifiManager::handleDeleteFinished,
                                      context);
    return true;
}

void WifiManager::handleDeleteFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    const bool success = nm_remote_connection_delete_finish(NM_REMOTE_CONNECTION(source), result, &error);
    if (context->manager
        && context->operationGeneration == context->manager->m_operationGeneration) {
        WifiManager *manager = context->manager;
        if (!success)
            manager->failOperation(errorMessage(error, manager->tr("Could not forget the Wi-Fi network.")));
        else {
            const QString id = manager->m_pendingNetworkId;
            manager->finishOperation();
            emit manager->networkForgotten(id);
            manager->scheduleRefresh();
        }
    }
    g_clear_error(&error);
}

bool WifiManager::setAutoconnect(const QString &networkIdValue, bool enabled)
{
    const WifiNetworkEntry *entry = network(networkIdValue);
    if (!entry || !entry->connection) {
        setLastError(tr("This Wi-Fi network is not saved."));
        return false;
    }
    auto *setting = nm_connection_get_setting_connection(NM_CONNECTION(entry->connection));
    if (!setting) {
        setLastError(tr("The saved Wi-Fi settings are invalid."));
        return false;
    }
    if (!beginOperation(QStringLiteral("autoconnect"), entry->id, entry->ssid))
        return false;

    g_object_set(G_OBJECT(setting), NM_SETTING_CONNECTION_AUTOCONNECT, enabled, nullptr);
    auto *context = new AsyncContext {
        QPointer<WifiManager>(this), entry->id, entry->ssid, m_operationGeneration
    };
    context->requestedAutoconnect = enabled;
    nm_remote_connection_commit_changes_async(entry->connection,
                                              TRUE,
                                              m_operationCancellable,
                                              WifiManager::handleCommitFinished,
                                              context);
    return true;
}

void WifiManager::handleCommitFinished(GObject *source, GAsyncResult *result, gpointer userData)
{
    std::unique_ptr<AsyncContext> context(static_cast<AsyncContext *>(userData));
    GError *error = nullptr;
    const bool success = nm_remote_connection_commit_changes_finish(NM_REMOTE_CONNECTION(source), result, &error);
    if (context->manager
        && context->operationGeneration == context->manager->m_operationGeneration) {
        if (!success)
            context->manager->failOperation(errorMessage(error, context->manager->tr("Could not update the saved Wi-Fi network.")));
        else {
            WifiManager *manager = context->manager;
            const QString id = context->networkId;
            const bool enabled = context->requestedAutoconnect;
            manager->finishOperation();
            emit manager->networkAutoconnectChanged(id, enabled);
            manager->scheduleRefresh();
        }
    }
    g_clear_error(&error);
}

bool WifiManager::beginOperation(const QString &operation, const QString &networkIdValue, const QString &ssid)
{
    if (m_operationBusy) {
        setLastError(tr("Another Wi-Fi operation is already in progress."));
        return false;
    }

    clearLastError();
    m_operationCancellable = g_cancellable_new();
    ++m_operationGeneration;
    m_operationBusy = true;
    m_activationAccepted = false;
    m_currentOperation = operation;
    m_pendingNetworkId = networkIdValue;
    m_pendingSsid = ssid;
    emit operationBusyChanged();
    emit currentOperationChanged();
    m_operationTimeout.start();
    scheduleRefresh();
    return true;
}

void WifiManager::markActivationAccepted()
{
    m_activationAccepted = true;
    m_activationElapsed.restart();
    scheduleRefresh();
}

void WifiManager::updateActivationState(NMDeviceWifi *device)
{
    if (!m_operationBusy || m_currentOperation != QStringLiteral("connect") || !m_activationAccepted)
        return;

    const NMDeviceState state = nm_device_get_state(NM_DEVICE(device));
    NMAccessPoint *activeAccessPoint = nm_device_wifi_get_active_access_point(device);
    const QString activeNetworkId = activeAccessPoint
        ? networkId(nm_access_point_get_ssid(activeAccessPoint), securityForAccessPoint(activeAccessPoint))
        : QString();
    NMActiveConnection *activeConnection = nm_device_get_active_connection(NM_DEVICE(device));
    const QString activeProfileId = activeConnection
        ? QStringLiteral("profile:") + fromCString(nm_active_connection_get_uuid(activeConnection))
        : QString();
    const bool requestedNetworkIsActive = activeNetworkId == m_pendingNetworkId
        || activeProfileId == m_pendingNetworkId;
    if (state == NM_DEVICE_STATE_ACTIVATED && requestedNetworkIsActive) {
        const QString id = m_pendingNetworkId;
        const QString ssid = m_pendingSsid;
        finishOperation();
        emit networkConnected(id, ssid);
        checkConnectivity();
        return;
    }
    if (state == NM_DEVICE_STATE_FAILED
        || (m_activationElapsed.hasExpired(3000) && state <= NM_DEVICE_STATE_DISCONNECTED)) {
        const NMDeviceStateReason reason = nm_device_get_state_reason(NM_DEVICE(device));
        failOperation(activationFailureMessage(reason));
    }
}

void WifiManager::finishOperation()
{
    m_operationTimeout.stop();
    if (m_operationCancellable) {
        g_object_unref(m_operationCancellable);
        m_operationCancellable = nullptr;
    }
    const bool wasBusy = m_operationBusy;
    const bool hadOperation = !m_currentOperation.isEmpty();
    m_operationBusy = false;
    m_activationAccepted = false;
    m_currentOperation.clear();
    m_pendingNetworkId.clear();
    m_pendingSsid.clear();
    ++m_operationGeneration;
    if (wasBusy)
        emit operationBusyChanged();
    if (hadOperation)
        emit currentOperationChanged();
}

void WifiManager::failOperation(const QString &message)
{
    const QString operation = m_currentOperation;
    finishOperation();
    setLastError(message);
    emit operationFailed(operation, message);
    scheduleRefresh();
}

void WifiManager::cancelOperation()
{
    if (!m_operationBusy)
        return;
    if (m_operationCancellable)
        g_cancellable_cancel(m_operationCancellable);
    failOperation(tr("The Wi-Fi operation was cancelled."));
}

void WifiManager::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

void WifiManager::clearLastError()
{
    setLastError({});
}
