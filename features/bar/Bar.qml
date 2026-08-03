import QtQuick
import Quickshell
import qs.components
import qs.features.notifications.components
import qs.platform.compositor
import qs.shell
import qs.theme

PanelWindow {
    id: window

    readonly property string outputName: window.screen ? window.screen.name : ""
    readonly property int workspacePageSize: 9
    readonly property var activeWorkspace: {
        const workspace = (NiriService.workspaces ?? []).find(workspace => {
            return workspace.output === window.outputName && Boolean(workspace.active);
        });
        return workspace ?? null;
    }
    readonly property int activeWorkspaceId: window.activeWorkspace ? Number(window.activeWorkspace.id) : 0
    readonly property var activeWindowId: window.activeWorkspace ? window.activeWorkspace.activeWindowId : null
    readonly property var visibleWindows: {
        const workspaceId = window.activeWorkspaceId;
        if (workspaceId < 1)
            return [];

        return (NiriService.windows ?? []).filter(appWindow => {
            return Number(appWindow.workspaceId) === workspaceId;
        }).sort((left, right) => {
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
        });
    }
    readonly property var visibleWorkspaces: {
        const allWorkspaces = NiriService.workspaces ?? [];
        const outputWorkspaces = allWorkspaces.filter(workspace => {
            return workspace.output === window.outputName;
        });
        const workspaces = outputWorkspaces.length > 0 ? outputWorkspaces : allWorkspaces;
        const activePosition = workspaces.findIndex(workspace => {
            return Boolean(workspace.active);
        });
        const page = activePosition >= 0 ? Math.floor(activePosition / window.workspacePageSize) : 0;
        const pageStart = page * window.workspacePageSize;
        const result = [];
        // Previous-page preview.
        if (pageStart > 0)
            result.push(preview(workspaces[pageStart - 1]));

        // Nine real workspaces on the current page.
        const currentPage = workspaces.slice(pageStart, pageStart + window.workspacePageSize);
        for (const workspace of currentPage)
            result.push(workspace);
        // Next-page preview.
        const nextWorkspace = workspaces[pageStart + window.workspacePageSize];
        if (nextWorkspace)
            result.push(preview(nextWorkspace));

        return result;
    }

    function preview(workspace) {
        return Object.assign({}, workspace, {
            "active": false,
            "occupied": false,
            "urgent": false,
            "pagePreview": true
        });
    }

    implicitHeight: 38
    color: Theme.scheme.surface

    anchors {
        top: true
        left: true
        right: true
    }

    Row {
        spacing: Metrics.spacingXs

        anchors {
            left: parent.left
            leftMargin: 6
            verticalCenter: parent.verticalCenter
        }

        WorkspacesWidget {
            workspaces: window.visibleWorkspaces
            onWorkspaceRequested: workspaceIndex => {
                return NiriService.focusWorkspace(workspaceIndex, window.outputName);
            }
        }

        WindowsWidget {
            windows: window.visibleWindows
            activeWindowId: window.activeWindowId
            useAppIcons: false
            onWindowRequested: windowId => {
                return NiriService.focusWindow(windowId);
            }
        }
    }

    ClockWidget {
        anchors.centerIn: parent
        screen: window.screen
    }

    Row {
        spacing: Metrics.spacingXs

        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }

        MediaWidget {
            anchors.verticalCenter: parent.verticalCenter
        }

        NotificationIndicator {
            anchors.verticalCenter: parent.verticalCenter
            screen: window.screen
        }

        StatusArea {
            anchors.verticalCenter: parent.verticalCenter
            screen: window.screen
            hasBattery: true
        }
    }
}
