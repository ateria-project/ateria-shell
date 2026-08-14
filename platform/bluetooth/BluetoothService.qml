pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Ateria.Bluetooth

Singleton {
    id: root

    property bool initialized: false
    property int incomingPairingRetryCount: 0
    readonly property bool agentReady: BluetoothAgent.ready
    readonly property var pairingRequest: {
        if (!BluetoothAgent.hasRequest)
            return null;

        const request = BluetoothAgent.request;
        const path = String(request.path ?? "");
        for (const device of root.devices) {
            if (String(device.dbusPath ?? "") !== path)
                continue;
            return Object.assign({}, request, {
                "name": root.deviceName(device),
                "address": String(device.address ?? "")
            });
        }
        return request;
    }
    readonly property string agentError: BluetoothAgent.lastError

    readonly property bool hasPairingRequest: root.pairingRequest !== null

    // Adapter state
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices.values.filter(device => {
        return root.adapter !== null && device.adapter === root.adapter;
    })
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool operational: root.available && root.adapter.state === BluetoothAdapterState.Enabled
    readonly property bool blocked: root.available && root.adapter.state === BluetoothAdapterState.Blocked
    readonly property bool enabling: root.available && root.adapter.state === BluetoothAdapterState.Enabling
    readonly property bool disabling: root.available && root.adapter.state === BluetoothAdapterState.Disabling
    readonly property bool discovering: root.available && root.adapter.discovering
    readonly property bool discoverable: root.available && root.adapter.discoverable
    readonly property bool pairable: root.available && root.adapter.pairable
    // Device collections
    readonly property var connectedDevices: root.devices.filter(device => {
        return device.connected;
    }).sort(root.compareDevices)
    readonly property var pairedDevices: root.devices.filter(device => {
        return device.paired;
    }).sort(root.compareDevices)
    readonly property var unpairedDevices: root.devices.filter(device => {
        return !device.paired && !device.blocked;
    }).sort(root.compareDevices)
    readonly property int connectedCount: root.connectedDevices.length
    readonly property bool hasConnectedDevice: root.connectedCount > 0
    readonly property string statusText: {
        if (!root.available)
            return "Unavailable";

        switch (root.adapter.state) {
        case BluetoothAdapterState.Blocked:
            return "Blocked";
        case BluetoothAdapterState.Enabling:
            return "Turning on";
        case BluetoothAdapterState.Disabling:
            return "Turning off";
        case BluetoothAdapterState.Enabled:
            if (root.connectedCount === 1 && root.connectedDevices.length > 0)
                return root.deviceName(root.connectedDevices[0]);
            return root.hasConnectedDevice ? root.connectedCount + " connected" : "On";
        default:
            return "Off";
        }
    }
    readonly property string iconName: {
        if (!root.enabled)
            return "bluetooth_disabled";
        if (root.hasConnectedDevice)
            return "bluetooth_connected";
        return "bluetooth";
    }

    function initialize() {
        if (root.initialized)
            return;

        root.initialized = true;
        BluetoothAgent.initialize();
        incomingPairingEnsureTimer.restart();
    }

    function ensureIncomingPairingEnabled() {
        if (!root.initialized || !root.operational)
            return;

        if (!root.pairable)
            root.setPairable(true, 0);
        if (!root.discoverable)
            root.setDiscoverable(true, 0);
        incomingPairingVerificationTimer.restart();
    }

    onOperationalChanged: {
        if (root.operational)
            incomingPairingEnsureTimer.restart();
        else {
            incomingPairingEnsureTimer.stop();
            incomingPairingVerificationTimer.stop();
            root.incomingPairingRetryCount = 0;
        }
    }
    onDiscoverableChanged: incomingPairingEnsureTimer.restart()
    onPairableChanged: incomingPairingEnsureTimer.restart()

    function respondToPairing(accepted: bool, value: string): bool {
        if (!root.pairingRequest || root.pairingRequest.event !== "request" || !root.agentReady)
            return false;

        return BluetoothAgent.respond(accepted, value);
    }

    function acceptPairing(value: string): bool {
        return root.respondToPairing(true, value);
    }

    function rejectPairing(): bool {
        return root.respondToPairing(false, "");
    }

    function dismissPairingDisplay() {
        if (root.pairingRequest && root.pairingRequest.event === "display")
            BluetoothAgent.dismissDisplay();
    }

    function pairingRequestDevice() {
        if (!root.pairingRequest)
            return null;

        const path = String(root.pairingRequest.path ?? "");
        for (const device of root.devices) {
            if (String(device.dbusPath ?? "") === path)
                return device;
        }
        return null;
    }

    function cancelActivePairing(): bool {
        const device = root.pairingRequestDevice();
        if (device && device.pairing)
            return root.cancelPairing(device);
        return root.rejectPairing();
    }

    // Adapter controls
    function setEnabled(enabled: bool): bool {
        if (!root.available || root.blocked)
            return false;

        try {
            root.adapter.enabled = enabled;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not change adapter power:", String(error));
            return false;
        }
    }

    function setDiscovering(discovering: bool): bool {
        if (!root.operational)
            return false;

        try {
            root.adapter.discovering = discovering;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not change discovery state:", String(error));
            return false;
        }
    }

    function setDiscoverable(discoverable: bool, timeout: int): bool {
        if (!root.operational)
            return false;

        try {
            root.adapter.discoverableTimeout = Math.max(0, timeout);
            root.adapter.discoverable = discoverable;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not change discoverable state:", String(error));
            return false;
        }
    }

    function setPairable(pairable: bool, timeout: int): bool {
        if (!root.operational)
            return false;

        try {
            root.adapter.pairableTimeout = Math.max(0, timeout);
            root.adapter.pairable = pairable;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not change pairable state:", String(error));
            return false;
        }
    }

    // Device controls
    function connectDevice(device): bool {
        if (!root.isValidDevice(device) || !root.operational || device.blocked)
            return false;

        try {
            device.connect();
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not connect device:", String(error));
            return false;
        }
    }

    function disconnectDevice(device): bool {
        if (!root.isValidDevice(device))
            return false;

        try {
            device.disconnect();
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not disconnect device:", String(error));
            return false;
        }
    }

    function toggleDeviceConnection(device): bool {
        if (!root.isValidDevice(device))
            return false;

        if (device.connected || device.state === BluetoothDeviceState.Connecting)
            return root.disconnectDevice(device);

        return root.connectDevice(device);
    }

    function pairDevice(device): bool {
        if (!root.isValidDevice(device) || !root.operational || !root.agentReady || device.blocked || device.paired || device.pairing)
            return false;

        try {
            device.pair();
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not pair device:", String(error));
            return false;
        }
    }

    function cancelPairing(device): bool {
        if (!root.isValidDevice(device) || !device.pairing)
            return false;

        try {
            device.cancelPair();
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not cancel pairing:", String(error));
            return false;
        }
    }

    function forgetDevice(device): bool {
        if (!root.isValidDevice(device) || !device.paired)
            return false;

        try {
            device.forget();
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not forget device:", String(error));
            return false;
        }
    }

    function setDeviceTrusted(device, trusted: bool): bool {
        if (!root.isValidDevice(device))
            return false;

        try {
            device.trusted = trusted;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not set trusted:", String(error));
            return false;
        }
    }

    function setDeviceName(device, name: string): bool {
        if (!root.isValidDevice(device))
            return false;

        const normalizedName = name.trim();
        if (normalizedName.length === 0)
            return false;

        try {
            device.name = normalizedName;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not rename device:", String(error));
            return false;
        }
    }

    function setDeviceBlocked(device, blocked: bool): bool {
        if (!root.isValidDevice(device))
            return false;

        try {
            device.blocked = blocked;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not set blocked:", String(error));
            return false;
        }
    }

    function isValidDevice(device): bool {
        return device !== null && device !== undefined && typeof device === "object";
    }

    // Device presentation helpers
    function deviceName(device): string {
        if (!root.isValidDevice(device))
            return "Unknown device";

        const name = String(device.name ?? "").trim();
        if (name.length > 0)
            return name;

        const address = String(device.address ?? "").trim();
        return address.length > 0 ? address : "Unknown device";
    }

    function compareDevices(left, right): int {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;
        return root.deviceName(left).localeCompare(root.deviceName(right));
    }

    function deviceIconName(device): string {
        if (!root.isValidDevice(device))
            return "bluetooth";

        const icon = String(device.icon ?? "").toLowerCase();
        if (icon.includes("headset"))
            return "headset";
        if (icon.includes("headphone") || icon.includes("audio"))
            return "headphones";
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("mouse") || icon.includes("pointing"))
            return "mouse";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("tablet"))
            return "tablet";
        if (icon.includes("computer") || icon.includes("laptop"))
            return "computer";
        if (icon.includes("game") || icon.includes("input"))
            return "sports_esports";
        return "bluetooth";
    }

    function deviceStatus(device): string {
        if (!root.isValidDevice(device))
            return "Unavailable";

        if (device.pairing)
            return "Pairing";

        if (device.blocked)
            return "Blocked";

        switch (device.state) {
        case BluetoothDeviceState.Connected:
            return "Connected";
        case BluetoothDeviceState.Connecting:
            return "Connecting";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting";
        default:
            return device.paired ? "Paired" : "Not paired";
        }
    }

    function deviceBusy(device): bool {
        if (!root.isValidDevice(device))
            return false;

        return device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting;
    }

    function deviceDescription(device): string {
        const status = root.deviceStatus(device);
        const battery = root.deviceBatteryPercent(device);
        return battery >= 0 ? status + " · " + battery + "%" : status;
    }

    function deviceBatteryPercent(device): int {
        if (!root.isValidDevice(device) || !device.batteryAvailable)
            return -1;

        return Math.round(device.battery * 100);
    }

    function serviceName(uuid: string): string {
        const normalized = uuid.toLowerCase();
        const names = {
            "0000110a-0000-1000-8000-00805f9b34fb": "audio source",
            "0000110b-0000-1000-8000-00805f9b34fb": "audio playback",
            "0000110c-0000-1000-8000-00805f9b34fb": "media controls",
            "00001124-0000-1000-8000-00805f9b34fb": "input controls",
            "0000112f-0000-1000-8000-00805f9b34fb": "phone book access",
            "00001132-0000-1000-8000-00805f9b34fb": "message access"
        };
        return names[normalized] ?? "a Bluetooth service";
    }

    Timer {
        id: incomingPairingEnsureTimer

        interval: 0
        onTriggered: root.ensureIncomingPairingEnabled()
    }

    Timer {
        id: incomingPairingVerificationTimer

        interval: 750
        onTriggered: {
            if (!root.operational)
                return;
            if (root.discoverable && root.pairable) {
                root.incomingPairingRetryCount = 0;
                return;
            }
            if (root.incomingPairingRetryCount < 2) {
                root.incomingPairingRetryCount++;
                root.ensureIncomingPairingEnabled();
                return;
            }

            root.incomingPairingRetryCount = 0;
            console.warn("BluetoothService: Could not keep the adapter discoverable and pairable");
        }
    }

}
