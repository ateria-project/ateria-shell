pragma Singleton

import QtQuick
import qs.platform.settings

QtObject {
    readonly property var schema: ({
            "doNotDisturb": {
                type: "bool",
                defaultValue: false,
                label: qsTr("Do Not Disturb"),
                description: qsTr("Silences notification popups while keeping notifications in the notification center."),
                group: "notifications",
                order: 10
            }
        })

    readonly property bool doNotDisturb: SettingsService.value("notifications", "doNotDisturb")

    function setDoNotDisturb(value) {
        return SettingsService.setValue("notifications", "doNotDisturb", value);
    }

    function resetDoNotDisturb() {
        return SettingsService.reset("notifications", "doNotDisturb");
    }
}
