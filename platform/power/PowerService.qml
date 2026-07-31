pragma Singleton
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // UPower's aggregate battery used by desktop environments.
    readonly property var battery: UPower.displayDevice
    readonly property var devices: UPower.devices.values
    readonly property bool ready: root.battery.ready
    readonly property bool hasBattery: root.ready && root.battery.isLaptopBattery && root.battery.isPresent
    readonly property bool onBattery: UPower.onBattery
    readonly property bool onExternalPower: !root.onBattery
    // Battery level is normalized from 0.0 to 1.0.
    readonly property real percentage: root.hasBattery ? root.battery.percentage : 0
    readonly property int percentageRounded: Math.round(root.percentage * 100)
    readonly property int state: root.hasBattery ? root.battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging || root.state === UPowerDeviceState.PendingCharge
    readonly property bool discharging: root.state === UPowerDeviceState.Discharging || root.state === UPowerDeviceState.PendingDischarge
    readonly property bool fullyCharged: root.state === UPowerDeviceState.FullyCharged
    readonly property bool empty: root.state === UPowerDeviceState.Empty
    readonly property bool low: root.hasBattery && root.percentage <= 0.2
    readonly property bool critical: root.hasBattery && root.percentage <= 0.1 && root.discharging
    readonly property real timeToEmpty: root.hasBattery ? root.battery.timeToEmpty : 0
    readonly property real timeToFull: root.hasBattery ? root.battery.timeToFull : 0
    readonly property real timeRemaining: root.charging ? root.timeToFull : root.discharging ? root.timeToEmpty : 0
    readonly property string timeRemainingText: root.formatDuration(root.timeRemaining)
    readonly property real energy: root.hasBattery ? root.battery.energy : 0
    readonly property real energyCapacity: root.hasBattery ? root.battery.energyCapacity : 0
    readonly property real changeRate: root.hasBattery ? root.battery.changeRate : 0
    readonly property bool healthAvailable: root.hasBattery && root.battery.healthSupported
    readonly property real health: root.healthAvailable ? root.battery.healthPercentage : 0
    readonly property int healthPercentage: Math.round(root.health * 100)
    readonly property string model: root.hasBattery ? root.battery.model : ""
    // Raw icon name supplied by UPower for system icon themes.
    readonly property string systemIconName: root.hasBattery ? root.battery.iconName : ""
    readonly property string stateText: {
        switch (root.state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.Empty:
            return "Empty";
        case UPowerDeviceState.PendingCharge:
            return "Waiting to charge";
        case UPowerDeviceState.PendingDischarge:
            return "Waiting to discharge";
        default:
            return "Unknown";
        }
    }
    /*
     * Physical laptop batteries. The aggregate displayDevice is not
     * included in UPower.devices.
     */
    readonly property var batteries: root.devices.filter(device => {
        return device.ready && device.type === UPowerDeviceType.Battery && device.isPresent;
    })
    /*
     * Other battery-powered devices reported by UPower, such as mice,
     * keyboards, headsets and controllers.
     */
    readonly property var peripheralDevices: root.devices.filter(device => {
        return device.ready && !device.isLaptopBattery && device.type !== UPowerDeviceType.LinePower && device.type !== UPowerDeviceType.Unknown;
    })
    // Power profiles
    readonly property int powerProfile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property var powerProfileHolds: PowerProfiles.holds
    readonly property int degradationReason: PowerProfiles.degradationReason
    readonly property string powerProfileName: {
        switch (root.powerProfile) {
        case PowerProfile.PowerSaver:
            return "Power saver";
        case PowerProfile.Performance:
            return "Performance";
        default:
            return "Balanced";
        }
    }

    function formatDuration(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0 || isNaN(seconds))
            return "";

        const totalMinutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours === 0)
            return minutes + "m";

        if (minutes === 0)
            return hours + "h";

        return hours + "h " + minutes + "m";
    }

    function devicePercentage(device): int {
        if (device === null || device === undefined || typeof device !== "object" || !device.ready)
            return 0;

        return Math.round(device.percentage * 100);
    }

    function deviceName(device): string {
        if (device === null || device === undefined || typeof device !== "object")
            return "";

        const modelName = String(device.model ?? "").trim();
        if (modelName.length > 0)
            return modelName;

        return UPowerDeviceType.toString(device.type);
    }

    function setPowerProfile(profile: int): bool {
        if (PowerProfiles === null || PowerProfiles === undefined)
            return false;

        if (profile === PowerProfile.Performance && !root.hasPerformanceProfile)
            return false;

        try {
            PowerProfiles.profile = profile;
            return true;
        } catch (error) {
            console.warn("PowerService: Could not set power profile:", String(error));
            return false;
        }
    }

    function usePowerSaver(): bool {
        return root.setPowerProfile(PowerProfile.PowerSaver);
    }

    function useBalanced(): bool {
        return root.setPowerProfile(PowerProfile.Balanced);
    }

    function usePerformance(): bool {
        return root.setPowerProfile(PowerProfile.Performance);
    }

    function cyclePowerProfile() {
        switch (root.powerProfile) {
        case PowerProfile.PowerSaver:
            root.useBalanced();
            break;
        case PowerProfile.Balanced:
            if (root.hasPerformanceProfile)
                root.usePerformance();
            else
                root.usePowerSaver();
            break;
        default:
            root.usePowerSaver();
            break;
        }
    }
}
