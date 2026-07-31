pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: root.connected
    property bool connected: false
    property var workspaces: []
    property string lastError: ""
    property int reconnectDelay: 1000
    property int currentReconnectDelay: 1000
    property int maxReconnectDelay: 5000
    property int pendingWorkspaceIndex: -1

    signal eventReceived(var event)
    signal eventParseFailed(string line, string message)
    signal eventApplyFailed(var event, string message)

    function normalizeWorkspace(workspace) {
        if (workspace === null || workspace === undefined || typeof workspace !== "object")
            return {
                "id": 0,
                "index": 0,
                "name": "",
                "output": "",
                "active": false,
                "focused": false,
                "urgent": false,
                "occupied": false,
                "activeWindowId": null
            };

        const activeWindowId = workspace.active_window_id ?? null;
        return {
            "id": Number(workspace.id ?? 0),
            "index": Number(workspace.idx ?? 0),
            "name": workspace.name ?? "",
            "output": workspace.output ?? "",
            "active": Boolean(workspace.is_active),
            "focused": Boolean(workspace.is_focused),
            "urgent": Boolean(workspace.is_urgent),
            "occupied": activeWindowId !== null,
            "activeWindowId": activeWindowId
        };
    }

    function patchWorkspaceById(workspaceId, changes) {
        const index = root.workspaces.findIndex(workspace => {
            return workspace.id === workspaceId;
        });
        if (index < 0)
            return;

        const workspace = root.workspaces[index];
        const keys = Object.keys(changes);
        let changed = false;
        for (const key of keys) {
            if (workspace[key] !== changes[key]) {
                changed = true;
                break;
            }
        }
        if (!changed)
            return;

        const nextWorkspaces = root.workspaces.slice();
        nextWorkspaces[index] = Object.assign({}, workspace, changes);
        root.workspaces = nextWorkspaces;
    }

    function handleEventLine(line: string) {
        const trimmedLine = String(line).trim();
        if (trimmedLine.length === 0)
            return;

        let event;
        try {
            event = JSON.parse(trimmedLine);
        } catch (error) {
            const message = String(error);
            root.lastError = message;
            root.eventParseFailed(trimmedLine, message);
            console.warn("Could not parse Niri event:", message, trimmedLine);
            return;
        }
        root.connected = true;
        root.lastError = "";
        root.currentReconnectDelay = root.reconnectDelay;
        root.eventReceived(event);
        try {
            root.applyEvent(event);
        } catch (error) {
            const message = String(error);
            root.lastError = message;
            root.eventApplyFailed(event, message);
            console.error("Could not apply Niri event:", message, JSON.stringify(event));
        }
    }

    function applyEvent(event) {
        if (event === null || typeof event !== "object" || Array.isArray(event))
            throw new Error("Expected a Niri event object");

        const eventType = Object.keys(event)[0];
        const payload = event[eventType];
        switch (eventType) {
        case "WorkspacesChanged":
            {
                const incoming = payload.workspaces ?? [];
                root.workspaces = incoming.map(workspace => {
                    return root.normalizeWorkspace(workspace);
                }).sort((left, right) => {
                    if (left.output === right.output)
                        return left.index - right.index;

                    return left.output.localeCompare(right.output);
                });
                return;
            }
        case "WorkspaceActivated":
            {
                const targetId = Number(payload.id);
                const target = root.workspaces.find(workspace => {
                    return workspace.id === targetId;
                });
                if (target === undefined)
                    return;

                const becomesFocused = Boolean(payload.focused);
                let nextWorkspaces = null;
                for (let index = 0; index < root.workspaces.length; ++index) {
                    const workspace = root.workspaces[index];
                    const active = workspace.output === target.output ? workspace.id === targetId : workspace.active;
                    const focused = becomesFocused ? workspace.id === targetId : workspace.focused;
                    if (active === workspace.active && focused === workspace.focused)
                        continue;

                    if (nextWorkspaces === null)
                        nextWorkspaces = root.workspaces.slice();

                    nextWorkspaces[index] = Object.assign({}, workspace, {
                        "active": active,
                        "focused": focused
                    });
                }
                if (nextWorkspaces !== null)
                    root.workspaces = nextWorkspaces;

                return;
            }
        case "WorkspaceUrgencyChanged":
            {
                root.patchWorkspaceById(Number(payload.id), {
                    "urgent": Boolean(payload.urgent)
                });
                return;
            }
        case "WorkspaceActiveWindowChanged":
            {
                const activeWindowId = payload.active_window_id ?? null;
                root.patchWorkspaceById(Number(payload.workspace_id), {
                    "activeWindowId": activeWindowId,
                    "occupied": activeWindowId !== null
                });
                return;
            }
        default:
            // Niri may add new event variants in the future.
            return;
        }
    }

    function handleStreamError(data) {
        const message = String(data).trim();
        if (message.length === 0)
            return;

        root.lastError = message;
        console.warn("Niri event stream:", message);
    }

    function runAction(process, action: string, args) {
        process.exec(["niri", "msg", "action", action].concat(args ?? []));
    }

    function focusWorkspace(workspaceIndex: int, outputName: string) {
        if (workspaceIndex < 1 || focusMonitorProcess.running || focusWorkspaceProcess.running)
            return;

        const focusedWorkspace = root.workspaces.find(workspace => {
            return workspace.focused;
        });
        const currentOutput = focusedWorkspace ? focusedWorkspace.output.trim() : "";
        const targetOutput = outputName.trim();
        const needsMonitorFocus = targetOutput.length > 0 && targetOutput.toLowerCase() !== currentOutput.toLowerCase();
        if (needsMonitorFocus) {
            root.pendingWorkspaceIndex = workspaceIndex;
            root.runAction(focusMonitorProcess, "focus-monitor", [targetOutput]);
            return;
        }
        root.pendingWorkspaceIndex = -1;
        root.runFocusWorkspace(workspaceIndex);
    }

    function runFocusWorkspace(workspaceIndex: int) {
        root.runAction(focusWorkspaceProcess, "focus-workspace", [String(workspaceIndex)]);
    }

    function quit() {
        if (quitProcess.running)
            return;

        root.runAction(quitProcess, "quit", ["--skip-confirmation"]);
    }

    Component.onCompleted: eventStream.running = true

    Process {
        id: eventStream

        command: ["niri", "msg", "--json", "event-stream"]
        onExited: {
            root.connected = false;
            reconnectTimer.interval = root.currentReconnectDelay;
            root.currentReconnectDelay = Math.min(root.maxReconnectDelay, root.currentReconnectDelay * 2);
            reconnectTimer.restart();
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                return root.handleEventLine(data);
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                return root.handleStreamError(data);
            }
        }
    }

    Timer {
        id: reconnectTimer

        interval: root.currentReconnectDelay
        repeat: false
        onTriggered: {
            if (!eventStream.running)
                eventStream.running = true;
        }
    }

    Process {
        id: focusMonitorProcess

        onExited: (exitCode, exitStatus) => {
            const workspaceIndex = root.pendingWorkspaceIndex;
            root.pendingWorkspaceIndex = -1;
            if (workspaceIndex < 1)
                return;

            if (exitCode !== 0) {
                root.lastError = "Could not focus monitor; exit code " + exitCode;
                console.warn(root.lastError, "status:", exitStatus);
                return;
            }
            root.runFocusWorkspace(workspaceIndex);
        }
    }

    Process {
        id: focusWorkspaceProcess
    }

    Process {
        id: quitProcess
    }
}
