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
        readonly property var visibleWorkspaces: {
            const allWorkspaces = NiriService.workspaces;
            const filteredWorkspaces = allWorkspaces.filter(workspace => workspace.output === window.outputName);

            return filteredWorkspaces.length > 0 ? filteredWorkspaces : allWorkspaces;
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
