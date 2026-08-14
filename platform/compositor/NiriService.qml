pragma Singleton

import QtQuick
import Ateria.Niri
import Quickshell

// Niri transport only. Feature-specific providers consume the raw event stream
// and translate it into their own compositor-independent contracts.
Singleton {
    id: root

    readonly property bool available: NiriIpc.available
    readonly property bool connected: NiriIpc.connected
    readonly property string lastError: NiriIpc.lastError

    signal eventReceived(var event)
    signal eventParseFailed(string line, string message)
    signal actionFailed(string action, string message)

    function focusWorkspace(workspaceIndex: int, outputName: string, focusedOutputName: string): bool {
        return NiriIpc.focusWorkspace(workspaceIndex, outputName, focusedOutputName);
    }

    function focusWindow(windowId: double): bool {
        return NiriIpc.focusWindow(windowId);
    }

    function quit() {
        NiriIpc.quit(true);
    }

    Component.onCompleted: NiriIpc.initialize()

    Connections {
        target: NiriIpc

        function onEventReceived(event) {
            root.eventReceived(event);
        }

        function onEventParseFailed(line, message) {
            console.warn("Could not parse Niri event:", message, line);
            root.eventParseFailed(line, message);
        }

        function onActionFailed(action, message) {
            console.warn("Niri action failed:", action, message);
            root.actionFailed(action, message);
        }
    }
}
