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

    function isVideoPath(path): bool {
        return /\.(mp4|webm|mkv|gif)$/i.test(path);
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
        if (root.isVideoPath(root.inFlightPath)) {
            generateProcess.exec([
                "bash",
                "-c",
                "n=\"$(basename \"$1\")\"; t=\"/tmp/ateria_thumbs/$n.jpg\"; if [ ! -f \"$t\" ]; then mkdir -p /tmp/ateria_thumbs && nice -n 19 ffmpeg -loglevel error -y -threads 1 -i \"$1\" -map 0:v:0 -frames:v 1 -vf 'scale=640:-2' -q:v 4 \"$t\" </dev/null; fi; matugen image \"$t\" --source-color-index 0 --json hex --quiet",
                "_",
                root.inFlightPath
            ]);
            return;
        }

        generateProcess.exec([
            "matugen", "image", root.inFlightPath,
            "--source-color-index", "0", "--json", "hex", "--quiet"
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

        // Video startup and the full-screen transition are latency-sensitive.
        // Theme extraction can wait until that work has completed.
        interval: root.isVideoPath(root.requestedPath) ? 2000 : 100
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
