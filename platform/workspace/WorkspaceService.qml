pragma Singleton

import QtQuick
import Quickshell
import "providers"

// The sole owner of canonical workspace state. Compositor providers emit
// normalized changes; consumers only read this service.
Singleton {
    id: root

    // Replace this provider to support another compositor without changing the
    // canonical store, caches, commands, or consumers.
    property var provider: NiriWorkspaceProvider
    property var workspaces: []
    property var windows: []

    readonly property var workspaceIndex: {
        const byOutput = {};
        const activeByOutput = {};
        let focused = null;

        for (const workspace of root.workspaces) {
            const output = String(workspace.output);
            if (!byOutput[output])
                byOutput[output] = [];
            byOutput[output].push(workspace);
            if (workspace.active)
                activeByOutput[output] = workspace;
            if (workspace.focused)
                focused = workspace;
        }

        return {
            "byOutput": byOutput,
            "activeByOutput": activeByOutput,
            "focused": focused
        };
    }
    readonly property var windowsByWorkspace: {
        const grouped = {};
        for (const windowData of root.windows) {
            const workspaceKey = String(Number(windowData.workspaceId));
            if (!grouped[workspaceKey])
                grouped[workspaceKey] = [];
            grouped[workspaceKey].push(windowData);
        }
        for (const workspaceKey in grouped)
            grouped[workspaceKey].sort(root.compareWindows);
        return grouped;
    }
    readonly property var focusedWorkspace: root.workspaceIndex.focused
    readonly property string focusedOutputName: root.focusedWorkspace ? String(root.focusedWorkspace.output) : ""

    property var _viewCache: ({})

    function focusWorkspace(workspaceIndex: int, outputName: string) {
        root.provider?.focusWorkspace(workspaceIndex, outputName, root.focusedOutputName);
    }

    function focusWindow(windowId: double) {
        root.provider?.focusWindow(windowId);
    }

    function patchWorkspace(workspaceId: int, changes) {
        const index = root.workspaces.findIndex(workspace => workspace.id === workspaceId);
        if (index < 0)
            return;

        const workspace = root.workspaces[index];
        if (!Object.keys(changes).some(key => workspace[key] !== changes[key]))
            return;

        const nextWorkspaces = root.workspaces.slice();
        nextWorkspaces[index] = Object.assign({}, workspace, changes);
        root.workspaces = nextWorkspaces;
    }

    function activateWorkspace(workspaceId: int, focused: bool) {
        const target = root.workspaces.find(workspace => workspace.id === workspaceId);
        if (!target)
            return;

        let nextWorkspaces = null;
        for (let index = 0; index < root.workspaces.length; ++index) {
            const workspace = root.workspaces[index];
            const active = workspace.output === target.output ? workspace.id === workspaceId : workspace.active;
            const isFocused = focused ? workspace.id === workspaceId : workspace.focused;
            if (active === workspace.active && isFocused === workspace.focused)
                continue;

            if (nextWorkspaces === null)
                nextWorkspaces = root.workspaces.slice();
            nextWorkspaces[index] = Object.assign({}, workspace, {
                "active": active,
                "focused": isFocused
            });
        }
        if (nextWorkspaces !== null)
            root.workspaces = nextWorkspaces;
    }

    function upsertWindow(windowData) {
        const index = root.windows.findIndex(existing => existing.id === windowData.id);
        let nextWindows = null;

        if (windowData.focused) {
            for (let currentIndex = 0; currentIndex < root.windows.length; ++currentIndex) {
                const existing = root.windows[currentIndex];
                if (existing.id === windowData.id || !existing.focused)
                    continue;
                if (nextWindows === null)
                    nextWindows = root.windows.slice();
                nextWindows[currentIndex] = Object.assign({}, existing, { "focused": false });
            }
        }

        if (index >= 0 && nextWindows === null && root.windowsEqual(root.windows[index], windowData))
            return;

        if (nextWindows === null)
            nextWindows = root.windows.slice();
        if (index < 0)
            nextWindows.push(windowData);
        else
            nextWindows[index] = windowData;
        root.windows = nextWindows;
    }

    function patchWindow(windowId: double, changes) {
        const index = root.windows.findIndex(windowData => windowData.id === windowId);
        if (index < 0)
            return;

        const windowData = root.windows[index];
        if (!Object.keys(changes).some(key => windowData[key] !== changes[key]))
            return;

        const nextWindows = root.windows.slice();
        nextWindows[index] = Object.assign({}, windowData, changes);
        root.windows = nextWindows;
    }

    function focusWindowState(windowId) {
        let nextWindows = null;
        for (let index = 0; index < root.windows.length; ++index) {
            const windowData = root.windows[index];
            const focused = windowId !== null && windowData.id === windowId;
            if (windowData.focused === focused)
                continue;
            if (nextWindows === null)
                nextWindows = root.windows.slice();
            nextWindows[index] = Object.assign({}, windowData, { "focused": focused });
        }
        if (nextWindows !== null)
            root.windows = nextWindows;
    }

    function vectorsEqual(left, right): bool {
        if (left === right)
            return true;
        if (left === null || right === null)
            return false;
        return Number(left[0]) === Number(right[0]) && Number(left[1]) === Number(right[1]);
    }

    function windowsEqual(left, right): bool {
        return left === right || (left !== null && right !== null
            && left.id === right.id
            && left.title === right.title
            && left.appId === right.appId
            && left.workspaceId === right.workspaceId
            && left.focused === right.focused
            && left.floating === right.floating
            && left.urgent === right.urgent
            && root.vectorsEqual(left.layoutPosition, right.layoutPosition)
            && root.vectorsEqual(left.tileSize, right.tileSize));
    }

    function patchWindowLayouts(changes) {
        const indexById = new Map();
        for (let index = 0; index < root.windows.length; ++index)
            indexById.set(root.windows[index].id, index);

        let nextWindows = null;
        for (const change of changes ?? []) {
            const index = indexById.get(Number(change[0]));
            if (index === undefined)
                continue;
            const windowData = root.windows[index];
            const layout = change[1] ?? {};
            const layoutPosition = layout.layoutPosition ?? null;
            const tileSize = layout.tileSize ?? null;
            if (root.vectorsEqual(windowData.layoutPosition, layoutPosition)
                    && root.vectorsEqual(windowData.tileSize, tileSize))
                continue;
            if (nextWindows === null)
                nextWindows = root.windows.slice();
            nextWindows[index] = Object.assign({}, windowData, {
                "layoutPosition": layoutPosition,
                "tileSize": tileSize
            });
        }
        if (nextWindows !== null)
            root.windows = nextWindows;
    }

    function compareWindows(left, right) {
        const leftPosition = left.layoutPosition;
        const rightPosition = right.layoutPosition;
        if (leftPosition === null && rightPosition === null)
            return Number(left.id) - Number(right.id);
        if (leftPosition === null)
            return 1;
        if (rightPosition === null)
            return -1;
        if (Number(leftPosition[0]) !== Number(rightPosition[0]))
            return Number(leftPosition[0]) - Number(rightPosition[0]);
        return Number(leftPosition[1]) - Number(rightPosition[1]);
    }

    function preview(workspace) {
        return Object.assign({}, workspace, {
            "active": false,
            "occupied": false,
            "urgent": false,
            "pagePreview": true
        });
    }

    function viewForOutput(outputName: string, pageSize: int): var {
        const workspaceSource = root.workspaces;
        const windowSource = root.windows;
        const normalizedOutput = String(outputName ?? "");
        const normalizedPageSize = Math.max(1, Number(pageSize));
        const key = normalizedOutput + "|" + normalizedPageSize;
        const cached = root._viewCache[key];
        if (cached
                && cached.workspaceSource === workspaceSource
                && cached.windowSource === windowSource)
            return cached.view;

        const workspaceIndex = root.workspaceIndex;
        const globalWindowsByWorkspace = root.windowsByWorkspace;
        const outputWorkspaces = workspaceIndex.byOutput[normalizedOutput] ?? [];
        const workspaces = outputWorkspaces.length > 0 ? outputWorkspaces : workspaceSource;
        const activeWorkspace = outputWorkspaces.length > 0
            ? workspaceIndex.activeByOutput[normalizedOutput] ?? null
            : workspaces.find(workspace => Boolean(workspace.active)) ?? null;
        const activeWorkspaceId = activeWorkspace ? Number(activeWorkspace.id) : 0;
        const activeWindowId = activeWorkspace ? activeWorkspace.activeWindowId : null;
        const activePosition = activeWorkspace ? workspaces.indexOf(activeWorkspace) : -1;
        const pageStart = activePosition >= 0
            ? Math.floor(activePosition / normalizedPageSize) * normalizedPageSize
            : 0;
        const visibleWorkspaces = workspaces.slice(pageStart, pageStart + normalizedPageSize);

        if (pageStart > 0)
            visibleWorkspaces.unshift(root.preview(workspaces[pageStart - 1]));
        if (workspaces[pageStart + normalizedPageSize])
            visibleWorkspaces.push(root.preview(workspaces[pageStart + normalizedPageSize]));

        const windowsByWorkspace = {};
        for (const workspace of visibleWorkspaces) {
            const workspaceKey = String(Number(workspace.id));
            windowsByWorkspace[workspaceKey] = globalWindowsByWorkspace[workspaceKey] ?? [];
        }

        const visibleWindows = windowsByWorkspace[String(activeWorkspaceId)] ?? [];
        const view = {
            "activeWorkspace": activeWorkspace,
            "activeWorkspaceId": activeWorkspaceId,
            "activeWorkspacePosition": activePosition < 0
                ? -1
                : activePosition - pageStart + (pageStart > 0 ? 1 : 0),
            "activeWindowId": activeWindowId,
            "activeVisibleWindowPosition": activeWindowId === null || activeWindowId === undefined
                ? -1
                : visibleWindows.findIndex(windowData => Number(windowData.id) === Number(activeWindowId)),
            "visibleWindows": visibleWindows,
            "visibleWorkspaces": visibleWorkspaces,
            "windowsByWorkspace": windowsByWorkspace
        };

        root._viewCache[key] = {
            "workspaceSource": workspaceSource,
            "windowSource": windowSource,
            "view": view
        };
        return view;
    }

    onProviderChanged: {
        root.workspaces = [];
        root.windows = [];
        root._viewCache = {};
    }

    Connections {
        target: root.provider
        ignoreUnknownSignals: true

        function onWorkspacesReset(workspaces) {
            root.workspaces = workspaces ?? [];
        }

        function onWorkspaceActivated(workspaceId, focused) {
            root.activateWorkspace(workspaceId, focused);
        }

        function onWorkspacePatched(workspaceId, changes) {
            root.patchWorkspace(workspaceId, changes);
        }

        function onWindowsReset(windows) {
            root.windows = windows ?? [];
        }

        function onWindowUpserted(windowData) {
            root.upsertWindow(windowData);
        }

        function onWindowRemoved(windowId) {
            const nextWindows = root.windows.filter(windowData => windowData.id !== windowId);
            if (nextWindows.length !== root.windows.length)
                root.windows = nextWindows;
        }

        function onWindowFocused(windowId) {
            root.focusWindowState(windowId);
        }

        function onWindowPatched(windowId, changes) {
            root.patchWindow(windowId, changes);
        }

        function onWindowLayoutsPatched(changes) {
            root.patchWindowLayouts(changes);
        }
    }
}
