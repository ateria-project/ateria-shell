pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "MatugenParser.js" as MatugenParser

Singleton {
    id: root

    property string requestedPath: ""
    property string inFlightPath: ""
    property string lastError: ""
    readonly property bool busy: generateProcess.running

    signal generated(var lightScheme, var darkScheme, string sourcePath)
    signal generationFailed(string sourcePath, string message)

    function localPath(source): string {
        const value = String(source ?? "");
        if (!value.startsWith("file:"))
            return value;

        return decodeURIComponent(value.replace(/^file:\/\//, ""));
    }

    function request(source) {
        const path = root.localPath(source);
        if (path.length === 0 || (path === root.requestedPath && (generateProcess.running || requestTimer.running)))
            return;

        root.requestedPath = path;
        requestTimer.restart();
    }

    function startGeneration() {
        if (generateProcess.running || root.requestedPath.length === 0)
            return;

        root.inFlightPath = root.requestedPath;
        generateProcess.exec([
            "matugen",
            "image",
            root.inFlightPath,
            "--source-color-index",
            "0",
            "--json",
            "hex",
            "--quiet"
        ]);
    }

    function finishGeneration(exitCode) {
        const sourcePath = root.inFlightPath;
        root.inFlightPath = "";

        if (sourcePath === root.requestedPath) {
            if (exitCode !== 0) {
                const detail = errorOutput.text.trim();
                root.lastError = detail.length > 0 ? detail : "Matugen exited with code " + exitCode;
                console.warn("MatugenService: " + root.lastError);
                root.generationFailed(sourcePath, root.lastError);
            } else {
                const result = MatugenParser.parse(standardOutput.text);
                if (result.valid) {
                    root.lastError = "";
                    root.generated(result.light, result.dark, sourcePath);
                } else {
                    root.lastError = result.error;
                    console.warn("MatugenService: " + root.lastError);
                    root.generationFailed(sourcePath, root.lastError);
                }
            }
        }

        if (root.requestedPath !== sourcePath)
            requestTimer.restart();
    }

    Timer {
        id: requestTimer

        interval: 100
        repeat: false
        onTriggered: root.startGeneration()
    }

    Process {
        id: generateProcess

        stdout: StdioCollector {
            id: standardOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: errorOutput
            waitForEnd: true
        }
        onExited: exitCode => root.finishGeneration(exitCode)
    }
}
