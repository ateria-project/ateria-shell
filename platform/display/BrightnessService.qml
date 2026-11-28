pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    // Timers

    id: root

    // Configuration
    // Internal brightness is cheap to sample and can also change through
    // hardware keys outside this shell. DDC probing is much more expensive,
    // so keep it on a separate, slower safety interval.
    property int refreshInterval: 30000
    property int externalRefreshInterval: 300000
    property int displayChangeDebounce: 750
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
    // Brightness is only consumed by Quick Settings, so polling is suspended
    // while that panel is closed.
    property bool viewActive: false
    // Incremented on every user write. Reads record the epoch they were
    // started with; a read whose epoch is behind the latest write predates
    // the user's intent and must not overwrite the optimistic value, or the
    // slider jumps back to the old hardware brightness.
    property int writeEpoch: 0
    property int internalReadEpoch: 0
    property int externalQueryEpoch: 0
    property var pendingInternalWrite: null
    property var pendingExternalWrites: ({})
    property var externalQueryQueue: []
    property var externalWriteQueue: []
    property var currentExternalQuery: null
    property var currentExternalWrite: null
    property bool externalRefreshPending: false
    property bool componentReady: false
    readonly property string connectedScreenSignature: root.screenSignature()
    readonly property bool hasPotentialExternalScreen: root.detectPotentialExternalScreen()

    signal commandFailed(string backend, string message)

    // General helpers
    function isInternalScreenName(name: string): bool {
        const normalized = String(name ?? "").trim();
        return /^(edp|lvds|dsi)/i.test(normalized) || normalized.toLowerCase().includes("internal");
    }

    function screenSignature(): string {
        const identities = [];
        for (const screen of Quickshell.screens) {
            identities.push([
                String(screen?.name ?? ""),
                String(screen?.model ?? ""),
                String(screen?.serialNumber ?? screen?.serial ?? "")
            ].join("\u001f"));
        }
        identities.sort();
        return identities.join("\u001e");
    }

    function detectPotentialExternalScreen(): bool {
        for (const screen of Quickshell.screens) {
            if (!root.isInternalScreenName(screen?.name))
                return true;
        }
        return false;
    }

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

    function displayForScreen(screen) {
        if (!screen || !Array.isArray(root.displays) || root.displays.length === 0)
            return root.primaryDisplay;

        const screenName = String(screen.name ?? "").trim().toLowerCase();
        const isInternalScreen = root.isInternalScreenName(screenName);

        if (isInternalScreen && root.internalDisplays.length > 0)
            return root.internalDisplays[0];

        const screenModel = String(screen.model ?? "").trim().toLowerCase();
        const screenSerial = String(screen.serialNumber ?? screen.serial ?? "").trim().toLowerCase();

        if (screenSerial.length > 0) {
            const bySerial = root.externalDisplays.find(display => {
                const displaySerial = String(display.serial ?? "").trim().toLowerCase();
                return displaySerial.length > 0 && displaySerial === screenSerial;
            });
            if (bySerial !== undefined)
                return bySerial;
        }

        if (screenModel.length > 0) {
            const byModel = root.externalDisplays.find(display => {
                const displayModel = String(display.model ?? "").trim().toLowerCase();
                return displayModel.length > 0 && (displayModel === screenModel || screenModel.includes(displayModel) || displayModel.includes(screenModel));
            });
            if (byModel !== undefined)
                return byModel;
        }

        if (!isInternalScreen && root.externalDisplays.length > 0)
            return root.externalDisplays[0];

        return root.primaryDisplay;
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

    // View lifecycle
    function setViewActive(active, screen) {
        const nextActive = Boolean(active);
        if (root.viewActive === nextActive)
            return;

        root.viewActive = nextActive;
        if (!nextActive)
            return;

        root.refreshInternal();
        // Only probe DDC when the panel is actually showing an external
        // display. Laptops with an internal panel avoid the expensive probe.
        const display = root.displayForScreen(screen);
        if (display === null || display === undefined || display.type === "external")
            root.refreshExternal();
    }

    // Refreshing
    function refresh() {
        root.refreshInternal();
        root.refreshExternal();
    }

    function refreshInternal() {
        if (internalReadProcess.running || internalWriteProcess.running)
            return;

        root.internalReadEpoch = root.writeEpoch;
        internalReadProcess.exec(["brightnessctl", "--machine-readable", "--class", "backlight", "info"]);
    }

    function refreshExternal() {
        // DDC/I2C probing is unnecessary on machines that currently expose
        // only internal panels. A Quickshell screen-list change will schedule
        // detection as soon as an external output appears.
        if (!root.hasPotentialExternalScreen) {
            root.externalRefreshPending = false;
            root.externalQueryQueue = [];
            root.externalDisplays = [];
            return;
        }

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
        const detected = [];
        const previous = root.externalDisplays;
        const lines = String(data).split(/\r?\n/);
        let candidate = null;

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
                root.refreshExternal();
            }
            return;
        }
        const job = root.externalQueryQueue[0];
        root.externalQueryQueue = root.externalQueryQueue.slice(1);
        root.currentExternalQuery = job;
        root.externalQueryEpoch = root.writeEpoch;
        externalQueryProcess.exec(["ddcutil", "--display", String(job.display), "getvcp", "10", "--terse"]);
    }

    function finishExternalQuery(exitCode: int, standardOutput: string, standardError: string) {
        const job = root.currentExternalQuery;
        root.currentExternalQuery = null;
        if (job === null)
            return;

        // A query that started before the latest write (or while writes are
        // still pending) reports stale hardware brightness; keep the
        // optimistic value and let the post-write refresh reconcile.
        const stale = root.externalQueryEpoch !== root.writeEpoch
            || Object.keys(root.pendingExternalWrites).length > 0
            || root.externalWriteQueue.length > 0;

        if (!stale) {
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

    function brightnessForScreen(screen): real {
        const display = root.displayForScreen(screen);
        return display !== null ? display.brightness : 0;
    }

    function setScreenBrightness(screen, value: real): bool {
        const display = root.displayForScreen(screen);
        if (display === null)
            return false;

        return root.setBrightness(display.id, value);
    }

    function increaseScreenBrightness(screen): bool {
        const display = root.displayForScreen(screen);
        if (display === null)
            return false;

        return root.increaseBrightness(display.id);
    }

    function decreaseScreenBrightness(screen): bool {
        const display = root.displayForScreen(screen);
        if (display === null)
            return false;

        return root.decreaseBrightness(display.id);
    }

    // Internal writes
    function setInternalBrightness(display, value: real): bool {
        const brightness = Math.round(root.clamp(value, root.minimumInternalBrightness, 1) * 1000) / 1000;
        const rawValue = Math.round(brightness * display.maximum);
        root.writeEpoch += 1;
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
        root.writeEpoch += 1;
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

    Component.onCompleted: {
        root.componentReady = true;
        root.refresh();
    }
    onConnectedScreenSignatureChanged: {
        if (root.componentReady)
            displayChangeTimer.restart();
    }

    // Processes
    Process {
        id: internalReadProcess

        onExited: (exitCode, exitStatus) => {
            // A read that started before the latest write, or while one is
            // still pending, reports the old hardware brightness. Applying
            // it would snap the slider back to the previous value; the
            // post-write refresh re-reads the settled hardware state.
            const stale = root.internalReadEpoch !== root.writeEpoch
                || root.pendingInternalWrite !== null;

            if (exitCode === 0) {
                if (!stale)
                    root.parseInternalDisplays(internalReadOutput.text);
            } else {
                if (!stale)
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
        running: root.viewActive && root.refreshInterval > 0
        repeat: true
        onTriggered: root.refreshInternal()
    }

    Timer {
        interval: Math.max(1000, root.externalRefreshInterval)
        running: root.viewActive && root.externalRefreshInterval > 0 && root.hasPotentialExternalScreen
        repeat: true
        onTriggered: root.refreshExternal()
    }

    Timer {
        id: displayChangeTimer

        interval: Math.max(0, root.displayChangeDebounce)
        repeat: false
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
