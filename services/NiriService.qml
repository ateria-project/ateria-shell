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

    function updateWorkspace(workspace: var, changes: var): var {
        return {
            id: workspace.id,
            index: workspace.index,
            name: workspace.name,
            output: workspace.output,
            active: changes.active !== undefined ? changes.active : workspace.active,
            focused: changes.focused !== undefined ? changes.focused : workspace.focused,
            urgent: changes.urgent !== undefined ? changes.urgent : workspace.urgent,
            occupied: changes.occupied !== undefined ? changes.occupied : workspace.occupied,
            activeWindowId: changes.activeWindowId !== undefined ? changes.activeWindowId : workspace.activeWindowId
        };
    }

    function handleEventLine(line: string): void {
        const trimmedLine = String(line).trim();

        if (trimmedLine.length === 0)
            return;

        try {
            const event = JSON.parse(trimmedLine);

            root.connected = true;
            root.lastError = "";

            root.eventReceived(event);
            root.applyEvent(event);
        } catch (error) {
            const message = String(error);

            root.lastError = message;
            root.eventParseFailed(trimmedLine, message);

            console.warn("Could not parse Niri event:", message, trimmedLine);
        }
    }

    function applyEvent(event: var): void {
        if (event.WorkspacesChanged !== undefined) {
            const payload = event.WorkspacesChanged;
            const incoming = payload.workspaces ?? [];

            root.workspaces = incoming.map(workspace => root.normalizeWorkspace(workspace)).sort((left, right) => {
                if (left.output === right.output)
                    return left.index - right.index;

                return left.output.localeCompare(right.output);
            });

            console.info("Loaded", root.workspaces.length, "Niri workspaces on outputs:", root.workspaces.map(workspace => workspace.output).filter((output, index, outputs) => output.length > 0 && outputs.indexOf(output) === index).join(", "));

            return;
        }

        if (event.WorkspaceActivated !== undefined) {
            const payload = event.WorkspaceActivated;
            const target = root.workspaces.find(workspace => workspace.id === Number(payload.id));

            if (target === undefined)
                return;

            root.workspaces = root.workspaces.map(workspace => root.updateWorkspace(workspace, {
                    active: workspace.output === target.output ? workspace.id === target.id : workspace.active,
                    focused: payload.focused ? workspace.id === target.id : workspace.focused
                }));

            return;
        }

        if (event.WorkspaceUrgencyChanged !== undefined) {
            const payload = event.WorkspaceUrgencyChanged;
            const workspaceId = Number(payload.id);

            root.workspaces = root.workspaces.map(workspace => root.updateWorkspace(workspace, {
                    urgent: workspace.id === workspaceId ? Boolean(payload.urgent) : workspace.urgent
                }));

            return;
        }

        if (event.WorkspaceActiveWindowChanged !== undefined) {
            const payload = event.WorkspaceActiveWindowChanged;
            const workspaceId = Number(payload.workspace_id);

            root.workspaces = root.workspaces.map(workspace => {
                if (workspace.id !== workspaceId)
                    return workspace;

                const activeWindowId = payload.active_window_id ?? null;

                return root.updateWorkspace(workspace, {
                    activeWindowId: activeWindowId,
                    occupied: activeWindowId !== null
                });
            });
        }
    }

    function focusWorkspace(workspaceIndex: int, outputName: string): void {
        if (workspaceIndex < 1)
            return;

        root.pendingWorkspaceIndex = workspaceIndex;

        const currentFocusedWorkspace = root.workspaces.find(workspace => workspace.focused);
        const currentOutput = currentFocusedWorkspace ? currentFocusedWorkspace.output : "";

        const needsMonitorFocus = outputName.length > 0 && currentOutput.length > 0 && outputName.trim().toLowerCase() !== currentOutput.trim().toLowerCase();

        // Workspace indices are local to each monitor. Focus the target
        // monitor first only when clicking a bar on another output.
        if (needsMonitorFocus) {
            focusMonitorProcess.exec(["niri", "msg", "action", "focus-monitor", outputName]);

            return;
        }

        root.runFocusWorkspace(workspaceIndex);
        root.pendingWorkspaceIndex = -1;
    }

    function runFocusWorkspace(workspaceIndex: int): void {
        focusWorkspaceProcess.exec(["niri", "msg", "action", "focus-workspace", String(workspaceIndex)]);
    }

    function quit(): void {
        if (!quitProcess.running)
            quitProcess.exec(["niri", "msg", "action", "quit", "--skip-confirmation"]);
    }

    Process {
        id: eventStream

        command: ["niri", "msg", "--json", "event-stream"]

        running: false

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => root.handleEventLine(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                const message = String(data).trim();

                if (message.length === 0)
                    return;

                root.lastError = message;

                console.warn("Niri event stream:", message);
            }
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

        onExited: {
            if (root.pendingWorkspaceIndex < 1)
                return;

            root.runFocusWorkspace(root.pendingWorkspaceIndex);

            root.pendingWorkspaceIndex = -1;
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
