import QtQuick
import Quickshell
import qs.components
import qs.core
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property var modelData

        readonly property string outputName: window.modelData.name

        readonly property int workspacePageSize: 9
        readonly property var visibleWorkspaces: {
            const allWorkspaces = NiriService.workspaces ?? [];

            const outputWorkspaces = allWorkspaces.filter(workspace => workspace.output === window.outputName);

            const workspaces = outputWorkspaces.length > 0 ? outputWorkspaces : allWorkspaces;

            const activePosition = workspaces.findIndex(workspace => Boolean(workspace.active));

            const page = activePosition >= 0 ? Math.floor(activePosition / window.workspacePageSize) : 0;

            const pageStart = page * window.workspacePageSize;

            // Nine normal workspaces
            const pageWorkspaces = workspaces.slice(pageStart, pageStart + window.workspacePageSize);

            // Tenth workspace acts as a preview of the next page
            const previewWorkspace = workspaces[pageStart + window.workspacePageSize];

            if (previewWorkspace) {
                pageWorkspaces.push(Object.assign({}, previewWorkspace, {
                    active: false,
                    occupied: false,
                    urgent: false,
                    pagePreview: true
                }));
            }

            return pageWorkspaces;
        }

        screen: window.modelData
        implicitHeight: 38
        color: Theme.scheme.surface

        anchors {
            top: true
            left: true
            right: true
        }

        WorkspacesWidget {
            anchors {
                left: parent.left
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }

            workspaces: window.visibleWorkspaces

            onWorkspaceRequested: workspaceIndex => NiriService.focusWorkspace(workspaceIndex, window.outputName)
        }

        ClockWidget {
            anchors.centerIn: parent
        }
    }
}
