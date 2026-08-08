pragma Singleton

import QtQuick
import Quickshell
import qs.platform.settings
import qs.platform.theme
import qs.theme

Singleton {
    id: root

    readonly property url bundledSource: Quickshell.shellPath("assets/sora-sagano-Dksk8szLRN0-unsplash.jpg")
    readonly property url source: SettingsService.ready && WallpaperSettings.selectedFile.length > 0 ? WallpaperSettings.selectedFile : root.bundledSource
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
