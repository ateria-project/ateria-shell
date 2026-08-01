pragma Singleton

import QtQuick
import qs.platform.settings

QtObject {
    readonly property var schema: ({
            "example.enabled": {
                type: "bool",
                defaultValue: false,
                label: qsTr("Enabled"),
                description: qsTr("Enables the example feature."),
                group: "general",
                order: 10
            },
            "example.mode": {
                type: "enum",
                defaultValue: "default",
                options: ["default", "alternative"],
                label: qsTr("Mode"),
                description: qsTr("Selects the example operating mode."),
                group: "general",
                order: 20
            }
        })

    readonly property bool enabled: SettingsService.value("example.enabled")
    readonly property string mode: SettingsService.value("example.mode")

    function setEnabled(value) {
        return SettingsService.setValue("example.enabled", value);
    }

    function setMode(value) {
        return SettingsService.setValue("example.mode", value);
    }

    function resetEnabled() {
        return SettingsService.reset("example.enabled");
    }

    function resetMode() {
        return SettingsService.reset("example.mode");
    }
}
