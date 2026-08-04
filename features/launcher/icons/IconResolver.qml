pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "IconSearch.js" as IconSearch

Singleton {
    id: root

    readonly property int preferredSize: 80
    readonly property var searchRoots: IconSearch.searchRoots({
        "HOME": Quickshell.env("HOME"),
        "XDG_DATA_HOME": Quickshell.env("XDG_DATA_HOME"),
        "XDG_DATA_DIRS": Quickshell.env("XDG_DATA_DIRS")
    })

    property var resolvedPaths: ({})
    property var queuedNames: ({})
    property var inFlightNames: ({})

    function source(icon): string {
        const direct = IconSearch.directSource(icon);
        if (direct.length > 0)
            return direct;

        const name = IconSearch.normalizedName(icon);
        if (name.length === 0)
            return "";

        const themed = Quickshell.iconPath(name, true);
        if (themed.length > 0)
            return themed;

        const key = IconSearch.cacheKey(name);
        if (IconSearch.hasOwn(root.resolvedPaths, key))
            return root.resolvedPaths[key];

        root.enqueue(name, key);
        return "";
    }

    function enqueue(name, key) {
        if (key.length === 0
                || name.includes("/")
                || IconSearch.hasOwn(root.resolvedPaths, key)
                || IconSearch.hasOwn(root.queuedNames, key)
                || IconSearch.hasOwn(root.inFlightNames, key))
            return;

        root.queuedNames[key] = name;
        scanTimer.restart();
    }

    function startScan() {
        if (scanProcess.running)
            return;

        root.inFlightNames = root.queuedNames;
        root.queuedNames = {};

        const names = Object.keys(root.inFlightNames).map(key => root.inFlightNames[key]);
        const command = IconSearch.findCommand(names, root.searchRoots);
        if (command.length === 0) {
            root.finishScan("");
            return;
        }
        scanProcess.exec(command);
    }

    function finishScan(output) {
        const names = Object.keys(root.inFlightNames).map(key => root.inFlightNames[key]);
        const matches = IconSearch.selectPaths(output, names, root.searchRoots, root.preferredSize);
        const updatedPaths = Object.assign({}, root.resolvedPaths);
        for (const key of Object.keys(root.inFlightNames))
            updatedPaths[key] = IconSearch.hasOwn(matches, key) ? matches[key] : "";

        root.inFlightNames = {};
        root.resolvedPaths = updatedPaths;

        if (Object.keys(root.queuedNames).length > 0)
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
