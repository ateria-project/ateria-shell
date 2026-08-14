pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.platform.wallpaper
import "MatugenParser.js" as MatugenParser

Singleton {
    id: root

    readonly property string configPath: WallpaperCacheService.localPath(Quickshell.shellPath("matugen/config.toml"))
    readonly property string matugenPath: WallpaperCacheService.localPath(Quickshell.shellPath("tools/ateria-matugen"))
    property string requestedSource: ""
    property string requestedPath: ""
    property string inFlightPath: ""
    property string lastError: ""
    property bool waitingForThumbnail: false
    property string thumbnailWaitSource: ""
    readonly property bool busy: generateProcess.running

    signal generated(var lightScheme, var darkScheme, string sourcePath)
    signal generationFailed(string sourcePath, string message)

    function isVideoPath(path): bool {
        return WallpaperCacheService.isVideo(path);
    }

    function request(source) {
        const sourceUrl = String(source ?? "");
        const path = WallpaperCacheService.localPath(sourceUrl);
        if (path.length === 0 || (path === root.requestedPath
                && (generateProcess.running || requestTimer.running || root.waitingForThumbnail)))
            return;

        thumbnailWaitTimer.stop();
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        root.requestedSource = sourceUrl;
        root.requestedPath = path;
        requestTimer.restart();
    }

    function runMatugen(imagePath: string): void {
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        thumbnailWaitTimer.stop();
        root.inFlightPath = root.requestedPath;
        generateProcess.exec([
            root.matugenPath, "image", imagePath,
            "--config", root.configPath,
            "--source-color-index", "0",
            "--json", "hex", "--quiet"
        ]);
    }

    function failThumbnailWait(): void {
        const sourcePath = root.requestedPath;
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        thumbnailWaitTimer.stop();
        root.lastError = qsTr("Could not prepare a preview for this video wallpaper.");
        console.warn("MatugenService: " + root.lastError);
        root.generationFailed(sourcePath, root.lastError);
    }

    function resumeThumbnailWait(): void {
        if (!root.waitingForThumbnail || generateProcess.running
                || root.thumbnailWaitSource !== root.requestedSource)
            return;

        const entry = WallpaperCacheService.entryFor(root.requestedSource);
        const thumbnailSource = String(entry?.thumbnailSource ?? "");
        if (thumbnailSource.length > 0) {
            root.runMatugen(WallpaperCacheService.localPath(thumbnailSource));
            return;
        }
        if (entry !== null && entry.thumbnailStatus === "failed")
            root.failThumbnailWait();
    }

    function startGeneration() {
        if (generateProcess.running || root.requestedPath.length === 0)
            return;

        if (root.isVideoPath(root.requestedPath)) {
            root.waitingForThumbnail = true;
            root.thumbnailWaitSource = root.requestedSource;
            thumbnailWaitTimer.restart();
            WallpaperCacheService.expeditePendingWork();
            root.resumeThumbnailWait();
            return;
        }
        root.runMatugen(root.requestedPath);
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

    Timer {
        id: thumbnailWaitTimer

        interval: 8000
        repeat: false
        onTriggered: root.failThumbnailWait()
    }

    Connections {
        target: WallpaperCacheService

        function onRevisionChanged(): void {
            root.resumeThumbnailWait();
        }
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
