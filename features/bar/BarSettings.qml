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
            "showWorkspaceNumbers": {
                type: "bool",
                defaultValue: true,
                label: qsTr("Show Workspace Numbers"),
                description: qsTr("Shows the workspace number pills inside the grouped taskbar."),
                group: "bar",
                order: 15
            },
            "showWorkspaceNumbersOnHover": {
                type: "bool",
                defaultValue: true,
                label: qsTr("Show Workspace Numbers on Hover"),
                description: qsTr("Shows all workspace numbers while hovering over the workspace switcher."),
                group: "bar",
                order: 16
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
    readonly property bool showWorkspaceNumbers: SettingsService.value("bar", "showWorkspaceNumbers")
    readonly property bool showWorkspaceNumbersOnHover: SettingsService.value("bar", "showWorkspaceNumbersOnHover")
    readonly property bool useAppIcons: SettingsService.value("bar", "useAppIcons")

    function setCombineWorkspacesAndWindows(value) {
        return SettingsService.setValue("bar", "combineWorkspacesAndWindows", value);
    }

    function resetCombineWorkspacesAndWindows() {
        return SettingsService.reset("bar", "combineWorkspacesAndWindows");
    }

    function setShowWorkspaceNumbers(value) {
        return SettingsService.setValue("bar", "showWorkspaceNumbers", value);
    }

    function resetShowWorkspaceNumbers() {
        return SettingsService.reset("bar", "showWorkspaceNumbers");
    }

    function setShowWorkspaceNumbersOnHover(value) {
        return SettingsService.setValue("bar", "showWorkspaceNumbersOnHover", value);
    }

    function resetShowWorkspaceNumbersOnHover() {
        return SettingsService.reset("bar", "showWorkspaceNumbersOnHover");
    }

    function setUseAppIcons(value) {
        return SettingsService.setValue("bar", "useAppIcons", value);
    }

    function resetUseAppIcons() {
        return SettingsService.reset("bar", "useAppIcons");
    }
}
