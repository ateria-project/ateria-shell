import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property var modelData

        screen: modelData
        implicitHeight: 38
        color: Theme.scheme.surface

        anchors {
            top: true
            left: true
            right: true
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6

            WorkspacesWidget {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                workspaces: {
                    const filtered = NiriService.workspaces.filter(w => {
                        return w.output === window.screen.name;
                    });
                    return filtered.length > 0 ? filtered : NiriService.workspaces;
                }
                onWorkspaceRequested: workspaceIndex => {
                    NiriService.focusWorkspace(workspaceIndex, window.screen.name);
                }
            }

            ClockWidget {
                anchors.centerIn: parent
            }
        }
    }
}
