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

    property int pendingWorkspaceIndex: -1

    signal eventReceived(var event)
    signal eventParseFailed(string line, string message)
    signal eventApplyFailed(var event, string message)

    function normalizeWorkspace(workspace: var): var {
        const activeWindowId = workspace.active_window_id ?? null;

        return {
            id: Number(workspace.id),
            index: Number(workspace.idx),
            name: workspace.name ?? "",
            output: workspace.output ?? "",
            active: Boolean(workspace.is_active),
            focused: Boolean(workspace.is_focused),
            urgent: Boolean(workspace.is_urgent),
            occupied: activeWindowId !== null,
            activeWindowId: activeWindowId
        };
    }

    function patchWorkspaceById(workspaceId: var, changes: var): void {
        const index = root.workspaces.findIndex(workspace => workspace.id === workspaceId);

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

    function handleEventLine(line: string): void {
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

    function applyEvent(event: var): void {
        if (event === null || typeof event !== "object" || Array.isArray(event)) {
            throw new Error("Expected a Niri event object");
        }

        const eventType = Object.keys(event)[0];
        const payload = event[eventType];

        switch (eventType) {
        case "WorkspacesChanged":
            {
                const incoming = payload.workspaces ?? [];

                root.workspaces = incoming.map(workspace => root.normalizeWorkspace(workspace)).sort((left, right) => {
                    if (left.output === right.output)
                        return left.index - right.index;

                    return left.output.localeCompare(right.output);
                });

                return;
            }
        case "WorkspaceActivated":
            {
                const targetId = Number(payload.id);
                const target = root.workspaces.find(workspace => workspace.id === targetId);

                if (target === undefined)
                    return;

                const becomesFocused = Boolean(payload.focused);
                let nextWorkspaces = null;

                for (let index = 0; index < root.workspaces.length; ++index) {
                    const workspace = root.workspaces[index];

                    const active = workspace.output === target.output ? workspace.id === targetId : workspace.active;

                    const focused = becomesFocused ? workspace.id === targetId : workspace.focused;

                    if (active === workspace.active && focused === workspace.focused) {
                        continue;
                    }

                    if (nextWorkspaces === null)
                        nextWorkspaces = root.workspaces.slice();

                    nextWorkspaces[index] = Object.assign({}, workspace, {
                        active: active,
                        focused: focused
                    });
                }

                if (nextWorkspaces !== null)
                    root.workspaces = nextWorkspaces;

                return;
            }
        case "WorkspaceUrgencyChanged":
            {
                root.patchWorkspaceById(Number(payload.id), {
                    urgent: Boolean(payload.urgent)
                });

                return;
            }
        case "WorkspaceActiveWindowChanged":
            {
                const activeWindowId = payload.active_window_id ?? null;

                root.patchWorkspaceById(Number(payload.workspace_id), {
                    activeWindowId: activeWindowId,
                    occupied: activeWindowId !== null
                });

                return;
            }
        default:
            // Niri may add new event variants in the future.
            return;
        }
    }

    function handleStreamError(data: var): void {
        const message = String(data).trim();

        if (message.length === 0)
            return;

        root.lastError = message;

        console.warn("Niri event stream:", message);
    }

    function runAction(process: var, action: string, args: var): void {
        process.exec(["niri", "msg", "action", action].concat(args ?? []));
    }

    function focusWorkspace(workspaceIndex: int, outputName: string): void {
        if (workspaceIndex < 1)
            return;

        const focusedWorkspace = root.workspaces.find(workspace => workspace.focused);

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

    function runFocusWorkspace(workspaceIndex: int): void {
        root.runAction(focusWorkspaceProcess, "focus-workspace", [String(workspaceIndex)]);
    }

    function quit(): void {
        if (quitProcess.running)
            return;

        root.runAction(quitProcess, "quit", ["--skip-confirmation"]);
    }

    Process {
        id: eventStream

        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => root.handleEventLine(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => root.handleStreamError(data)
        }

        onExited: {
            root.connected = false;
            reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer

        interval: root.reconnectDelay
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

    Component.onCompleted: eventStream.running = true
}
