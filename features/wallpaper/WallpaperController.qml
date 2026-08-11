pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.platform.settings
import qs.platform.theme
import qs.platform.wallpaper
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
    readonly property int largestScreenWidth: {
        let largest = 0;
        for (const screen of Quickshell.screens)
            largest = Math.max(largest, Math.round(screen.width * screen.devicePixelRatio));
        return largest > 0 ? largest : 1920;
    }
    readonly property int largestScreenHeight: {
        let largest = 0;
        for (const screen of Quickshell.screens)
            largest = Math.max(largest, Math.round(screen.height * screen.devicePixelRatio));
        return largest > 0 ? largest : 1080;
    }

    FolderListModel {
        id: wallpaperModel

        folder: root.normalizedFolderUrl(root.currentFolder)
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm", "*.mkv", "*.gif"]
        showDirs: false
        caseSensitive: false
    }

    readonly property url defaultFileFromFolder: wallpaperModel.count > 0 ? wallpaperModel.get(0, "fileUrl") : root.bundledSource
    // Avoid briefly decoding the folder's first entry while persisted settings
    // are still loading. That transient source is especially expensive when it
    // is a video and is never meant to reach the screen.
    readonly property url source: !SettingsService.ready ? root.bundledSource : (WallpaperSettings.selectedFile.length > 0 ? WallpaperSettings.selectedFile : root.defaultFileFromFolder)
    readonly property url playbackSource: {
        if (!WallpaperCacheService.isVideo(root.source))
            return root.source;

        const cachedSource = WallpaperCacheService.playbackSource(root.source);
        return cachedSource.length > 0 ? cachedSource : root.bundledSource;
    }
    property bool initialized: false
    property bool initialVideoReconcilePending: true
    property bool urgentVideoReconcileRequested: false

    readonly property int initialVideoReconcileDelay: 750
    readonly property int normalVideoReconcileDelay: 250
    readonly property int urgentVideoReconcileDelay: 50

    function videoSources(): var {
        const sources = [];
        for (let index = 0; index < wallpaperModel.count; ++index) {
            const source = wallpaperModel.get(index, "fileUrl");
            if (WallpaperCacheService.isVideo(source))
                sources.push(String(source));
        }
        return sources;
    }

    function scheduleWallpaperVideoReconcile(): void {
        if (!root.initialized || wallpaperModel.status !== FolderListModel.Ready)
            return;

        videoReconcileTimer.interval = root.urgentVideoReconcileRequested
            ? root.urgentVideoReconcileDelay
            : (root.initialVideoReconcilePending
                ? root.initialVideoReconcileDelay
                : root.normalVideoReconcileDelay);
        videoReconcileTimer.restart();
    }

    function expediteWallpaperVideoReconcile(): void {
        if (!root.initialVideoReconcilePending && !videoReconcileTimer.running)
            return;

        root.urgentVideoReconcileRequested = true;
        root.scheduleWallpaperVideoReconcile();
    }

    function initialize() {
        if (root.initialized)
            return;

        root.initialized = true;
        MatugenService.request(root.source);
        root.scheduleWallpaperVideoReconcile();
    }

    onSourceChanged: {
        if (root.initialized)
            MatugenService.request(root.source);
        root.scheduleWallpaperVideoReconcile();
    }
    onCurrentFolderChanged: root.scheduleWallpaperVideoReconcile()
    onLargestScreenWidthChanged: root.scheduleWallpaperVideoReconcile()
    onLargestScreenHeightChanged: root.scheduleWallpaperVideoReconcile()

    Timer {
        id: videoReconcileTimer

        interval: root.initialVideoReconcileDelay
        repeat: false
        onTriggered: {
            root.initialVideoReconcilePending = false;
            root.urgentVideoReconcileRequested = false;
            WallpaperCacheService.reconcile(
                root.videoSources(),
                root.largestScreenWidth,
                root.largestScreenHeight,
                root.source
            );
        }
    }

    Connections {
        target: wallpaperModel

        function onCountChanged(): void {
            root.scheduleWallpaperVideoReconcile();
        }

        function onStatusChanged(): void {
            root.scheduleWallpaperVideoReconcile();
        }
    }

    Connections {
        target: MatugenService

        function onGenerated(lightScheme, darkScheme) {
            Theme.setGeneratedSchemes(lightScheme, darkScheme);
        }
    }
}
