import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property url source: WallpaperController.source

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
