pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: root.connected
    property bool connected: false
    property var workspaces: []
    property var windows: []
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

        const activeWindowId = workspace.active_window_id === null || workspace.active_window_id === undefined
            ? null : Number(workspace.active_window_id);
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

    function normalizeWindow(window) {
        if (window === null || window === undefined || typeof window !== "object")
            return {
                "id": 0,
                "title": "",
                "appId": "",
                "workspaceId": null,
                "focused": false,
                "floating": false,
                "urgent": false,
                "layoutPosition": null
            };

        const layout = window.layout ?? {};
        return {
            "id": Number(window.id ?? 0),
            "title": window.title ?? "",
            "appId": window.app_id ?? "",
            "workspaceId": window.workspace_id === null || window.workspace_id === undefined
                ? null : Number(window.workspace_id),
            "focused": Boolean(window.is_focused),
            "floating": Boolean(window.is_floating),
            "urgent": Boolean(window.is_urgent),
            "layoutPosition": layout.pos_in_scrolling_layout ?? null
        };
    }

    function layoutPositionsEqual(left, right) {
        if (left === right)
            return true;
        if (left === null || right === null)
            return false;

        return Number(left[0]) === Number(right[0]) && Number(left[1]) === Number(right[1]);
    }

    function patchWindowById(windowId, changes) {
        const index = root.windows.findIndex(window => {
            return window.id === windowId;
        });
        if (index < 0)
            return;

        const window = root.windows[index];
        const keys = Object.keys(changes);
        if (!keys.some(key => window[key] !== changes[key]))
            return;

        const nextWindows = root.windows.slice();
        nextWindows[index] = Object.assign({}, window, changes);
        root.windows = nextWindows;
    }

    function setFocusedWindow(windowId) {
        let nextWindows = null;
        for (let index = 0; index < root.windows.length; ++index) {
            const window = root.windows[index];
            const focused = windowId !== null && window.id === windowId;
            if (window.focused === focused)
                continue;

            if (nextWindows === null)
                nextWindows = root.windows.slice();
            nextWindows[index] = Object.assign({}, window, { "focused": focused });
        }
        if (nextWindows !== null)
            root.windows = nextWindows;
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
                const activeWindowId = payload.active_window_id === null || payload.active_window_id === undefined
                    ? null : Number(payload.active_window_id);
                root.patchWorkspaceById(Number(payload.workspace_id), {
                    "activeWindowId": activeWindowId,
                    "occupied": activeWindowId !== null
                });
                return;
            }
        case "WindowsChanged":
            root.windows = (payload.windows ?? []).map(window => {
                return root.normalizeWindow(window);
            });
            return;
        case "WindowOpenedOrChanged":
            {
                const incoming = root.normalizeWindow(payload.window);
                const index = root.windows.findIndex(window => {
                    return window.id === incoming.id;
                });
                let nextWindows = null;
                if (incoming.focused) {
                    for (let currentIndex = 0; currentIndex < root.windows.length; ++currentIndex) {
                        const window = root.windows[currentIndex];
                        if (window.id === incoming.id || !window.focused)
                            continue;

                        if (nextWindows === null)
                            nextWindows = root.windows.slice();
                        nextWindows[currentIndex] = Object.assign({}, window, { "focused": false });
                    }
                }

                if (nextWindows === null)
                    nextWindows = root.windows.slice();
                if (index < 0) {
                    nextWindows.push(incoming);
                } else {
                    nextWindows[index] = incoming;
                }
                root.windows = nextWindows;
                return;
            }
        case "WindowClosed":
            root.windows = root.windows.filter(window => {
                return window.id !== Number(payload.id);
            });
            return;
        case "WindowFocusChanged":
            root.setFocusedWindow(payload.id === null || payload.id === undefined ? null : Number(payload.id));
            return;
        case "WindowUrgencyChanged":
            root.patchWindowById(Number(payload.id), {
                "urgent": Boolean(payload.urgent)
            });
            return;
        case "WindowLayoutsChanged":
            {
                const indexById = new Map();
                for (let index = 0; index < root.windows.length; ++index)
                    indexById.set(root.windows[index].id, index);

                let nextWindows = null;
                for (const change of payload.changes ?? []) {
                    const windowId = Number(change[0]);
                    const index = indexById.get(windowId);
                    if (index === undefined)
                        continue;
                    const layout = change[1] ?? {};
                    const layoutPosition = layout.pos_in_scrolling_layout ?? null;
                    const window = root.windows[index];
                    if (root.layoutPositionsEqual(window.layoutPosition, layoutPosition))
                        continue;

                    if (nextWindows === null)
                        nextWindows = root.windows.slice();
                    nextWindows[index] = Object.assign({}, window, {
                        "layoutPosition": layoutPosition
                    });
                }
                if (nextWindows !== null)
                    root.windows = nextWindows;
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

    function focusWindow(windowId: double) {
        if (windowId < 1 || focusWindowProcess.running)
            return;

        root.runAction(focusWindowProcess, "focus-window", ["--id", String(windowId)]);
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
        id: focusWindowProcess
    }

    Process {
        id: quitProcess
    }
}
