pragma Singleton

import QtQuick
import Quickshell
import Ateria.Wallpaper
import qs.platform.wallpaper
import "MatugenParser.js" as MatugenParser

Singleton {
    id: root

    readonly property string configPath: WallpaperCacheService.localPath(Quickshell.shellPath("matugen/config.toml"))
    readonly property string matugenPath: WallpaperCacheService.localPath(Quickshell.shellPath("tools/ateria-matugen"))
    property string requestedSource: ""
    property string requestedPath: ""
    property string inFlightPath: ""
    property string completedPath: ""
    property string lastError: ""
    property bool resultApplied: false
    property bool waitingForThumbnail: false
    property string thumbnailWaitSource: ""
    property bool waitingForImageCache: false
    property string imageCacheWaitSource: ""
    readonly property bool busy: MatugenRunner.running

    signal generated(var lightScheme, var darkScheme, string sourcePath)
    signal generationFailed(string sourcePath, string message)

    function isVideoPath(path): bool {
        return WallpaperCacheService.isVideo(path);
    }

    function request(source) {
        const sourceUrl = String(source ?? "");
        const path = WallpaperCacheService.localPath(sourceUrl);
        if (path.length === 0 || (path === root.requestedPath
                && (path === root.completedPath || MatugenRunner.running
                    || requestTimer.running || root.waitingForThumbnail
                    || root.waitingForImageCache)))
            return;

        thumbnailWaitTimer.stop();
        imageCacheWaitTimer.stop();
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        root.waitingForImageCache = false;
        root.imageCacheWaitSource = "";
        root.requestedSource = sourceUrl;
        root.requestedPath = path;
        requestTimer.restart();
    }

    function runMatugen(imagePath: string): void {
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        root.waitingForImageCache = false;
        root.imageCacheWaitSource = "";
        thumbnailWaitTimer.stop();
        imageCacheWaitTimer.stop();
        root.inFlightPath = root.requestedPath;
        root.resultApplied = false;
        if (!MatugenRunner.generate(root.matugenPath, imagePath,
                                    root.configPath, root.inFlightPath)) {
            root.inFlightPath = "";
            requestTimer.restart();
        }
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
        if (!root.waitingForThumbnail || MatugenRunner.running
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

    function resumeImageCacheWait(): void {
        if (!root.waitingForImageCache || MatugenRunner.running
                || root.imageCacheWaitSource !== root.requestedSource)
            return;

        const playbackSource = WallpaperCacheService.imagePlaybackSource(root.requestedSource);
        const playbackPath = WallpaperCacheService.localPath(playbackSource);
        if (playbackPath.length > 0)
            root.runMatugen(playbackPath);
    }

    function finishImageCacheWait(): void {
        if (!root.waitingForImageCache || MatugenRunner.running
                || root.imageCacheWaitSource !== root.requestedSource)
            return;

        // A first-time cache can take longer to encode than Matugen needs to
        // inspect the original. Fall back instead of adding visible latency.
        root.runMatugen(root.requestedPath);
    }

    function startGeneration() {
        if (MatugenRunner.running || root.requestedPath.length === 0)
            return;

        if (root.isVideoPath(root.requestedPath)) {
            root.waitingForThumbnail = true;
            root.thumbnailWaitSource = root.requestedSource;
            thumbnailWaitTimer.restart();
            WallpaperCacheService.expeditePendingWork();
            root.resumeThumbnailWait();
            return;
        }

        if (WallpaperCacheService.isImage(root.requestedSource)
                && WallpaperCacheService.isLocalFile(root.requestedSource)) {
            const playbackSource = WallpaperCacheService.imagePlaybackSource(root.requestedSource);
            const playbackPath = WallpaperCacheService.localPath(playbackSource);
            if (playbackPath.length > 0) {
                root.runMatugen(playbackPath);
            } else {
                root.waitingForImageCache = true;
                root.imageCacheWaitSource = root.requestedSource;
                imageCacheWaitTimer.restart();
            }
            return;
        }
        root.runMatugen(root.requestedPath);
    }

    function applyGeneratedOutput(sourcePath: string, output: string,
                                  reportError: bool): bool {
        if (sourcePath.length === 0 || sourcePath !== root.requestedPath)
            return false;

        const result = MatugenParser.parse(output);
        if (result.valid) {
            root.lastError = "";
            root.completedPath = sourcePath;
            root.resultApplied = true;
            root.generated(result.light, result.dark, sourcePath);
            return true;
        }

        if (reportError) {
            root.lastError = result.error;
            console.warn("MatugenService: " + root.lastError);
            root.generationFailed(sourcePath, root.lastError);
        }
        return false;
    }

    function finishGeneration(sourcePath: string, exitCode: int,
                              output: string, error: string): void {
        root.inFlightPath = "";

        if (sourcePath === root.requestedPath) {
            if (exitCode !== 0) {
                const detail = error.trim();
                root.lastError = detail.length > 0 ? detail : "Matugen exited with code " + exitCode;
                console.warn("MatugenService: " + root.lastError);
                root.generationFailed(sourcePath, root.lastError);
            } else if (!root.resultApplied)
                root.applyGeneratedOutput(sourcePath, output, true);
        }

        if (root.requestedPath !== sourcePath)
            requestTimer.restart();
    }

    Timer {
        id: requestTimer

        // Coalesce transient startup/source changes without imposing a visible
        // delay on the selected wallpaper.
        interval: 25
        repeat: false
        onTriggered: root.startGeneration()
    }

    Timer {
        id: thumbnailWaitTimer

        interval: 8000
        repeat: false
        onTriggered: root.failThumbnailWait()
    }

    Timer {
        id: imageCacheWaitTimer

        // Existing cache hits normally resolve after the native service's
        // 50 ms debounce. A miss falls back to the original at the same point
        // where the previous Matugen debounce would have started extraction.
        interval: 75
        repeat: false
        onTriggered: root.finishImageCacheWait()
    }

    Connections {
        target: WallpaperCacheService

        function onRevisionChanged(): void {
            root.resumeThumbnailWait();
            root.resumeImageCacheWait();
        }
    }

    Connections {
        target: MatugenRunner

        function onOutputAvailable(requestId: string, output: string): void {
            if (!root.resultApplied && requestId === root.inFlightPath)
                root.applyGeneratedOutput(requestId, output, false);
        }

        function onFinished(requestId: string, exitCode: int,
                            output: string, error: string): void {
            root.finishGeneration(requestId, exitCode, output, error);
        }
    }
}
