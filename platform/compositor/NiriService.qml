pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Niri transport only. Feature-specific providers consume the raw event stream
// and translate it into their own compositor-independent contracts.
Singleton {
    id: root

    readonly property bool available: root.connected
    property bool connected: false
    property string lastError: ""
    property int reconnectDelay: 1000
    property int currentReconnectDelay: 1000
    property int maxReconnectDelay: 5000

    signal eventReceived(var event)
    signal eventParseFailed(string line, string message)

    function handleEventLine(line: string) {
        const trimmedLine = String(line).trim();
        if (trimmedLine.length === 0)
            return;

        try {
            const event = JSON.parse(trimmedLine);
            root.connected = true;
            root.lastError = "";
            root.currentReconnectDelay = root.reconnectDelay;
            root.eventReceived(event);
        } catch (error) {
            const message = String(error);
            root.lastError = message;
            root.eventParseFailed(trimmedLine, message);
            console.warn("Could not parse Niri event:", message, trimmedLine);
        }
    }

    function handleStreamError(data) {
        const message = String(data).trim();
        if (message.length === 0)
            return;

        root.lastError = message;
        console.warn("Niri event stream:", message);
    }

    function quit() {
        if (!quitProcess.running)
            quitProcess.exec(["niri", "msg", "action", "quit", "--skip-confirmation"]);
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
            onRead: data => root.handleEventLine(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleStreamError(data)
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
        id: quitProcess
    }
}
