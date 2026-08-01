import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.platform.settings

PanelWindow {
    id: root

    readonly property url bundledSource: Quickshell.shellPath("assets/sora-sagano-Dksk8szLRN0-unsplash.jpg")
    property url source: SettingsService.ready && WallpaperSettings.selectedFile.length > 0 ? WallpaperSettings.selectedFile : root.bundledSource

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Background

    Image {
        id: wallpaperImage

        anchors.fill: parent

        source: root.source
        fillMode: Image.PreserveAspectCrop

        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
    }
}
