pragma Singleton

import QtQuick
import Quickshell
import Ateria.Wallpaper
import qs.platform.power

Singleton {
    id: root

    readonly property string cachePath: Quickshell.cachePath("video-wallpapers")
    readonly property string imageCachePath: Quickshell.cachePath("image-wallpapers")
    readonly property bool busy: WallpaperManager.busy
    readonly property bool hardwareAvailable: WallpaperManager.hardwareAvailable
    readonly property bool canTranscode: WallpaperManager.canTranscode
    readonly property var knownSources: WallpaperManager.knownSources
    readonly property string preferredSource: WallpaperManager.preferredSource
    readonly property int revision: WallpaperManager.revision

    function configureNativeService(): void {
        WallpaperManager.configure(root.cachePath, root.imageCachePath);
        WallpaperManager.setPowerState(PowerService.powerSaver, PowerService.onBattery);
    }

    function localPath(source): string {
        return WallpaperManager.localPath(String(source ?? ""));
    }

    function isVideo(source): bool {
        return WallpaperManager.isVideo(String(source ?? ""));
    }

    function isImage(source): bool {
        return WallpaperManager.isImage(String(source ?? ""));
    }

    function isLocalFile(source): bool {
        return WallpaperManager.isLocalFile(String(source ?? ""));
    }

    function imagePlaybackSource(source): string {
        // revision makes native per-entry updates observable without cloning
        // the complete cache map into the QML engine.
        root.revision;
        return WallpaperManager.imagePlaybackSource(String(source ?? ""));
    }

    function prepareImage(source, width, height): void {
        WallpaperManager.prepareImage(String(source ?? ""),
                                      Math.max(1, Math.round(Number(width) || 1920)),
                                      Math.max(1, Math.round(Number(height) || 1080)));
    }

    function entryFor(source): var {
        root.revision;
        const entry = WallpaperManager.entryFor(String(source ?? ""));
        return entry.status === undefined ? null : entry;
    }

    function isSelectable(source): bool {
        root.revision;
        return WallpaperManager.isSelectable(String(source ?? ""));
    }

    function playbackSource(source): string {
        root.revision;
        return WallpaperManager.playbackSource(String(source ?? ""));
    }

    function statusText(source): string {
        const entry = root.entryFor(source);
        if (entry === null)
            return qsTr("Checking video");

        switch (entry.status) {
        case "queued":
            if (PowerService.powerSaver)
                return qsTr("Waiting for balanced power mode");
            if (PowerService.onBattery && String(source) !== root.preferredSource)
                return qsTr("Waiting for external power");
            return qsTr("Queued for conversion");
        case "converting":
            return qsTr("Converting %1%").arg(Math.round(entry.progress * 100));
        case "invalid":
            return qsTr("Video cannot be prepared");
        case "failed":
            return qsTr("Conversion failed");
        default:
            return "";
        }
    }

    function reconcile(sources, width, height, preferredSource, forceRebuild): void {
        WallpaperManager.reconcile(sources ?? [],
                                   Math.max(2, Math.round(Number(width) || 1920)),
                                   Math.max(2, Math.round(Number(height) || 1080)),
                                   String(preferredSource ?? ""),
                                   forceRebuild === true);
    }

    function rebuild(): void {
        WallpaperManager.rebuild();
    }

    function expeditePendingWork(): void {
        WallpaperManager.expeditePendingWork();
    }

    Component.onCompleted: root.configureNativeService()

    Connections {
        target: PowerService

        function onPowerSaverChanged(): void {
            WallpaperManager.setPowerState(PowerService.powerSaver, PowerService.onBattery);
        }

        function onOnBatteryChanged(): void {
            WallpaperManager.setPowerState(PowerService.powerSaver, PowerService.onBattery);
        }
    }
}
