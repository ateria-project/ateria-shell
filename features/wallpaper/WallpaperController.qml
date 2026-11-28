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
        if (WallpaperCacheService.isImage(root.source) && WallpaperCacheService.isLocalFile(root.source)) {
            const cachedImage = WallpaperCacheService.imagePlaybackSource(root.source);
            // Never decode an oversized original just to replace it with the
            // display-sized cache moments later. An empty pending source keeps
            // the previous wallpaper active, or the window's black background
            // during first startup.
            return cachedImage.length > 0 ? cachedImage : "";
        }
        if (!WallpaperCacheService.isVideo(root.source))
            return root.source;

        const cachedSource = WallpaperCacheService.playbackSource(root.source);
        return cachedSource.length > 0 ? cachedSource : "";
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

    function requestMatugen(): void {
        if (!root.initialized || !SettingsService.ready)
            return;
        // Without an explicit selection, wait for the folder model rather than
        // generating a palette for the bundled placeholder or a transient entry.
        if (WallpaperSettings.selectedFile.length === 0
                && wallpaperModel.status !== FolderListModel.Ready)
            return;

        MatugenService.request(root.source);
    }

    function initialize() {
        if (root.initialized)
            return;

        root.initialized = true;
        root.requestMatugen();
        root.prepareCurrentImage();
        root.scheduleWallpaperVideoReconcile();
    }

    function prepareCurrentImage(): void {
        if (!root.initialized || !SettingsService.ready)
            return;
        // With no explicit selection, wait until the folder model has either
        // produced its first wallpaper or confirmed that the bundled fallback
        // is genuinely needed. This avoids preparing a transient fallback.
        if (WallpaperSettings.selectedFile.length === 0
                && wallpaperModel.status !== FolderListModel.Ready)
            return;

        WallpaperCacheService.prepareImage(root.source, root.largestScreenWidth, root.largestScreenHeight);
    }

    onSourceChanged: {
        root.requestMatugen();
        root.prepareCurrentImage();
        root.scheduleWallpaperVideoReconcile();
    }
    onCurrentFolderChanged: root.scheduleWallpaperVideoReconcile()
    onLargestScreenWidthChanged: {
        root.prepareCurrentImage();
        root.scheduleWallpaperVideoReconcile();
    }
    onLargestScreenHeightChanged: {
        root.prepareCurrentImage();
        root.scheduleWallpaperVideoReconcile();
    }

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
        target: SettingsService

        function onReadyChanged(): void {
            if (!SettingsService.ready)
                return;

            // Initialize deliberately skipped the bundled placeholder source.
            // Start from the real selection once it has been loaded.
            root.requestMatugen();
            root.prepareCurrentImage();
        }
    }

    Connections {
        target: wallpaperModel

        function onCountChanged(): void {
            root.prepareCurrentImage();
            root.scheduleWallpaperVideoReconcile();
        }

        function onStatusChanged(): void {
            root.requestMatugen();
            root.prepareCurrentImage();
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
