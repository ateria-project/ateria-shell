pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Ateria.Wallpaper
import qs.platform.wallpaper
import "MatugenParser.js" as MatugenParser

Singleton {
    id: root

    readonly property int paletteVersion: 1
    readonly property int paletteEntryLimit: 8
    readonly property string stateDirectory: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/ateria"
    readonly property string paletteFile: root.stateDirectory + "/theme-palette.json"
    readonly property string configPath: WallpaperCacheService.localPath(Quickshell.shellPath("matugen/config.toml"))
    readonly property string matugenPath: WallpaperCacheService.localPath(Quickshell.shellPath("tools/ateria-matugen"))
    readonly property string matugenRoot: WallpaperCacheService.localPath(Quickshell.shellPath("matugen"))
    // Covers the source image and every input that can change the generated
    // scheme. Template edits invalidate the cache so installed color files are
    // never left on an older template.
    readonly property string fingerprintScript: "stat -c '%n|%s|%y' -- \"$1\" \"$2/config.toml\" \"$2\"/templates/* \"$3\""
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
    property bool paletteLoaded: false
    property var paletteEntries: []
    property var pendingPaletteEntry: null
    property var paletteSaveQueue: []
    property var inFlightPaletteSave: null
    property bool paletteDirectoryReady: false
    property bool paletteDirectoryInProgress: false
    property bool paletteSaveInProgress: false
    property string pendingPaletteText: ""
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
                    || requestTimer.running || root.pendingPaletteEntry !== null
                    || root.waitingForThumbnail || root.waitingForImageCache)))
            return;

        thumbnailWaitTimer.stop();
        imageCacheWaitTimer.stop();
        if (restoreFingerprintProcess.running)
            restoreFingerprintProcess.signal(9);
        root.pendingPaletteEntry = null;
        root.waitingForThumbnail = false;
        root.thumbnailWaitSource = "";
        root.waitingForImageCache = false;
        root.imageCacheWaitSource = "";
        root.requestedSource = sourceUrl;
        root.requestedPath = path;

        // A stored palette only needs a metadata check, not the generation
        // debounce. Apply it immediately so startup does not show the fallback
        // colors while waiting for a timer.
        if (root.paletteLoaded && root.paletteEntryFor(path) !== null) {
            root.startGeneration();
            return;
        }
        requestTimer.restart();
    }

    function fingerprintArguments(sourcePath: string): var {
        return ["sh", "-c", root.fingerprintScript, "ateria-theme-fingerprint",
                sourcePath, root.matugenRoot, root.matugenPath];
    }

    function paletteEntryFor(sourcePath: string): var {
        for (let index = 0; index < root.paletteEntries.length; ++index) {
            const entry = root.paletteEntries[index];
            if (entry !== null && entry.source === sourcePath)
                return entry;
        }
        return null;
    }

    function restorePalette(): bool {
        if (!root.paletteLoaded || root.matugenRoot.length === 0)
            return false;
        // A previous source change may still be terminating its metadata
        // probe. Retry on the normal debounce instead of overlapping commands.
        if (restoreFingerprintProcess.running) {
            requestTimer.restart();
            return true;
        }

        const entry = root.paletteEntryFor(root.requestedPath);
        if (entry === null)
            return false;

        root.pendingPaletteEntry = entry;
        requestTimer.stop();
        restoreFingerprintProcess.exec(root.fingerprintArguments(root.requestedPath));
        return true;
    }

    function applyCachedPalette(entry): bool {
        if (entry === null || entry.source !== root.requestedPath)
            return false;

        root.inFlightPath = "";
        root.lastError = "";
        root.completedPath = entry.source;
        root.resultApplied = true;
        root.generated(entry.light, entry.dark, entry.source);
        return true;
    }

    function saveGeneratedPalette(sourcePath: string, light, dark): void {
        if (root.matugenRoot.length === 0)
            return;

        root.paletteSaveQueue = root.paletteSaveQueue.concat([{
            "source": sourcePath,
            "light": light,
            "dark": dark
        }]);
        root.startPaletteSave();
    }

    function startPaletteSave(): void {
        if (saveFingerprintProcess.running || root.paletteSaveQueue.length === 0)
            return;

        const job = root.paletteSaveQueue[0];
        root.paletteSaveQueue = root.paletteSaveQueue.slice(1);
        root.inFlightPaletteSave = job;
        saveFingerprintProcess.exec(root.fingerprintArguments(job.source));
    }

    function storePaletteEntry(entry): void {
        const entries = root.paletteEntries.filter(candidate => candidate !== null
                                                               && candidate.source !== entry.source);
        entries.unshift(entry);
        root.paletteEntries = entries.slice(0, root.paletteEntryLimit);
        root.writePalette();
    }

    function loadPalette(text: string): void {
        const entries = [];
        const trimmed = String(text ?? "").trim();
        if (trimmed.length > 0) {
            try {
                const document = JSON.parse(trimmed);
                if (document !== null && typeof document === "object"
                        && document.version === root.paletteVersion
                        && Array.isArray(document.entries)) {
                    for (const candidate of document.entries) {
                        if (candidate === null || typeof candidate !== "object"
                                || typeof candidate.source !== "string"
                                || typeof candidate.fingerprint !== "string"
                                || candidate.fingerprint.length === 0)
                            continue;

                        const parsed = MatugenParser.parseSchemes(candidate.light, candidate.dark);
                        if (!parsed.valid)
                            continue;

                        entries.push({
                            "source": candidate.source,
                            "fingerprint": candidate.fingerprint,
                            "light": parsed.light,
                            "dark": parsed.dark
                        });
                        if (entries.length >= root.paletteEntryLimit)
                            break;
                    }
                }
            } catch (error) {
                console.warn("MatugenService: ignoring invalid palette cache: " + String(error));
            }
        }

        root.paletteEntries = entries;
        root.paletteLoaded = true;
        if (root.requestedPath.length > 0 && !MatugenRunner.running) {
            if (root.paletteEntryFor(root.requestedPath) !== null)
                root.startGeneration();
            else
                requestTimer.restart();
        }
    }

    function handlePaletteLoadFailure(error): void {
        if (error !== FileViewError.FileNotFound)
            console.warn("MatugenService: could not read palette cache: " + FileViewError.toString(error));

        root.paletteEntries = [];
        root.paletteLoaded = true;
        if (root.requestedPath.length > 0 && !MatugenRunner.running)
            requestTimer.restart();
    }

    function writePalette(): void {
        root.pendingPaletteText = JSON.stringify({
            "version": root.paletteVersion,
            "entries": root.paletteEntries
        }, null, 2) + "\n";

        if (root.paletteDirectoryReady) {
            root.flushPaletteWrite();
            return;
        }
        if (root.paletteDirectoryInProgress)
            return;

        root.paletteDirectoryInProgress = true;
        paletteDirectoryProcess.exec(["mkdir", "-p", "--", root.stateDirectory]);
    }

    function flushPaletteWrite(): void {
        if (root.paletteSaveInProgress || root.pendingPaletteText.length === 0)
            return;

        const text = root.pendingPaletteText;
        root.pendingPaletteText = "";
        root.paletteSaveInProgress = true;
        root.paletteView.setText(text);
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

        // The cache is a tiny local file loaded at startup. Wait for it
        // instead of starting an avoidable Matugen run.
        if (!root.paletteLoaded) {
            requestTimer.restart();
            return;
        }

        if (root.restorePalette())
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
            root.saveGeneratedPalette(sourcePath, result.light, result.dark);
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

    property FileView paletteView: FileView {
        path: ""
        atomicWrites: true
        watchChanges: false
        printErrors: false

        onLoaded: root.loadPalette(root.paletteView.text())
        onLoadFailed: error => root.handlePaletteLoadFailure(error)
        onSaved: {
            root.paletteSaveInProgress = false;
            root.flushPaletteWrite();
        }
        onSaveFailed: error => {
            root.paletteSaveInProgress = false;
            root.pendingPaletteText = "";
            console.warn("MatugenService: could not save palette cache: " + FileViewError.toString(error));
        }
    }

    Process {
        id: restoreFingerprintProcess

        stdout: StdioCollector {
            id: restoreFingerprintOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            const entry = root.pendingPaletteEntry;
            root.pendingPaletteEntry = null;
            if (entry === null || entry.source !== root.requestedPath)
                return;

            if (exitCode === 0 && restoreFingerprintOutput.text.trim() === entry.fingerprint) {
                root.applyCachedPalette(entry);
                return;
            }
            requestTimer.restart();
        }
    }

    Process {
        id: saveFingerprintProcess

        stdout: StdioCollector {
            id: saveFingerprintOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            const job = root.inFlightPaletteSave;
            root.inFlightPaletteSave = null;
            if (job !== null && job !== undefined && exitCode === 0) {
                const fingerprint = saveFingerprintOutput.text.trim();
                if (fingerprint.length > 0) {
                    root.storePaletteEntry({
                        "source": job.source,
                        "fingerprint": fingerprint,
                        "light": job.light,
                        "dark": job.dark
                    });
                }
            }
            root.startPaletteSave();
        }
    }

    Process {
        id: paletteDirectoryProcess

        onExited: (exitCode, exitStatus) => {
            root.paletteDirectoryInProgress = false;
            if (exitCode !== 0) {
                root.pendingPaletteText = "";
                console.warn("MatugenService: could not create the palette state directory");
                return;
            }

            root.paletteDirectoryReady = true;
            root.flushPaletteWrite();
        }
    }

    Component.onCompleted: root.paletteView.path = root.paletteFile
}
