pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.platform.power

Singleton {
    id: root

    readonly property string cachePath: Quickshell.cachePath("video-wallpapers")
    readonly property string cacheToolPath: root.localPath(Quickshell.shellPath("tools/ateria-video-cache"))
    readonly property bool busy: scanProcess.running || workerProcess.running
        || reconcileTimer.running || jobDelay.running
    readonly property bool canTranscode: !PowerService.powerSaver && (root.hardwareAvailable || PowerService.onExternalPower)
    property bool hardwareAvailable: false
    property var entries: ({})
    property var queue: []
    property var thumbnailQueue: []
    property var knownSources: []
    property var pendingRequest: null
    property var scanRequest: null
    property string activeSource: ""
    property string activeJob: ""
    property string preferredSource: ""
    property bool workerSucceeded: false
    property int profileWidth: 1920
    property int profileHeight: 1080
    property int consecutiveThumbnails: 0
    property bool startupGracePending: true
    property bool expeditedWorkRequested: false

    readonly property int initialJobDelay: 250
    readonly property int startupJobDelay: 2500
    readonly property int interJobDelay: 50
    readonly property int thumbnailBurstSize: 4

    function localPath(source): string {
        const value = String(source ?? "");
        if (!value.startsWith("file:"))
            return value;

        return decodeURIComponent(value.replace(/^file:\/\//, ""));
    }

    function fileUrl(path): string {
        return "file://" + String(path).split("/").map(part => encodeURIComponent(part)).join("/");
    }

    function isVideo(source): bool {
        return /\.(mp4|webm|mkv|gif)$/i.test(String(source));
    }

    function entryFor(source): var {
        return root.entries[String(source)] ?? null;
    }

    function isSelectable(source): bool {
        if (!root.isVideo(source))
            return true;

        const entry = root.entryFor(source);
        return entry !== null && (entry.status === "ready" || entry.status === "original");
    }

    function playbackSource(source): string {
        const entry = root.entryFor(source);
        return root.isSelectable(source) && entry !== null ? String(entry.playbackSource ?? "") : "";
    }

    function statusText(source): string {
        const entry = root.entryFor(source);
        if (entry === null)
            return qsTr("Checking video");

        switch (entry.status) {
        case "queued":
            if (PowerService.powerSaver)
                return qsTr("Waiting for balanced power mode");
            if (PowerService.onBattery && String(source) !== root.preferredSource)
                return qsTr("Waiting for external power");
            return qsTr("Queued for conversion");
        case "converting":
            return qsTr("Converting %1%").arg(Math.round(entry.progress * 100));
        case "invalid":
            return qsTr("Video cannot be prepared");
        case "failed":
            return qsTr("Conversion failed");
        default:
            return "";
        }
    }

    function updateEntry(source, changes): void {
        const key = String(source);
        const current = root.entries[key];
        if (current === undefined)
            return;

        const updatedEntries = Object.assign({}, root.entries);
        updatedEntries[key] = Object.assign({}, current, changes);
        root.entries = updatedEntries;
    }

    function markScanFailed(request, message): void {
        if (request === null)
            return;

        const failedEntries = {};
        for (const source of request.sources) {
            failedEntries[source] = {
                "localPath": root.localPath(source),
                "status": "failed",
                "progress": 0,
                "playbackSource": "",
                "error": message
            };
        }
        root.entries = failedEntries;
        root.queue = [];
        root.thumbnailQueue = [];
    }

    function reconcile(sources, width, height, preferredSource, forceRebuild): void {
        const uniqueSources = [];
        const seen = {};
        for (const source of sources ?? []) {
            const sourceUrl = String(source);
            if (!root.isVideo(sourceUrl) || seen[sourceUrl] === true)
                continue;
            seen[sourceUrl] = true;
            uniqueSources.push(sourceUrl);
        }

        root.pendingRequest = {
            "sources": uniqueSources,
            "width": Math.max(2, Math.round(Number(width) || 1920)),
            "height": Math.max(2, Math.round(Number(height) || 1080)),
            "preferredSource": String(preferredSource ?? ""),
            "forceRebuild": forceRebuild === true
        };
        root.knownSources = uniqueSources;
        reconcileTimer.restart();
    }

    function rebuild(): void {
        if (root.busy || root.knownSources.length === 0)
            return;

        const checkingEntries = Object.assign({}, root.entries);
        for (const source of Object.keys(checkingEntries)) {
            const entry = checkingEntries[source];
            if (entry.status !== "original") {
                checkingEntries[source] = Object.assign({}, entry, {
                    "status": "checking",
                    "progress": 0,
                    "playbackSource": "",
                    "error": ""
                });
            }
        }
        root.entries = checkingEntries;
        root.queue = [];
        root.thumbnailQueue = [];
        root.reconcile(root.knownSources, root.profileWidth, root.profileHeight, root.preferredSource, true);
    }

    function scheduleNext(delay): void {
        if (root.pendingRequest === null && root.queue.length === 0
                && root.thumbnailQueue.length === 0)
            return;

        jobDelay.interval = Math.max(0, Math.round(Number(delay) || 0));
        jobDelay.restart();
    }

    function expeditePendingWork(): void {
        const discoveryPending = scanProcess.running || reconcileTimer.running
            || root.pendingRequest !== null || root.scanRequest !== null;
        const workPending = jobDelay.running || root.queue.length > 0 || root.thumbnailQueue.length > 0;
        if (!root.startupGracePending && !discoveryPending && !workPending)
            return;

        root.expeditedWorkRequested = true;
        if (jobDelay.running)
            root.scheduleNext(root.interJobDelay);
    }

    function startScan(): void {
        if (scanProcess.running || workerProcess.running || root.pendingRequest === null)
            return;

        const request = root.pendingRequest;
        root.pendingRequest = null;
        root.scanRequest = request;
        root.profileWidth = request.width;
        root.profileHeight = request.height;

        const command = [root.cacheToolPath, "scan", root.cachePath, String(request.width), String(request.height)];
        if (request.forceRebuild)
            command.push("--rebuild");
        for (const source of request.sources)
            command.push(root.localPath(source));
        scanProcess.exec(command);
    }

    function finishScan(exitCode): void {
        const request = root.scanRequest;
        root.scanRequest = null;
        if (exitCode !== 0 || request === null) {
            const detail = String(scanError.text).trim();
            const message = detail.length > 0 ? detail : qsTr("Cache scan exited with code %1").arg(exitCode);
            root.markScanFailed(request, message);
            console.warn("WallpaperCacheService: cache scan failed:", message);
            if (root.pendingRequest !== null)
                reconcileTimer.restart();
            return;
        }

        let payload;
        try {
            payload = JSON.parse(String(scanOutput.text).trim());
        } catch (error) {
            const message = qsTr("Invalid cache scan output: %1").arg(String(error));
            root.markScanFailed(request, message);
            console.warn("WallpaperCacheService:", message);
            if (root.pendingRequest !== null)
                reconcileTimer.restart();
            return;
        }

        root.hardwareAvailable = payload.hardwareAvailable === true;
        const sourceByPath = {};
        for (const source of request.sources)
            sourceByPath[root.localPath(source)] = source;

        const updatedEntries = {};
        const pending = [];
        const pendingThumbnails = [];
        for (const rawEntry of payload.entries ?? []) {
            const source = sourceByPath[String(rawEntry.source)] ?? root.fileUrl(rawEntry.source);
            const playbackPath = String(rawEntry.playbackPath ?? "");
            const thumbnailPath = String(rawEntry.thumbnailPath ?? "");
            const entry = {
                "localPath": String(rawEntry.source),
                "status": String(rawEntry.status ?? "invalid"),
                "progress": Number(rawEntry.progress ?? 0),
                "playbackPath": playbackPath,
                "playbackSource": playbackPath.length > 0 ? root.fileUrl(playbackPath) : "",
                "thumbnailStatus": String(rawEntry.thumbnailStatus ?? "failed"),
                "thumbnailSource": rawEntry.thumbnailStatus === "ready" && thumbnailPath.length > 0
                    ? root.fileUrl(thumbnailPath) : "",
                "error": String(rawEntry.error ?? "")
            };
            updatedEntries[source] = entry;
            if (entry.status === "queued")
                pending.push(source);
            if (entry.thumbnailStatus === "queued")
                pendingThumbnails.push(source);
        }

        const preferredSource = String(request.preferredSource);
        root.preferredSource = preferredSource;
        pending.sort((left, right) => (left === preferredSource ? -1 : 0) - (right === preferredSource ? -1 : 0));
        pendingThumbnails.sort((left, right) => (left === preferredSource ? -1 : 0) - (right === preferredSource ? -1 : 0));
        root.entries = updatedEntries;
        root.queue = pending;
        root.thumbnailQueue = pendingThumbnails;
        root.consecutiveThumbnails = 0;

        if (root.pendingRequest !== null) {
            reconcileTimer.restart();
            return;
        }

        // Discovery is asynchronous and low-priority, so cached playback can
        // be restored early. New media work waits once for shell startup unless
        // opening the selector made it explicitly user-facing.
        const delay = root.expeditedWorkRequested
            ? root.interJobDelay
            : (root.startupGracePending ? root.startupJobDelay : root.initialJobDelay);
        root.startupGracePending = false;
        root.expeditedWorkRequested = false;
        root.scheduleNext(delay);
    }

    function startNext(): void {
        if (root.pendingRequest !== null) {
            root.startScan();
            return;
        }
        if (scanProcess.running || workerProcess.running)
            return;

        const canStartTranscode = root.canTranscode && root.queue.length > 0
            && (!PowerService.onBattery || root.queue[0] === root.preferredSource);
        const preferredNeedsTranscode = canStartTranscode && root.queue[0] === root.preferredSource;
        const preferredNeedsThumbnail = root.thumbnailQueue.length > 0
            && root.thumbnailQueue[0] === root.preferredSource;
        const canStartThumbnailBurst = root.thumbnailQueue.length > 0
            && (!canStartTranscode || root.consecutiveThumbnails < root.thumbnailBurstSize);

        // A selected video's small preview is cheap and makes the selector
        // useful immediately. Its full playback cache remains the next
        // priority. Afterwards, bounded thumbnail bursts keep previews and
        // background transcodes from starving each other.
        if (preferredNeedsThumbnail) {
            root.startThumbnail();
            return;
        }
        if (preferredNeedsTranscode) {
            root.startTranscode();
            return;
        }
        if (canStartThumbnailBurst) {
            root.startThumbnail();
            return;
        }
        if (canStartTranscode)
            root.startTranscode();
        else if (root.thumbnailQueue.length > 0)
            root.startThumbnail();
    }

    function startTranscode(): void {
        const pending = root.queue.slice();
        const source = String(pending.shift() ?? "");
        root.queue = pending;
        const entry = root.entryFor(source);
        if (entry === null || entry.status !== "queued") {
            Qt.callLater(root.startNext);
            return;
        }
        root.activeSource = source;
        root.activeJob = "transcode";
        root.workerSucceeded = false;
        root.consecutiveThumbnails = 0;
        root.updateEntry(source, {"status": "converting", "progress": 0});
        workerProcess.exec([
            root.cacheToolPath,
            "transcode",
            root.cachePath,
            String(root.profileWidth),
            String(root.profileHeight),
            entry.localPath
        ]);
    }

    function startThumbnail(): void {
        const pending = root.thumbnailQueue.slice();
        const source = String(pending.shift() ?? "");
        root.thumbnailQueue = pending;
        const entry = root.entryFor(source);
        if (entry === null || entry.thumbnailStatus !== "queued") {
            Qt.callLater(root.startNext);
            return;
        }

        root.activeSource = source;
        root.activeJob = "thumbnail";
        root.workerSucceeded = false;
        root.consecutiveThumbnails += 1;
        root.updateEntry(source, {"thumbnailStatus": "generating"});
        const command = [root.cacheToolPath, "thumbnail", root.cachePath, entry.localPath];
        if (String(entry.playbackPath ?? "").length > 0)
            command.push(entry.playbackPath);
        workerProcess.exec(command);
    }

    function handleWorkerLine(line): void {
        if (root.activeSource.length === 0)
            return;

        let payload;
        try {
            payload = JSON.parse(String(line));
        } catch (error) {
            return;
        }

        switch (payload.type) {
        case "progress":
            root.updateEntry(root.activeSource, {"progress": Math.max(0, Math.min(1, Number(payload.progress ?? 0)))});
            break;
        case "ready":
            root.workerSucceeded = true;
            root.updateEntry(root.activeSource, {
                "status": "ready",
                "progress": 1,
                "playbackPath": String(payload.playbackPath ?? ""),
                "playbackSource": root.fileUrl(payload.playbackPath),
                "error": ""
            });
            break;
        case "thumbnailReady":
            root.workerSucceeded = true;
            root.updateEntry(root.activeSource, {
                "thumbnailStatus": "ready",
                "thumbnailSource": root.fileUrl(payload.thumbnailPath)
            });
            break;
        case "error":
            if (root.activeJob !== "thumbnail")
                root.updateEntry(root.activeSource, {"error": String(payload.message ?? "ffmpeg failed")});
            break;
        }
    }

    function finishWorker(exitCode): void {
        const source = root.activeSource;
        if (source.length > 0 && (!root.workerSucceeded || exitCode !== 0)) {
            const detail = String(workerError.text).trim();
            if (root.activeJob === "thumbnail") {
                root.updateEntry(source, {"thumbnailStatus": "failed"});
            } else {
                root.updateEntry(source, {
                    "status": "failed",
                    "progress": 0,
                    "error": detail.length > 0 ? detail : qsTr("ffmpeg exited with code %1").arg(exitCode)
                });
            }
        }
        root.activeSource = "";
        root.activeJob = "";
        root.workerSucceeded = false;

        if (root.pendingRequest !== null)
            reconcileTimer.restart();
        else
            root.scheduleNext(root.interJobDelay);
    }

    onCanTranscodeChanged: {
        if (root.canTranscode)
            root.scheduleNext(root.interJobDelay);
    }

    Connections {
        target: PowerService

        function onOnBatteryChanged(): void {
            if (PowerService.onExternalPower)
                root.scheduleNext(root.interJobDelay);
        }
    }

    Timer {
        id: reconcileTimer

        interval: 250
        repeat: false
        onTriggered: root.startScan()
    }

    Timer {
        id: jobDelay

        interval: root.initialJobDelay
        repeat: false
        onTriggered: root.startNext()
    }

    Process {
        id: scanProcess

        stdout: StdioCollector {
            id: scanOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: scanError
            waitForEnd: true
        }
        onExited: exitCode => root.finishScan(exitCode)
    }

    Process {
        id: workerProcess

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleWorkerLine(data)
        }
        stderr: StdioCollector {
            id: workerError
            waitForEnd: true
        }
        onExited: exitCode => root.finishWorker(exitCode)
    }
}
