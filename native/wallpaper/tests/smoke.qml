import QtQuick
import Ateria.Wallpaper

Item {
    Component.onCompleted: {
        WallpaperManager.configure("/tmp/ateria-wallpaper-smoke/video",
                                   "/tmp/ateria-wallpaper-smoke/image")
        if (!WallpaperManager.isVideo("file:///tmp/wallpaper.mp4"))
            throw new Error("video type detection failed")
        if (!WallpaperManager.isImage("file:///tmp/wallpaper.jpg"))
            throw new Error("image type detection failed")
        if (!WallpaperManager.isLocalFile("file:///tmp/wallpaper.jpg"))
            throw new Error("local URL detection failed")
        Qt.quit()
    }
}
