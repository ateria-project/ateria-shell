pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    /*
     * Native adapter controls
     */

    id: root

    /*
     * Device selection
     *
     * Leave preferredWifiDeviceName empty to automatically use:
     * 1. A connected Wi-Fi adapter
     * 2. Otherwise, the first available Wi-Fi adapter
     */
    property string preferredWifiDeviceName: ""
    // Native Quickshell state
    readonly property bool available: Networking.backend !== NetworkBackendType.None
    readonly property int backend: Networking.backend
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevices: root.devices.filter(device => {
        return device.type === DeviceType.Wifi;
    })
    readonly property var wiredDevices: root.devices.filter(device => {
        return device.type === DeviceType.Wired;
    })
    readonly property var selectedWifiDevice: {
        const devices = root.wifiDevices;
        if (devices.length === 0)
            return null;

        if (root.preferredWifiDeviceName.length > 0) {
            const preferred = devices.find(device => {
                return device.name === root.preferredWifiDeviceName;
            });
            if (preferred !== undefined)
                return preferred;
        }
        return devices.find(device => {
            return device.connected;
        }) ?? devices[0];
    }
    readonly property bool hasWifiDevice: root.selectedWifiDevice !== null
    readonly property bool hasWiredDevice: root.wiredDevices.length > 0
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool scanning: root.selectedWifiDevice !== null && root.selectedWifiDevice.scannerEnabled
    readonly property bool wifiConnected: root.wifiDevices.some(device => {
        return device.connected;
    })
    readonly property bool wiredConnected: root.wiredDevices.some(device => {
        return device.connected;
    })
    readonly property bool connected: root.wifiConnected || root.wiredConnected
    readonly property int connectivity: Networking.connectivity
    readonly property bool hasInternet: root.connectivity === NetworkConnectivity.Full
    readonly property bool captivePortal: root.connectivity === NetworkConnectivity.Portal
    readonly property bool limitedConnectivity: root.connectivity === NetworkConnectivity.Limited
    readonly property bool canCheckConnectivity: Networking.canCheckConnectivity
    /*
     * Networks belonging to the selected Wi-Fi adapter.
     *
     * Connected and connecting networks are shown first, followed by
     * known networks, then signal strength.
     */
    readonly property var wifiNetworks: {
        const device = root.selectedWifiDevice;
        if (device === null)
            return [];

        return device.networks.values.filter(network => {
            return network.name.length > 0;
        }).slice().sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1;

            if (left.stateChanging !== right.stateChanging)
                return left.stateChanging ? -1 : 1;

            if (left.known !== right.known)
                return left.known ? -1 : 1;

            if (left.signalStrength !== right.signalStrength)
                return right.signalStrength - left.signalStrength;

            return left.name.localeCompare(right.name);
        });
    }
    readonly property var knownWifiNetworks: root.wifiNetworks.filter(network => {
        return network.known;
    })
    readonly property var connectedWifiNetwork: root.wifiNetworks.find(network => {
        return network.connected;
    }) ?? null
    readonly property var connectedWifiDevice: root.wifiDevices.find(device => {
        return device.connected;
    }) ?? null
    readonly property var connectedWiredDevice: root.wiredDevices.find(device => {
        return device.connected;
    }) ?? null
    readonly property var connectedWiredNetwork: {
        const device = root.connectedWiredDevice;
        if (device === null)
            return null;

        return device.network ?? null;
    }
    readonly property var activeNetwork: root.connectedWiredNetwork ?? root.connectedWifiNetwork
    readonly property string wifiIconName: {
        if (!root.wifiEnabled)
            return "signal_wifi_off";
        if (!root.wifiConnected) {
            if (root.scanning)
                return "wifi_find";
            return "signal_wifi_statusbar_not_connected";
        }
        if (root.limitedConnectivity || root.captivePortal)
            return "signal_wifi_bad";

        const strength = root.connectedWifiNetwork ? root.connectedWifiNetwork.signalStrength * 100 : 100;
        if (strength < 5)
            return "signal_wifi_0_bar";
        if (strength < 20)
            return "network_wifi_1_bar";
        if (strength < 40)
            return "network_wifi_2_bar";
        if (strength < 65)
            return "network_wifi_3_bar";
        if (strength < 80)
            return "network_wifi";
        return "signal_wifi_4_bar";
    }
    readonly property string wifiStatusText: {
        if (!root.available)
            return "Unavailable";
        if (!root.wifiEnabled)
            return "Off";
        if (root.wifiConnected && root.connectedWifiNetwork && root.connectedWifiNetwork.name.length > 0)
            return root.connectedWifiNetwork.name;
        if (root.wifiConnected)
            return "Connected";
        return "Not connected";
    }
    // Native Quickshell connection operation state
    property var pendingNetwork: null
    readonly property bool nativeConnectionBusy: root.pendingNetwork !== null && root.pendingNetwork.stateChanging
    // Unknown/hidden SSID operation state
    readonly property bool addWifiBusy: addWifiProcess.running
    property string pendingAddedSsid: ""
    property string pendingAddedPassword: ""
    property bool addWifiCancellationRequested: false
    property string lastError: ""
    /*
     * Password handling for nmcli
     *
     * The password is written through stdin after the shell starts.
     * It is not included in the process argument list or environment.
     */
    readonly property string addWifiScript: `
set -e

ssid=$1
ifname=$2
security=$3
hidden=$4
private_connection=$5
profile_name=$6

IFS= read -r password || password=""

uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || dbus-uuidgen 2>/dev/null || printf '00000000-0000-0000-0000-000000000000')
created=0

cleanup() {
    if [ "$created" -eq 1 ]; then
        nmcli --wait 5 connection delete uuid "$uuid" \
            >/dev/null 2>&1 || true
    fi
}

trap cleanup 0 1 2 15

set -- \
    nmcli \
    --colors no \
    --wait 20 \
    connection add \
    type wifi \
    con-name "$profile_name" \
    connection.uuid "$uuid" \
    connection.autoconnect yes \
    ifname "$ifname" \
    ssid "$ssid" \
    802-11-wireless.hidden "$hidden"

if [ "$private_connection" = "yes" ] \
        && [ -n "$USER" ]; then
    set -- "$@" \
        connection.permissions "user:$USER"
fi

"$@" >/dev/null
created=1

case "$security" in
    open)
        ;;

    owe)
        nmcli \
            --colors no \
            --wait 10 \
            connection modify \
            uuid "$uuid" \
            wifi-sec.key-mgmt owe
        ;;

    wpa-psk|sae)
        nmcli \
            --colors no \
            --wait 10 \
            connection modify \
            uuid "$uuid" \
            wifi-sec.key-mgmt "$security"
        ;;

    *)
        echo "Unsupported Wi-Fi security: $security" >&2
        exit 64
        ;;
esac

if [ "$security" = "wpa-psk" ] \
        || [ "$security" = "sae" ]; then
    printf '%s\n' "wifi-sec.psk:$password" |
        nmcli \
            --colors no \
            --wait 60 \
            connection up \
            uuid "$uuid" \
            ifname "$ifname" \
            passwd-file /dev/stdin \
            >/dev/null
else
    nmcli \
        --colors no \
        --wait 60 \
        connection up \
        uuid "$uuid" \
        ifname "$ifname" \
        >/dev/null
fi

created=0
trap - 0 1 2 15

printf '%s\n' "$uuid"
`

    signal credentialsRequired(var network)
    signal networkConnected(var network)
    signal networkConnectionFailed(var network, int reason, string message)
    signal wifiNetworkAdded(string ssid, string connectionUuid)
    signal wifiNetworkAddFailed(string ssid, string message)
    signal wifiNetworkAddCancelled(string ssid)
    signal operationFailed(string operation, string message)

    function selectWifiDevice(deviceOrName): bool {
        const name = typeof deviceOrName === "string" ? deviceOrName : (deviceOrName ? (deviceOrName.name ?? "") : "");
        if (name.length === 0)
            return false;

        const exists = root.wifiDevices.some(device => {
            return device.name === name;
        });
        if (!exists)
            return false;

        root.preferredWifiDeviceName = name;
        return true;
    }

    function clearPreferredWifiDevice() {
        root.preferredWifiDeviceName = "";
    }

    function setWifiEnabled(enabled: bool): bool {
        if (enabled && !root.wifiHardwareEnabled) {
            root.setError("wifi", "Wi-Fi is disabled by a hardware switch");
            return false;
        }
        Networking.wifiEnabled = enabled;
        return true;
    }

    function toggleWifi(): bool {
        return root.setWifiEnabled(!root.wifiEnabled);
    }

    /*
     * Keep scanning enabled while the network panel is open.
     *
     * Unlike a one-shot scan, scannerEnabled maintains an actively
     * populated network list.
     */
    function setScanning(enabled: bool): bool {
        const device = root.selectedWifiDevice;
        if (device === null)
            return false;

        if (enabled && !root.wifiEnabled)
            return false;

        device.scannerEnabled = enabled;
        return true;
    }

    function checkConnectivity(): bool {
        if (!Networking.canCheckConnectivity)
            return false;

        Networking.checkConnectivity();
        return true;
    }

    function setDeviceAutoconnect(device, enabled: bool): bool {
        if (device === null || device === undefined)
            return false;

        device.autoconnect = enabled;
        return true;
    }

    /*
     * Network controls
     */
    function connectNetwork(network): bool {
        if (!root.isValidNetwork(network))
            return false;

        if (network.connected)
            return true;

        root.lastError = "";
        root.pendingNetwork = network;
        /*
         * Call connect() first so NetworkManager can reuse an existing
         * profile and stored credentials. If a password is required,
         * credentialsRequired() will be emitted.
         */
        network.connect();
        return true;
    }

    function connectNetworkWithPsk(network, password: string): bool {
        if (!root.isValidNetwork(network))
            return false;

        if (!root.supportsPsk(network)) {
            root.setError("connect", "This network does not support PSK authentication");
            return false;
        }
        const validationError = root.validatePersonalPassword(network.security, password);
        if (validationError.length > 0) {
            root.setError("connect", validationError);
            return false;
        }
        root.lastError = "";
        root.pendingNetwork = network;
        network.connectWithPsk(password);
        return true;
    }

    function disconnectNetwork(network): bool {
        if (!root.isValidNetwork(network))
            return false;

        network.disconnect();
        if (root.pendingNetwork === network)
            root.pendingNetwork = null;

        return true;
    }

    function forgetNetwork(network): bool {
        if (!root.isValidNetwork(network))
            return false;

        network.forget();
        if (root.pendingNetwork === network)
            root.pendingNetwork = null;

        return true;
    }

    /*
     * This disconnects the complete network device and prevents it
     * from automatically activating another profile.
     */
    function disconnectDevice(device): bool {
        if (device === null || device === undefined)
            return false;

        device.disconnect();
        return true;
    }

    function isValidNetwork(network): bool {
        return network !== null && network !== undefined && typeof network === "object" && network.device !== null && network.device !== undefined;
    }

    function supportsPsk(network): bool {
        if (!root.isValidNetwork(network))
            return false;

        return network.security === WifiSecurityType.WpaPsk || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.Sae;
    }

    function requiresCredentials(network): bool {
        if (!root.isValidNetwork(network))
            return false;

        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function validatePersonalPassword(security: int, password: string): string {
        if (password.includes("\n") || password.includes("\r"))
            return "The password cannot contain a newline";

        if (security === WifiSecurityType.Sae)
            return password.length > 0 ? "" : "A password is required";

        if (security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk) {
            const validPassphrase = password.length >= 8 && password.length <= 63;
            const validRawKey = password.length === 64 && /^[0-9a-fA-F]{64}$/.test(password);
            if (!validPassphrase && !validRawKey)
                return "A WPA password must contain 8–63 characters or be a 64-digit hexadecimal key";
        }
        return "";
    }

    /*
     * Add and connect to an SSID not exposed by Quickshell
     *
     * options:
     * {
     *     interfaceName: "wlan0",   // defaults to selected adapter
     *     security: "wpa-psk",      // open, owe, wpa-psk, or sae
     *     hidden: true,              // defaults to true
     *     privateConnection: true,   // user-only profile
     *     profileName: "My Wi-Fi"   // defaults to SSID
     * }
     *
     * This creates a NetworkManager profile using a generated UUID.
     * If activation fails, the incomplete profile is deleted.
     */
    function addAndConnectWifi(ssid: string, password: string, options): bool {
        if (root.addWifiBusy) {
            root.setError("addWifi", "Another Wi-Fi profile is being added");
            return false;
        }
        if (!root.available) {
            root.setError("addWifi", "The networking backend is unavailable");
            return false;
        }
        if (Networking.backend !== NetworkBackendType.NetworkManager) {
            root.setError("addWifi", "Adding unknown networks requires NetworkManager");
            return false;
        }
        if (!root.wifiHardwareEnabled) {
            root.setError("addWifi", "Wi-Fi is disabled by a hardware switch");
            return false;
        }
        if (!root.wifiEnabled) {
            root.setError("addWifi", "Enable Wi-Fi before adding a network");
            return false;
        }
        const normalizedSsid = String(ssid);
        if (normalizedSsid.length === 0) {
            root.setError("addWifi", "The SSID cannot be empty");
            return false;
        }
        if (normalizedSsid.includes("\n") || normalizedSsid.includes("\r")) {
            root.setError("addWifi", "The SSID cannot contain a newline");
            return false;
        }
        const config = options ?? {};
        const interfaceName = String(config.interfaceName ?? (root.selectedWifiDevice ? (root.selectedWifiDevice.name ?? "") : ""));
        if (interfaceName.length === 0) {
            root.setError("addWifi", "No Wi-Fi adapter is available");
            return false;
        }
        const security = String(config.security ?? (password.length > 0 ? "wpa-psk" : "open")).trim().toLowerCase();
        const validSecurity = security === "open" || security === "owe" || security === "wpa-psk" || security === "sae";
        if (!validSecurity) {
            root.setError("addWifi", "Supported security values are open, owe, wpa-psk, and sae");
            return false;
        }
        if (security === "wpa-psk") {
            const validPassphrase = password.length >= 8 && password.length <= 63;
            const validRawKey = password.length === 64 && /^[0-9a-fA-F]{64}$/.test(password);
            if (!validPassphrase && !validRawKey) {
                root.setError("addWifi", "A WPA password must contain 8–63 characters or be a 64-digit hexadecimal key");
                return false;
            }
        }
        if (security === "sae" && password.length === 0) {
            root.setError("addWifi", "A password is required for WPA3-SAE");
            return false;
        }
        if (password.includes("\n") || password.includes("\r")) {
            root.setError("addWifi", "The password cannot contain a newline");
            return false;
        }
        const hidden = config.hidden ?? true;
        const privateConnection = config.privateConnection ?? true;
        const requestedProfileName = String(config.profileName ?? normalizedSsid);
        const profileName = requestedProfileName.length > 0 ? requestedProfileName : normalizedSsid;
        root.lastError = "";
        root.pendingAddedSsid = normalizedSsid;
        root.pendingAddedPassword = password;
        root.addWifiCancellationRequested = false;
        addWifiProcess.exec(["/bin/sh", "-c", root.addWifiScript, "NetworkService", normalizedSsid, interfaceName, security, hidden ? "yes" : "no", privateConnection ? "yes" : "no", profileName]);
        return true;
    }

    function cancelAddWifi(): bool {
        if (!addWifiProcess.running)
            return false;

        root.addWifiCancellationRequested = true;
        root.pendingAddedPassword = "";
        addWifiProcess.running = false;
        return true;
    }

    function setError(operation: string, message: string) {
        root.lastError = message;
        root.operationFailed(operation, message);
        console.warn("NetworkService [" + operation + "]:", message);
    }

    function handleNativeConnectionFailure(reason: int) {
        const network = root.pendingNetwork;
        if (network === null)
            return;

        root.pendingNetwork = null;
        if (reason === ConnectionFailReason.NoSecrets) {
            root.lastError = "";
            root.credentialsRequired(network);
            return;
        }
        const message = ConnectionFailReason.toString(reason);
        root.lastError = message;
        root.networkConnectionFailed(network, reason, message);
    }

    Connections {
        function onConnectionFailed(reason) {
            root.handleNativeConnectionFailure(reason);
        }

        function onConnectedChanged() {
            const network = root.pendingNetwork;
            if (network === null || !network.connected)
                return;

            root.pendingNetwork = null;
            root.lastError = "";
            root.networkConnected(network);
        }

        target: root.pendingNetwork
        ignoreUnknownSignals: true
    }

    Process {
        id: addWifiProcess

        stdinEnabled: true
        onStarted: {
            /*
             * Send exactly one line. The shell reads the line and then
             * continues, so closing stdin is not required.
             */
            addWifiProcess.write((root.pendingAddedPassword ?? "") + "\n");
            root.pendingAddedPassword = "";
        }
        onExited: (exitCode, exitStatus) => {
            const ssid = root.pendingAddedSsid;
            const cancelled = root.addWifiCancellationRequested;
            root.pendingAddedSsid = "";
            root.pendingAddedPassword = "";
            root.addWifiCancellationRequested = false;
            if (cancelled) {
                root.wifiNetworkAddCancelled(ssid);
                return;
            }
            if (exitCode === 0) {
                const uuid = String(addWifiOutput.text).trim();
                root.lastError = "";
                root.wifiNetworkAdded(ssid, uuid);
                if (Networking.canCheckConnectivity)
                    Networking.checkConnectivity();

                return;
            }
            const stderr = String(addWifiError.text).trim();
            const message = stderr.length > 0 ? stderr : "nmcli exited with code " + exitCode;
            root.lastError = message;
            root.wifiNetworkAddFailed(ssid, message);
            console.warn("NetworkService [addWifi]:", message, "status:", exitStatus);
        }

        stdout: StdioCollector {
            id: addWifiOutput
        }

        stderr: StdioCollector {
            id: addWifiError
        }
    }
}
