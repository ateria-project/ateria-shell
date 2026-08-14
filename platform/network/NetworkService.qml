pragma Singleton

import QtQuick
import Quickshell
import Ateria.Network

// Stable shell-facing facade. Native libnm objects stay behind WifiManager and
// its list model, so feature QML never owns or retains GObject pointers.
Singleton {
    id: root

    readonly property bool available: WifiManager.available
    readonly property bool hasWifiDevice: WifiManager.wifiDevices.length > 0
    readonly property bool wifiEnabled: WifiManager.wifiEnabled
    readonly property bool wifiHardwareEnabled: WifiManager.wifiHardwareEnabled
    readonly property bool scanning: WifiManager.scanning
    readonly property bool wifiConnected: WifiManager.wifiConnected
    readonly property bool wiredConnected: WifiManager.wiredConnected
    readonly property bool connected: WifiManager.connected
    readonly property int connectivity: WifiManager.connectivity
    readonly property bool hasInternet: WifiManager.hasInternet
    readonly property bool captivePortal: WifiManager.captivePortal
    readonly property bool limitedConnectivity: WifiManager.limitedConnectivity
    readonly property bool canCheckConnectivity: WifiManager.canCheckConnectivity
    readonly property string connectedSsid: WifiManager.connectedSsid
    readonly property int connectedStrength: WifiManager.connectedStrength
    readonly property string selectedWifiDevice: WifiManager.selectedDevice
    readonly property var wifiDevices: WifiManager.wifiDevices
    readonly property var wifiNetworks: WifiManager.networks
    readonly property int wifiNetworkCount: WifiManager.networks.count
    readonly property var savedWifiNetworks: WifiManager.savedNetworks
    readonly property int savedWifiNetworkCount: WifiManager.savedNetworks.count
    readonly property bool operationBusy: WifiManager.operationBusy
    readonly property string currentOperation: WifiManager.currentOperation
    readonly property string lastError: WifiManager.lastError

    readonly property int securityOpen: WifiManager.Open
    readonly property int securityWep: WifiManager.Wep
    readonly property int securityWpaPersonal: WifiManager.WpaPersonal
    readonly property int securityWpa3Personal: WifiManager.Wpa3Personal
    readonly property int securityOwe: WifiManager.Owe
    readonly property int securityEnterprise: WifiManager.Enterprise

    readonly property string wifiIconName: {
        if (!root.wifiEnabled)
            return "signal_wifi_off";
        if (!root.wifiConnected)
            return root.scanning ? "wifi_find" : "signal_wifi_statusbar_not_connected";
        if (root.limitedConnectivity || root.captivePortal)
            return "signal_wifi_bad";
        return root.signalIcon(root.connectedStrength);
    }

    readonly property string wifiStatusText: {
        if (!root.available)
            return "Unavailable";
        if (!root.hasWifiDevice)
            return "No adapter";
        if (!root.wifiHardwareEnabled)
            return "Hardware disabled";
        if (!root.wifiEnabled)
            return "Off";
        if (root.wifiConnected && root.connectedSsid.length > 0)
            return root.connectedSsid;
        if (root.wifiConnected)
            return "Connected";
        return "Not connected";
    }

    signal credentialsRequired(string networkId, string ssid, int security)
    signal networkConnected(string networkId, string ssid)
    signal networkDisconnected(string networkId)
    signal networkForgotten(string networkId)
    signal networkAutoconnectChanged(string networkId, bool enabled)
    signal operationFailed(string operation, string message)

    function initialize() {
        // Accessing WifiManager constructs the native singleton. Keeping this
        // method mirrors the lifecycle API used by the other platform services.
        return WifiManager.available;
    }

    function setWifiEnabled(enabled: bool): bool {
        return WifiManager.setWifiEnabled(enabled);
    }

    function toggleWifi(): bool {
        return root.setWifiEnabled(!root.wifiEnabled);
    }

    function selectWifiDevice(interfaceName: string): bool {
        return WifiManager.selectDevice(interfaceName);
    }

    function requestScan(): bool {
        return WifiManager.requestScan();
    }

    function setScanning(enabled: bool): bool {
        return enabled ? root.requestScan() : true;
    }

    function checkConnectivity(): bool {
        return WifiManager.checkConnectivity();
    }

    function connectNetwork(networkId: string): bool {
        return WifiManager.connectNetwork(networkId);
    }

    function connectNetworkWithPassword(networkId: string, password: string): bool {
        return WifiManager.connectNetworkWithPassword(networkId, password);
    }

    function disconnectNetwork(networkId: string): bool {
        return WifiManager.disconnectNetwork(networkId);
    }

    function forgetNetwork(networkId: string): bool {
        return WifiManager.forgetNetwork(networkId);
    }

    function setAutoconnect(networkId: string, enabled: bool): bool {
        return WifiManager.setAutoconnect(networkId, enabled);
    }

    function addAndConnectWifi(ssid: string, password: string, security: int, hidden: bool): bool {
        return WifiManager.addAndConnect(ssid, password, security, hidden);
    }

    function cancelOperation() {
        WifiManager.cancelOperation();
    }

    function validatePassword(security: int, password: string): string {
        return WifiManager.validatePassword(security, password);
    }

    function securityLabel(security: int): string {
        return WifiManager.securityLabel(security);
    }

    function requiresPassword(security: int): bool {
        return security === root.securityWep
            || security === root.securityWpaPersonal
            || security === root.securityWpa3Personal;
    }

    function signalIcon(strength: int): string {
        if (strength < 5)
            return "signal_wifi_0_bar";
        if (strength < 25)
            return "network_wifi_1_bar";
        if (strength < 50)
            return "network_wifi_2_bar";
        if (strength < 75)
            return "network_wifi_3_bar";
        return "signal_wifi_4_bar";
    }

    Connections {
        target: WifiManager

        function onCredentialsRequired(networkId: string, ssid: string, security: int) {
            root.credentialsRequired(networkId, ssid, security);
        }

        function onNetworkConnected(networkId: string, ssid: string) {
            root.networkConnected(networkId, ssid);
        }

        function onNetworkDisconnected(networkId: string) {
            root.networkDisconnected(networkId);
        }

        function onNetworkForgotten(networkId: string) {
            root.networkForgotten(networkId);
        }

        function onNetworkAutoconnectChanged(networkId: string, enabled: bool) {
            root.networkAutoconnectChanged(networkId, enabled);
        }

        function onOperationFailed(operation: string, message: string) {
            root.operationFailed(operation, message);
        }
    }
}
