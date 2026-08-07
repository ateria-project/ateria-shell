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
            },
            "useAppIcons": {
                type: "bool",
                defaultValue: true,
                label: qsTr("Use App Icons"),
                description: qsTr("Displays application icons instead of app initials in the window switcher."),
                group: "bar",
                order: 20
            }
        })

    readonly property bool combineWorkspacesAndWindows: SettingsService.value("bar", "combineWorkspacesAndWindows")
    readonly property bool useAppIcons: SettingsService.value("bar", "useAppIcons")

    function setCombineWorkspacesAndWindows(value) {
        return SettingsService.setValue("bar", "combineWorkspacesAndWindows", value);
    }

    function resetCombineWorkspacesAndWindows() {
        return SettingsService.reset("bar", "combineWorkspacesAndWindows");
    }

    function setUseAppIcons(value) {
        return SettingsService.setValue("bar", "useAppIcons", value);
    }

    function resetUseAppIcons() {
        return SettingsService.reset("bar", "useAppIcons");
    }
}
