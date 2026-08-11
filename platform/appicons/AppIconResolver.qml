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
    property var resolvedCandidates: ({})
    property var queuedRequests: ({})
    property var inFlightRequests: ({})
    property bool scanInProgress: false

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
        const iconKey = AppIconSearch.cacheKey(name);
        const key = AppIconSearch.cacheKey(name) + "@" + size;
        if (AppIconSearch.hasOwn(root.resolvedPaths, key))
            return root.resolvedPaths[key];

        // A scan returns every available size for a name. Reuse those
        // candidates instead of walking the icon directories again when the
        // launcher and taskbar request different sizes.
        if (AppIconSearch.hasOwn(root.resolvedCandidates, iconKey))
            return AppIconSearch.bestPath(root.resolvedCandidates[iconKey], root.searchRoots, size);

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
        if (root.scanInProgress || scanProcess.running)
            return;

        root.scanInProgress = true;

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
        const updatedCandidates = Object.assign({}, root.resolvedCandidates);
        for (const key of Object.keys(root.inFlightRequests)) {
            const request = root.inFlightRequests[key];
            const iconKey = AppIconSearch.cacheKey(request.name);
            const iconCandidates = candidates[iconKey] ?? [];
            updatedCandidates[iconKey] = iconCandidates;
            updatedPaths[key] = AppIconSearch.bestPath(iconCandidates, root.searchRoots, request.size);
        }

        // Requests for another size may arrive while the process is running.
        // Resolve those from the candidates returned by this scan instead of
        // launching an identical second directory walk.
        const remainingRequests = {};
        for (const key of Object.keys(root.queuedRequests)) {
            const request = root.queuedRequests[key];
            const iconKey = AppIconSearch.cacheKey(request.name);
            if (AppIconSearch.hasOwn(updatedCandidates, iconKey))
                updatedPaths[key] = AppIconSearch.bestPath(updatedCandidates[iconKey], root.searchRoots, request.size);
            else
                remainingRequests[key] = request;
        }

        root.inFlightRequests = {};
        root.queuedRequests = remainingRequests;
        root.resolvedCandidates = updatedCandidates;
        root.resolvedPaths = updatedPaths;
        root.scanInProgress = false;

        if (Object.keys(root.queuedRequests).length > 0)
            scanTimer.restart();
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
