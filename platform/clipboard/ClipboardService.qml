pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "ClipboardParser.js" as ClipboardParser

Singleton {
    id: root

    readonly property bool capturing: textCaptureProcess.running || imageCaptureProcess.running
    readonly property bool busy: listProcess.running || copyProcess.running || deleteProcess.running || clearProcess.running
    property bool initialized: false
    property bool available: false
    property bool captureEnabled: true
    property bool viewActive: false
    property bool historyDirty: true
    property bool loading: false
    property bool refreshPending: false
    property int historyRevision: 0
    property int listRevision: 0
    property var entries: []
    property string lastError: ""
    property string pendingCopyEntry: ""
    property var pendingCopiedEntry: null
    property string pendingDeleteLine: ""
    property var pendingDeleteEntry: null

    signal entryCopied(var entry)
    signal entryDeleted(var entry)
    signal historyCleared()
    signal operationFailed(string operation, string message)

    function initialize() {
        if (root.initialized)
            return;

        root.initialized = true;
    }

    function setViewActive(active) {
        const nextActive = Boolean(active);
        if (root.viewActive === nextActive)
            return;

        root.viewActive = nextActive;
        if (nextActive && (root.historyDirty || !root.available)) {
            root.refresh();
        } else {
            historyRefreshTimer.stop();
            // The history can be large and is only used by the clipboard
            // panel. Drop it when the panel closes so it does not stay
            // resident for the rest of the session.
            if (!nextActive && root.entries.length > 0) {
                root.entries = [];
                root.historyDirty = true;
            }
        }
    }

    function markHistoryDirty() {
        root.historyRevision++;
        root.historyDirty = true;
        if (root.viewActive)
            historyRefreshTimer.restart();
    }

    function refresh() {
        if (listProcess.running) {
            root.refreshPending = true;
            return;
        }

        root.refreshPending = false;
        historyRefreshTimer.stop();
        root.listRevision = root.historyRevision;
        root.loading = true;
        listProcess.exec(["cliphist", "list"]);
    }

    function copy(entry): bool {
        if (!root.isValidEntry(entry) || copyProcess.running)
            return false;

        root.pendingCopyEntry = entry.rawLine;
        root.pendingCopiedEntry = entry;
        copyProcess.exec(["sh", "-c", "IFS= read -r selection && printf '%s\\n' \"$selection\" | cliphist decode | wl-copy"]);
        return true;
    }

    function remove(entry): bool {
        if (!root.isValidEntry(entry) || deleteProcess.running)
            return false;

        root.pendingDeleteLine = entry.rawLine;
        root.pendingDeleteEntry = entry;
        deleteProcess.exec(["cliphist", "delete"]);
        return true;
    }

    function clear(): bool {
        if (clearProcess.running)
            return false;

        clearProcess.exec(["cliphist", "wipe"]);
        return true;
    }

    function isValidEntry(entry): bool {
        return entry !== null && entry !== undefined
            && typeof entry.rawLine === "string" && entry.rawLine.length > 0;
    }

    function handleListFinished(exitCode, output, errorOutput) {
        root.loading = false;

        if (exitCode !== 0) {
            root.available = false;
            root.lastError = errorOutput.trim().length > 0 ? errorOutput.trim() : "cliphist exited with code " + exitCode;
            console.warn("ClipboardService: could not list clipboard history:", root.lastError);
        } else {
            root.available = true;
            root.lastError = "";
            // If the panel closed while cliphist was running, do not keep the
            // parsed history resident. The next open refreshes it.
            root.entries = root.viewActive ? ClipboardParser.parseList(output) : [];
            root.historyDirty = !root.viewActive || root.listRevision !== root.historyRevision;
        }

        if (root.refreshPending || (exitCode === 0 && root.viewActive && root.historyDirty))
            root.refresh();
    }

    function handleOperationFailure(operation, exitCode, errorOutput) {
        const details = String(errorOutput || "").trim();
        const message = details.length > 0 ? details : operation + " exited with code " + exitCode;
        root.lastError = message;
        root.operationFailed(operation, message);
        console.warn("ClipboardService: " + operation + " failed:", message);
    }

    Timer {
        id: historyRefreshTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (root.viewActive)
                root.refresh();
        }
    }

    FileView {
        // cliphist writes a Bolt database. Watch its metadata without loading
        // the binary file into QML, then list it only while the UI is visible.
        path: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation) + "/cliphist/db"
        watchChanges: root.initialized && root.captureEnabled
        preload: false
        blockAllReads: true
        printErrors: false
        onFileChanged: root.markHistoryDirty()
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            id: listOutput
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: listError
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            root.handleListFinished(exitCode, listOutput.text, listError.text);
        }
    }

    Process {
        id: copyProcess

        stdinEnabled: true

        onStarted: {
            copyProcess.write(root.pendingCopyEntry + "\n");
            root.pendingCopyEntry = "";
        }

        stderr: StdioCollector {
            id: copyError
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            const copiedEntry = root.pendingCopiedEntry;
            root.pendingCopiedEntry = null;
            if (exitCode !== 0) {
                root.handleOperationFailure("copy", exitCode, copyError.text);
                return;
            }

            root.entryCopied(copiedEntry);
        }
    }

    Process {
        id: deleteProcess

        stdinEnabled: true

        onStarted: {
            deleteProcess.write(root.pendingDeleteLine + "\n");
            root.pendingDeleteLine = "";
        }

        stderr: StdioCollector {
            id: deleteError
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            const deletedEntry = root.pendingDeleteEntry;
            root.pendingDeleteEntry = null;

            if (exitCode !== 0) {
                root.handleOperationFailure("delete", exitCode, deleteError.text);
                return;
            }

            root.entryDeleted(deletedEntry);
            if (root.viewActive)
                root.refresh();
        }
    }

    Process {
        id: clearProcess

        stderr: StdioCollector {
            id: clearError
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.handleOperationFailure("clear", exitCode, clearError.text);
                return;
            }

            root.entries = [];
            root.historyCleared();
            if (root.viewActive)
                root.refresh();
        }
    }

    Process {
        id: textCaptureProcess

        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: root.initialized && root.captureEnabled

        onExited: (exitCode, exitStatus) => {
            if (root.captureEnabled && exitCode !== 0)
                console.warn("ClipboardService: text capture stopped with code", exitCode);
        }
    }

    Process {
        id: imageCaptureProcess

        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: root.initialized && root.captureEnabled

        onExited: (exitCode, exitStatus) => {
            if (root.captureEnabled && exitCode !== 0)
                console.warn("ClipboardService: image capture stopped with code", exitCode);
        }
    }
}
