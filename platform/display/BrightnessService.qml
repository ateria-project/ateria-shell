pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    // Timers

    id: root

    // Configuration
    property int refreshInterval: 30000
    property int writeDebounce: 80
    property real brightnessStep: 0.05
    // Prevent accidentally turning a laptop panel completely black.
    property real minimumInternalBrightness: 0.01
    property real minimumExternalBrightness: 0
    // Public state
    property var internalDisplays: []
    property var externalDisplays: []
    readonly property var displays: root.internalDisplays.concat(root.externalDisplays)
    readonly property bool available: root.displays.length > 0
    readonly property bool hasInternalDisplay: root.internalDisplays.length > 0
    readonly property bool hasExternalDisplay: root.externalDisplays.length > 0
    readonly property var primaryDisplay: root.internalDisplays.length > 0 ? root.internalDisplays[0] : root.externalDisplays.length > 0 ? root.externalDisplays[0] : null
    readonly property real brightness: root.primaryDisplay !== null ? root.primaryDisplay.brightness : 0
    readonly property bool busy: internalReadProcess.running || internalWriteProcess.running || externalDetectProcess.running || externalQueryProcess.running || externalWriteProcess.running
    property string lastError: ""
    // Internal state
    property var pendingInternalWrite: null
    property var pendingExternalWrites: ({})
    property var externalQueryQueue: []
    property var externalWriteQueue: []
    property var currentExternalQuery: null
    property var currentExternalWrite: null
    property bool externalRefreshPending: false

    signal commandFailed(string backend, string message)

    // General helpers
    function clamp(value: real, minimum: real, maximum: real): real {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function displayById(displayId: string) {
        if (!Array.isArray(root.displays))
            return null;

        return root.displays.find(display => {
            return display.id === displayId;
        }) ?? null;
    }

    function readableName(name: string): string {
        const normalized = String(name ?? "").replace(/[_-]+/g, " ").trim();
        if (normalized.length === 0)
            return "Internal display";

        return normalized.replace(/\b\w/g, character => {
            return character.toUpperCase();
        });
    }

    function errorMessage(prefix: string, data): string {
        const detail = String(data ?? "").trim();
        return detail.length > 0 ? prefix + ": " + detail : prefix;
    }

    function reportError(backend: string, message: string) {
        root.lastError = message;
        root.commandFailed(backend, message);
        console.warn("BrightnessService [" + backend + "]:", message);
    }

    function patchDisplay(list, displayId: string, changes) {
        if (!Array.isArray(list) || displayId === undefined || displayId === null)
            return list;

        const index = list.findIndex(display => {
            return display.id === displayId;
        });
        if (index < 0)
            return list;

        const current = list[index];
        const keys = Object.keys(changes);
        let changed = false;
        for (const key of keys) {
            if (current[key] !== changes[key]) {
                changed = true;
                break;
            }
        }
        if (!changed)
            return list;

        const next = list.slice();
        next[index] = Object.assign({}, current, changes);
        return next;
    }

    function patchInternalDisplay(displayId: string, changes) {
        root.internalDisplays = root.patchDisplay(root.internalDisplays, displayId, changes);
    }

    function patchExternalDisplay(displayId: string, changes) {
        root.externalDisplays = root.patchDisplay(root.externalDisplays, displayId, changes);
    }

    // Refreshing
    function refresh() {
        root.refreshInternal();
        root.refreshExternal();
    }

    function refreshInternal() {
        if (internalReadProcess.running || internalWriteProcess.running)
            return;

        internalReadProcess.exec(["brightnessctl", "--machine-readable", "--class", "backlight", "info"]);
    }

    function refreshExternal() {
        if (externalDetectProcess.running || externalQueryProcess.running || externalWriteProcess.running || root.currentExternalQuery !== null || root.currentExternalWrite !== null || root.externalWriteQueue.length > 0) {
            root.externalRefreshPending = true;
            return;
        }
        root.externalRefreshPending = false;
        externalDetectProcess.exec(["ddcutil", "detect", "--brief"]);
    }

    // Internal display parsing
    function parseInternalDisplays(data: string) {
        const result = [];
        const lines = String(data).trim().split(/\r?\n/);
        for (const line of lines) {
            if (line.trim().length === 0)
                continue;

            // brightnessctl machine-readable format:
            // device,class,current,current%,maximum
            const fields = line.split(",");
            if (fields.length < 5)
                continue;

            const device = fields[0].trim();
            const deviceClass = fields[1].trim();
            const current = Number(fields[2]);
            const maximum = Number(fields[4]);
            if (device.length === 0 || !isFinite(current) || !isFinite(maximum) || maximum <= 0)
                continue;

            /*
             * ddcci-driver-linux may expose external monitors through
             * /sys/class/backlight. Exclude them to avoid showing the same
             * monitor through both brightnessctl and ddcutil.
             */
            if (device.toLowerCase().startsWith("ddcci"))
                continue;

            result.push({
                "id": "internal:" + device,
                "type": "internal",
                "backend": "brightnessctl",
                "name": root.readableName(device),
                "device": device,
                "deviceClass": deviceClass,
                "brightness": root.clamp(current / maximum, 0, 1),
                "current": current,
                "maximum": maximum,
                "available": true
            });
        }
        root.internalDisplays = result;
    }

    // External display detection
    function parseExternalDisplays(data: string) {
        function commitCandidate() {
            if (candidate === null)
                return;

            const monitorParts = candidate.monitor.split(":");
            const manufacturer = monitorParts.length > 0 ? monitorParts.shift().trim() : "";
            const serial = monitorParts.length > 1 ? monitorParts.pop().trim() : "";
            const model = monitorParts.join(":").trim();
            const identity = candidate.bus.length > 0 ? candidate.bus : manufacturer + ":" + model + ":" + serial + ":" + candidate.display;
            const displayId = "external:" + identity;
            const oldDisplay = previous.find(display => {
                return display.id === displayId;
            });
            detected.push({
                "id": displayId,
                "type": "external",
                "backend": "ddcutil",
                "name": model.length > 0 ? model : manufacturer.length > 0 ? manufacturer : "External display " + candidate.display,
                "display": candidate.display,
                "bus": candidate.bus,
                "manufacturer": manufacturer,
                "model": model,
                "serial": serial,
                "brightness": oldDisplay !== undefined ? oldDisplay.brightness : 0,
                "current": oldDisplay !== undefined ? oldDisplay.current : 0,
                "maximum": oldDisplay !== undefined ? oldDisplay.maximum : 100,
                "available": oldDisplay !== undefined ? oldDisplay.available : false
            });
            candidate = null;
        }

        const detected = [];
        const previous = root.externalDisplays;
        const lines = String(data).split(/\r?\n/);
        let candidate = null;
        for (const line of lines) {
            const displayMatch = line.match(/^\s*Display\s+(\d+)\s*$/);
            if (displayMatch !== null) {
                commitCandidate();
                candidate = {
                    "display": Number(displayMatch[1]),
                    "bus": "",
                    "monitor": ""
                };
                continue;
            }
            if (candidate === null)
                continue;

            const busMatch = line.match(/^\s*I2C bus:\s*(.*)$/);
            if (busMatch !== null) {
                candidate.bus = busMatch[1].trim();
                continue;
            }
            const monitorMatch = line.match(/^\s*Monitor:\s*(.*)$/);
            if (monitorMatch !== null)
                candidate.monitor = monitorMatch[1].trim();
        }
        commitCandidate();
        root.externalDisplays = detected;
        root.queueExternalQueries();
    }

    // External brightness queries
    function queueExternalQueries() {
        root.externalQueryQueue = root.externalDisplays.map(display => {
            return ({
                    "id": display.id,
                    "display": display.display
                });
        });
        root.runNextExternalQuery();
    }

    function runNextExternalQuery() {
        if (externalQueryProcess.running || root.currentExternalQuery !== null || externalWriteProcess.running || root.currentExternalWrite !== null || root.externalWriteQueue.length > 0)
            return;

        if (root.externalQueryQueue.length === 0) {
            if (root.externalRefreshPending) {
                root.externalRefreshPending = false;
                Qt.callLater(() => {
                    return root.refreshExternal();
                });
            }
            return;
        }
        const job = root.externalQueryQueue[0];
        root.externalQueryQueue = root.externalQueryQueue.slice(1);
        root.currentExternalQuery = job;
        externalQueryProcess.exec(["ddcutil", "--display", String(job.display), "getvcp", "10", "--terse"]);
    }

    function finishExternalQuery(exitCode: int, standardOutput: string, standardError: string) {
        const job = root.currentExternalQuery;
        root.currentExternalQuery = null;
        if (job === null)
            return;

        const valueMatch = String(standardOutput).match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
        if (exitCode === 0 && valueMatch !== null) {
            const current = Number(valueMatch[1]);
            const maximum = Number(valueMatch[2]);
            if (isFinite(current) && isFinite(maximum) && maximum > 0)
                root.patchExternalDisplay(job.id, {
                    "brightness": root.clamp(current / maximum, 0, 1),
                    "current": current,
                    "maximum": maximum,
                    "available": true
                });
        } else {
            root.patchExternalDisplay(job.id, {
                "available": false
            });
            const message = root.errorMessage("Could not query display " + job.display, standardError);
            root.reportError("ddcutil", message);
        }
        if (root.externalWriteQueue.length > 0)
            root.runNextExternalWrite();
        else
            root.runNextExternalQuery();
    }

    // Public brightness controls
    function setBrightness(displayId: string, value: real): bool {
        const display = root.displayById(displayId);
        if (display === null || !display.available)
            return false;

        if (display.type === "internal")
            return root.setInternalBrightness(display, value);

        if (display.type === "external")
            return root.setExternalBrightness(display, value);

        return false;
    }

    function changeBrightness(displayId: string, delta: real): bool {
        const display = root.displayById(displayId);
        if (display === null)
            return false;

        return root.setBrightness(displayId, display.brightness + delta);
    }

    function increaseBrightness(displayId: string): bool {
        return root.changeBrightness(displayId, root.brightnessStep);
    }

    function decreaseBrightness(displayId: string): bool {
        return root.changeBrightness(displayId, -root.brightnessStep);
    }

    function setPrimaryBrightness(value: real): bool {
        if (root.primaryDisplay === null)
            return false;

        return root.setBrightness(root.primaryDisplay.id, value);
    }

    function increasePrimaryBrightness(): bool {
        if (root.primaryDisplay === null)
            return false;

        return root.increaseBrightness(root.primaryDisplay.id);
    }

    function decreasePrimaryBrightness(): bool {
        if (root.primaryDisplay === null)
            return false;

        return root.decreaseBrightness(root.primaryDisplay.id);
    }

    function setAllBrightness(value: real) {
        for (const display of root.displays)
            root.setBrightness(display.id, value);
    }

    // Internal writes
    function setInternalBrightness(display, value: real): bool {
        const brightness = Math.round(root.clamp(value, root.minimumInternalBrightness, 1) * 1000) / 1000;
        const rawValue = Math.round(brightness * display.maximum);
        root.patchInternalDisplay(display.id, {
            "brightness": brightness,
            "current": rawValue
        });
        root.pendingInternalWrite = {
            "id": display.id,
            "device": display.device,
            "rawValue": rawValue
        };
        internalWriteTimer.restart();
        return true;
    }

    function flushInternalWrite() {
        if (root.pendingInternalWrite === null)
            return;

        if (internalReadProcess.running || internalWriteProcess.running) {
            internalWriteTimer.restart();
            return;
        }
        const job = root.pendingInternalWrite;
        root.pendingInternalWrite = null;
        internalWriteProcess.exec(["brightnessctl", "--quiet", "--device", job.device, "set", String(job.rawValue)]);
    }

    // External writes
    function setExternalBrightness(display, value: real): bool {
        const brightness = Math.round(root.clamp(value, root.minimumExternalBrightness, 1) * 1000) / 1000;
        const rawValue = Math.round(brightness * display.maximum);
        root.patchExternalDisplay(display.id, {
            "brightness": brightness,
            "current": rawValue
        });
        const pending = Object.assign({}, root.pendingExternalWrites);
        pending[display.id] = {
            "id": display.id,
            "display": display.display,
            "rawValue": rawValue
        };
        root.pendingExternalWrites = pending;
        // A write is more important than remaining stale reads.
        root.externalQueryQueue = [];
        externalWriteTimer.restart();
        return true;
    }

    function flushExternalWrites() {
        const pending = root.pendingExternalWrites;
        const displayIds = Object.keys(pending);
        if (displayIds.length === 0)
            return;

        const queuedIds = ({});
        for (const displayId of displayIds)
            queuedIds[displayId] = true;
        const queue = root.externalWriteQueue.filter(job => {
            return !queuedIds[job.id];
        });
        for (const displayId of displayIds)
            queue.push(pending[displayId]);
        root.pendingExternalWrites = ({});
        root.externalWriteQueue = queue;
        root.runNextExternalWrite();
    }

    function runNextExternalWrite() {
        if (externalWriteProcess.running || root.currentExternalWrite !== null || externalQueryProcess.running || root.currentExternalQuery !== null)
            return;

        if (root.externalWriteQueue.length === 0) {
            externalRefreshAfterWriteTimer.restart();
            return;
        }
        const job = root.externalWriteQueue[0];
        root.externalWriteQueue = root.externalWriteQueue.slice(1);
        root.currentExternalWrite = job;
        externalWriteProcess.exec(["ddcutil", "--display", String(job.display), "setvcp", "10", String(job.rawValue)]);
    }

    function finishExternalWrite(exitCode: int, standardError: string) {
        const job = root.currentExternalWrite;
        root.currentExternalWrite = null;
        if (job !== null && exitCode !== 0) {
            const message = root.errorMessage("Could not change display " + job.display, standardError);
            root.reportError("ddcutil", message);
        }
        root.runNextExternalWrite();
    }

    Component.onCompleted: root.refresh()

    // Processes
    Process {
        id: internalReadProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.parseInternalDisplays(internalReadOutput.text);
            } else {
                root.internalDisplays = [];
                const message = String(internalReadError.text).trim();
                if (message.length > 0)
                    root.reportError("brightnessctl", message);
            }
            if (root.pendingInternalWrite !== null)
                internalWriteTimer.restart();
        }

        stdout: StdioCollector {
            id: internalReadOutput
        }

        stderr: StdioCollector {
            id: internalReadError
        }
    }

    Process {
        id: internalWriteProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.reportError("brightnessctl", root.errorMessage("Could not change internal brightness", internalWriteError.text));

            if (root.pendingInternalWrite !== null)
                internalWriteTimer.restart();
            else
                root.refreshInternal();
        }

        stderr: StdioCollector {
            id: internalWriteError
        }
    }

    Process {
        id: externalDetectProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 || exitCode === 1) {
                root.parseExternalDisplays(exitCode === 0 ? externalDetectOutput.text : "");
            } else {
                root.externalDisplays = [];
                const message = String(externalDetectError.text).trim();
                if (message.length > 0)
                    root.reportError("ddcutil", message);
            }
        }

        stdout: StdioCollector {
            id: externalDetectOutput
        }

        stderr: StdioCollector {
            id: externalDetectError
        }
    }

    Process {
        id: externalQueryProcess

        onExited: (exitCode, exitStatus) => {
            root.finishExternalQuery(exitCode, externalQueryOutput.text, externalQueryError.text);
        }

        stdout: StdioCollector {
            id: externalQueryOutput
        }

        stderr: StdioCollector {
            id: externalQueryError
        }
    }

    Process {
        id: externalWriteProcess

        onExited: (exitCode, exitStatus) => {
            root.finishExternalWrite(exitCode, externalWriteError.text);
        }

        stderr: StdioCollector {
            id: externalWriteError
        }
    }

    Timer {
        interval: Math.max(1000, root.refreshInterval)
        running: root.refreshInterval > 0
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: internalWriteTimer

        interval: root.writeDebounce
        repeat: false
        onTriggered: root.flushInternalWrite()
    }

    Timer {
        id: externalWriteTimer

        interval: root.writeDebounce
        repeat: false
        onTriggered: root.flushExternalWrites()
    }

    Timer {
        id: externalRefreshAfterWriteTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (root.externalDisplays.length > 0)
                root.queueExternalQueries();
            else
                root.refreshExternal();
        }
    }
}
