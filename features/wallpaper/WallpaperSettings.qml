pragma Singleton

import QtQuick
import QtCore
import qs.platform.settings

QtObject {
    id: root

    readonly property string defaultFolder: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.PicturesLocation)).replace(/^file:\/\//, "")) + "/Wallpaper/"

    readonly property var schema: ({
            "wallpaper.folder": {
                type: "string",
                defaultValue: root.defaultFolder,
                label: qsTr("Wallpaper folder"),
                description: qsTr("The folder shown when choosing a wallpaper."),
                group: "general",
                order: 10
            },
            "wallpaper.selectedFile": {
                type: "string",
                defaultValue: "",
                label: qsTr("Wallpaper"),
                description: qsTr("The image file used as the wallpaper."),
                group: "general",
                order: 20
            }
        })

    readonly property string folder: SettingsService.value("wallpaper.folder")
    readonly property string selectedFile: SettingsService.value("wallpaper.selectedFile")

    function setFolder(folder) {
        return SettingsService.setValue("wallpaper.folder", folder);
    }

    function setSelectedFile(filePath) {
        return SettingsService.setValue("wallpaper.selectedFile", filePath);
    }

    function clearSelectedFile() {
        return SettingsService.reset("wallpaper.selectedFile");
    }
}
