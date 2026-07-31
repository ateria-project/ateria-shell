pragma Singleton
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    // Adapter state
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var adapters: Bluetooth.adapters.values
    readonly property var devices: Bluetooth.devices.values
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool blocked: root.available && root.adapter.state === BluetoothAdapterState.Blocked
    readonly property bool discovering: root.available && root.adapter.discovering
    readonly property bool discoverable: root.available && root.adapter.discoverable
    readonly property bool pairable: root.available && root.adapter.pairable
    readonly property string adapterName: root.available ? root.adapter.name : ""
    // Device collections
    readonly property var connectedDevices: root.devices.filter(device => {
        return device.connected;
    })
    readonly property var pairedDevices: root.devices.filter(device => {
        return device.paired;
    })
    readonly property var disconnectedDevices: root.devices.filter(device => {
        return !device.connected;
    })
    readonly property var unpairedDevices: root.devices.filter(device => {
        return !device.paired;
    })
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
            return root.hasConnectedDevice ? root.connectedCount + " connected" : "On";
        default:
            return "Off";
        }
    }

    // Adapter controls
    function setEnabled(enabled: bool): bool {
        if (!root.available || root.blocked)
            return false;

        root.adapter.enabled = enabled;
        return true;
    }

    function toggleEnabled(): bool {
        return root.setEnabled(!root.enabled);
    }

    function setDiscovering(discovering: bool): bool {
        if (!root.available || !root.enabled)
            return false;

        root.adapter.discovering = discovering;
        return true;
    }

    function toggleDiscovery(): bool {
        return root.setDiscovering(!root.discovering);
    }

    function setDiscoverable(discoverable: bool, timeout: int): bool {
        if (!root.available || !root.enabled)
            return false;

        root.adapter.discoverableTimeout = Math.max(0, timeout);
        root.adapter.discoverable = discoverable;
        return true;
    }

    function setPairable(pairable: bool, timeout: int): bool {
        if (!root.available || !root.enabled)
            return false;

        root.adapter.pairableTimeout = Math.max(0, timeout);
        root.adapter.pairable = pairable;
        return true;
    }

    // Device controls
    function connectDevice(device): bool {
        if (!root.isValidDevice(device) || !root.enabled || device.blocked)
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
        if (!root.isValidDevice(device) || !root.enabled || device.blocked || device.paired || device.pairing)
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

    function setWakeAllowed(device, allowed: bool): bool {
        if (!root.isValidDevice(device))
            return false;

        try {
            device.wakeAllowed = allowed;
            return true;
        } catch (error) {
            console.warn("BluetoothService: Could not set wake allowed:", String(error));
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

    function deviceStatus(device): string {
        if (!root.isValidDevice(device))
            return "Unavailable";

        if (device.pairing)
            return "Pairing";

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

    function deviceBatteryPercent(device): int {
        if (!root.isValidDevice(device) || !device.batteryAvailable)
            return -1;

        return Math.round(device.battery * 100);
    }
}
