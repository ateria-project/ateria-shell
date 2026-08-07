pragma Singleton

import QtQuick
import qs.platform.settings

QtObject {
    readonly property var schema: ({
            "combineWorkspacesAndWindows": {
                type: "bool",
                defaultValue: false,
                label: qsTr("Combine Workspaces and Windows"),
                description: qsTr("Groups windows together with their workspace indicators on the taskbar."),
                group: "bar",
                order: 10
            }
        })

    readonly property bool combineWorkspacesAndWindows: SettingsService.value("bar", "combineWorkspacesAndWindows")

    function setCombineWorkspacesAndWindows(value) {
        return SettingsService.setValue("bar", "combineWorkspacesAndWindows", value);
    }

    function resetCombineWorkspacesAndWindows() {
        return SettingsService.reset("bar", "combineWorkspacesAndWindows");
    }
}
