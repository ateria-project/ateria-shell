pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.platform.compositor

// Translates Niri events and commands to WorkspaceService's canonical contract.
Singleton {
    id: root

    property string lastError: ""
    property int pendingWorkspaceIndex: -1

    signal workspacesReset(var workspaces)
    signal workspaceActivated(int workspaceId, bool focused)
    signal workspacePatched(int workspaceId, var changes)
    signal windowsReset(var windows)
    signal windowUpserted(var windowData)
    signal windowRemoved(double windowId)
    signal windowFocused(var windowId)
    signal windowPatched(double windowId, var changes)
    signal windowLayoutsPatched(var changes)

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

    function normalizeWindow(windowData) {
        if (windowData === null || windowData === undefined || typeof windowData !== "object")
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

        const layout = windowData.layout ?? {};
        return {
            "id": Number(windowData.id ?? 0),
            "title": windowData.title ?? "",
            "appId": windowData.app_id ?? "",
            "workspaceId": windowData.workspace_id === null || windowData.workspace_id === undefined
                ? null : Number(windowData.workspace_id),
            "focused": Boolean(windowData.is_focused),
            "floating": Boolean(windowData.is_floating),
            "urgent": Boolean(windowData.is_urgent),
            "layoutPosition": layout.pos_in_scrolling_layout ?? null
        };
    }

    function applyEvent(event) {
        if (event === null || typeof event !== "object" || Array.isArray(event))
            throw new Error("Expected a Niri event object");

        const eventType = Object.keys(event)[0];
        const payload = event[eventType];
        switch (eventType) {
        case "WorkspacesChanged":
            {
                const workspaces = (payload.workspaces ?? []).map(root.normalizeWorkspace);
                workspaces.sort((left, right) => left.output === right.output
                    ? left.index - right.index
                    : left.output.localeCompare(right.output));
                root.workspacesReset(workspaces);
                return;
            }
        case "WorkspaceActivated":
            root.workspaceActivated(Number(payload.id), Boolean(payload.focused));
            return;
        case "WorkspaceUrgencyChanged":
            root.workspacePatched(Number(payload.id), {
                "urgent": Boolean(payload.urgent)
            });
            return;
        case "WorkspaceActiveWindowChanged":
            {
                const activeWindowId = payload.active_window_id === null || payload.active_window_id === undefined
                    ? null : Number(payload.active_window_id);
                root.workspacePatched(Number(payload.workspace_id), {
                    "activeWindowId": activeWindowId,
                    "occupied": activeWindowId !== null
                });
                return;
            }
        case "WindowsChanged":
            root.windowsReset((payload.windows ?? []).map(root.normalizeWindow));
            return;
        case "WindowOpenedOrChanged":
            root.windowUpserted(root.normalizeWindow(payload.window));
            return;
        case "WindowClosed":
            root.windowRemoved(Number(payload.id));
            return;
        case "WindowFocusChanged":
            root.windowFocused(payload.id === null || payload.id === undefined ? null : Number(payload.id));
            return;
        case "WindowUrgencyChanged":
            root.windowPatched(Number(payload.id), {
                "urgent": Boolean(payload.urgent)
            });
            return;
        case "WindowLayoutsChanged":
            root.windowLayoutsPatched((payload.changes ?? []).map(change => {
                const layout = change[1] ?? {};
                return [Number(change[0]), layout.pos_in_scrolling_layout ?? null];
            }));
            return;
        default:
            return;
        }
    }

    function runAction(process, action: string, args) {
        process.exec(["niri", "msg", "action", action].concat(args ?? []));
    }

    function focusWorkspace(workspaceIndex: int, outputName: string, focusedOutputName: string) {
        if (workspaceIndex < 1 || focusMonitorProcess.running || focusWorkspaceProcess.running)
            return;

        const targetOutput = String(outputName).trim();
        const currentOutput = String(focusedOutputName).trim();
        const needsMonitorFocus = targetOutput.length > 0
            && targetOutput.toLowerCase() !== currentOutput.toLowerCase();
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

    Connections {
        target: NiriService

        function onEventReceived(event) {
            try {
                root.applyEvent(event);
                root.lastError = "";
            } catch (error) {
                root.lastError = String(error);
                console.error("Could not translate Niri workspace event:", root.lastError, JSON.stringify(event));
            }
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
}
