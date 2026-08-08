pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.platform.settings
import qs.platform.theme
import qs.theme

Singleton {
    id: root

    function normalizedFolderUrl(path): string {
        const value = String(path || "");
        if (value.length === 0)
            return "";

        if (value.startsWith("file:") || value.startsWith("qrc:") || !value.startsWith("/"))
            return value;

        return "file://" + value;
    }

    readonly property string currentFolder: WallpaperSettings.folder.length > 0 ? WallpaperSettings.folder : WallpaperSettings.defaultFolder
    readonly property url bundledSource: Quickshell.shellPath("assets/sora-sagano-Dksk8szLRN0-unsplash.jpg")
    readonly property alias wallpapers: wallpaperModel

    FolderListModel {
        id: wallpaperModel

        folder: root.normalizedFolderUrl(root.currentFolder)
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm", "*.mkv", "*.gif"]
        showDirs: false
        caseSensitive: false
    }

    readonly property url defaultFileFromFolder: wallpaperModel.count > 0 ? wallpaperModel.get(0, "fileUrl") : root.bundledSource
    readonly property url source: SettingsService.ready && WallpaperSettings.selectedFile.length > 0 ? WallpaperSettings.selectedFile : root.defaultFileFromFolder
    property bool initialized: false

    function initialize() {
        if (root.initialized)
            return;

        root.initialized = true;
        MatugenService.request(root.source);
    }

    onSourceChanged: {
        if (root.initialized)
            MatugenService.request(root.source);
    }

    Connections {
        target: MatugenService

        function onGenerated(lightScheme, darkScheme) {
            Theme.setGeneratedSchemes(lightScheme, darkScheme);
        }
    }
}
