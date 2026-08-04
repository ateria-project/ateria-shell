pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "AppIconSearch.js" as AppIconSearch

Singleton {
    id: root

    readonly property int defaultSize: 64
    readonly property var searchRoots: AppIconSearch.searchRoots({
        "HOME": Quickshell.env("HOME"),
        "XDG_DATA_HOME": Quickshell.env("XDG_DATA_HOME"),
        "XDG_DATA_DIRS": Quickshell.env("XDG_DATA_DIRS")
    })

    property var resolvedPaths: ({})
    property var queuedRequests: ({})
    property var inFlightRequests: ({})

    function source(icon, requestedSize): string {
        const direct = AppIconSearch.directSource(icon);
        if (direct.length > 0)
            return direct;

        const name = AppIconSearch.normalizedName(icon);
        if (name.length === 0)
            return "";

        const themed = Quickshell.iconPath(name, true);
        if (themed.length > 0)
            return themed;

        const size = Math.max(1, Math.round(Number(requestedSize) || root.defaultSize));
        const key = AppIconSearch.cacheKey(name) + "@" + size;
        if (AppIconSearch.hasOwn(root.resolvedPaths, key))
            return root.resolvedPaths[key];

        root.enqueue(name, size, key);
        return "";
    }

    function enqueue(name, size, key) {
        if (key.length === 0
                || name.includes("/")
                || AppIconSearch.hasOwn(root.resolvedPaths, key)
                || AppIconSearch.hasOwn(root.queuedRequests, key)
                || AppIconSearch.hasOwn(root.inFlightRequests, key))
            return;

        root.queuedRequests[key] = {
            "name": name,
            "size": size
        };
        scanTimer.restart();
    }

    function startScan() {
        if (scanProcess.running)
            return;

        root.inFlightRequests = root.queuedRequests;
        root.queuedRequests = {};

        const names = Object.keys(root.inFlightRequests).map(key => root.inFlightRequests[key].name);
        const command = AppIconSearch.findCommand(names, root.searchRoots);
        if (command.length === 0) {
            root.finishScan("");
            return;
        }
        scanProcess.exec(command);
    }

    function finishScan(output) {
        const requests = Object.keys(root.inFlightRequests).map(key => root.inFlightRequests[key]);
        const candidates = AppIconSearch.candidatePaths(output, requests.map(request => request.name));
        const updatedPaths = Object.assign({}, root.resolvedPaths);
        for (const key of Object.keys(root.inFlightRequests)) {
            const request = root.inFlightRequests[key];
            const iconKey = AppIconSearch.cacheKey(request.name);
            updatedPaths[key] = AppIconSearch.bestPath(candidates[iconKey], root.searchRoots, request.size);
        }

        root.inFlightRequests = {};
        root.resolvedPaths = updatedPaths;

        if (Object.keys(root.queuedRequests).length > 0)
            scanTimer.restart();
    }

    function clearMissingPaths() {
        const existingPaths = {};
        for (const key of Object.keys(root.resolvedPaths)) {
            if (root.resolvedPaths[key].length > 0)
                existingPaths[key] = root.resolvedPaths[key];
        }
        root.resolvedPaths = existingPaths;
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            // Retry misses when application metadata changes; new icons may have been installed too.
            root.clearMissingPaths();
        }
    }

    Timer {
        id: scanTimer

        interval: 25
        onTriggered: root.startScan()
    }

    Process {
        id: scanProcess

        stdout: StdioCollector {
            id: scanOutput
            waitForEnd: true
        }
        // Some standard roots are optional. Consume find's diagnostics for roots that do not exist.
        stderr: StdioCollector {
            waitForEnd: true
        }
        onExited: root.finishScan(scanOutput.text)
    }
}
