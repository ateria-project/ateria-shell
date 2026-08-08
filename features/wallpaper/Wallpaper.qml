pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.platform.power
import qs.platform.workspace

PanelWindow {
    id: root

    property url source: WallpaperController.source
    property bool isMedia1Active: true
    property bool transitionPending: false
    property bool videoLoading: false
    property bool blurTransition: false
    property int currentGroupIndex: 0
    property string currentShader: shaderGroups[0][0]
    readonly property string outputName: root.screen ? root.screen.name : ""
    readonly property var workspaceView: WorkspaceService.viewForOutput(root.outputName, 1)
    readonly property var activeWorkspaceWindow: {
        const activeWindowId = root.workspaceView?.activeWindowId;
        if (activeWindowId === null || activeWindowId === undefined)
            return null;
        return (root.workspaceView?.visibleWindows ?? []).find(windowData =>
            Number(windowData.id) === Number(activeWindowId)) ?? null;
    }
    readonly property bool hasCoveringWindows: {
        if (root.width <= 0)
            return false;

        const activeWindow = root.activeWorkspaceWindow;
        const coverageTarget = root.width * 0.9;
        const activeWidth = Number(activeWindow?.tileSize?.[0] ?? 0);
        if (activeWidth >= coverageTarget)
            return true;

        // Windows stacked vertically share a Niri column. Count that column's
        // width once, then combine distinct columns to estimate screen cover.
        const columnWidths = {};
        let coveredWidth = 0;
        for (const windowData of root.workspaceView?.visibleWindows ?? []) {
            if (windowData.floating || !windowData.layoutPosition)
                continue;

            const column = String(Number(windowData.layoutPosition[0]));
            const previousWidth = Number(columnWidths[column] ?? 0);
            const width = Number(windowData.tileSize?.[0] ?? 0);
            if (width <= previousWidth)
                continue;

            columnWidths[column] = width;
            coveredWidth += width - previousWidth;
            if (coveredWidth >= coverageTarget)
                return true;
        }
        return false;
    }
    readonly property bool videoPlaybackSuppressed: PowerService.powerSaver || root.hasCoveringWindows
    readonly property var shaderGroups: [
        // Circle reveals
        ["shaders/circle_reveal.frag.qsb", "shaders/circle_reveal_center.frag.qsb", "shaders/circle_reveal_top.frag.qsb", "shaders/circle_reveal_corner.frag.qsb", "shaders/circle_reveal_bl.frag.qsb", "shaders/circle_reveal_br.frag.qsb", "shaders/circle_reveal_tr.frag.qsb", "shaders/circle_reveal_outer.frag.qsb", "shaders/circle_reveal_ring.frag.qsb"],
        // Diamonds
        ["shaders/diamond.frag.qsb", "shaders/diamond_bl.frag.qsb", "shaders/diamond_outer.frag.qsb", "shaders/diamond_tr.frag.qsb", "shaders/diamond_tl.frag.qsb", "shaders/diamond_br.frag.qsb"],
        // Clock sweeps
        ["shaders/clock_wipe.frag.qsb", "shaders/clock_wipe_ccw.frag.qsb", "shaders/clock_wipe_both.frag.qsb"],
        // Wipes
        ["shaders/wipe.frag.qsb", "shaders/wipe_tr_bl.frag.qsb", "shaders/wipe_bl_tr.frag.qsb", "shaders/wipe_br_tl.frag.qsb", "shaders/scanline_wipe.frag.qsb"],
        // Waves
        ["shaders/wave.frag.qsb", "shaders/wave_down.frag.qsb", "shaders/wave_up.frag.qsb", "shaders/wave_dual.frag.qsb"],
        // Tiles
        ["shaders/squares.frag.qsb", "shaders/squares_spiral.frag.qsb", "shaders/squares_checker.frag.qsb"],
        // Shapes
        ["shaders/star.frag.qsb", "shaders/sparkle_star.frag.qsb", "shaders/triangle.frag.qsb"],
        // Hexagons
        ["shaders/hexagons.frag.qsb", "shaders/hexagons_spiral.frag.qsb"],
        // Retro
        ["shaders/tv_off.frag.qsb", "shaders/tv_on.frag.qsb"],
        // Radial fans
        ["shaders/radial_fan.frag.qsb", "shaders/radial_fan_double.frag.qsb"],
        // Page curls
        ["shaders/page_curl.frag.qsb", "shaders/page_curl_tl.frag.qsb", "shaders/page_curl_br.frag.qsb"]
    ]

    function pickNextShader() {
        const group = shaderGroups[currentGroupIndex];
        const variantIndex = Math.floor(Math.random() * group.length);
        currentShader = group[variantIndex];
        currentGroupIndex = (currentGroupIndex + 1) % shaderGroups.length;
    }

    function activeMedia(): WallpaperMedia {
        return root.isMedia1Active ? media1 : media2;
    }

    function inactiveMedia(): WallpaperMedia {
        return root.isMedia1Active ? media2 : media1;
    }

    function isVideoSource(source): bool {
        return /\.(mp4|webm|mkv|gif)$/i.test(String(source));
    }

    function reconcileVideoPlayback(): void {
        if (root.videoPlaybackSuppressed) {
            // Do not stop a newly selected video before its first frame. It
            // must finish warming up so the pending transition can proceed.
            if (media1.firstVideoFrameReady)
                media1.pauseVideo();
            if (media2.firstVideoFrameReady)
                media2.pauseVideo();
            return;
        }

        // Loading deliberately keeps the outgoing wallpaper paused. During a
        // shader transition only the incoming wallpaper should be moving.
        if (root.videoLoading)
            return;
        if (shaderEffect.visible) {
            root.inactiveMedia().playVideo();
            return;
        }

        root.activeMedia().resumeVideo();
    }

    function startVideoLoading(): void {
        root.transitionPending = true;
        root.videoLoading = true;
        root.blurTransition = false;
        root.activeMedia().pauseVideo();
        root.inactiveMedia().source = "";

        loadingBlur.visible = true;
        if (loadingBlur.opacity >= 0.99) {
            root.loadPendingVideo();
            return;
        }

        blurInAnim.from = loadingBlur.opacity;
        blurInAnim.restart();
    }

    function loadPendingVideo(): void {
        if (!root.videoLoading)
            return;

        const next = root.inactiveMedia();
        if (String(next.source) !== String(root.source))
            next.source = root.source;
        if (next.ready)
            root.beginTransition();
    }

    function clearLoadingBlur(): void {
        blurInAnim.stop();
        loadingBlur.opacity = 0;
        loadingBlur.visible = false;
    }

    function cancelVideoLoading(resumeActive): void {
        root.videoLoading = false;
        root.blurTransition = false;
        root.clearLoadingBlur();
        if (resumeActive)
            root.activeMedia().resumeVideo();
    }

    function beginTransition(): void {
        const next = root.inactiveMedia();
        if (!root.transitionPending || !next.ready || String(next.source) !== String(root.source))
            return;

        if (root.videoLoading) {
            // Start the prepared video, then run the shader while the loading
            // blur remains in place beneath it.
            next.playVideo();
            root.videoLoading = false;
            root.blurTransition = true;
            root.startShaderTransition();
            return;
        }

        root.startShaderTransition();
    }

    function startShaderTransition(): void {
        const active = root.activeMedia();
        const next = root.inactiveMedia();
        if (!root.transitionPending || !next.ready || String(next.source) !== String(root.source))
            return;

        // Keep the outgoing side static. A prepared incoming video can run
        // immediately, so only one shader source needs a live texture.
        root.transitionPending = false;
        active.pauseVideo();
        next.playVideo();
        root.pickNextShader();
        shaderEffect.progress = 0;
        shaderEffect.visible = true;
        src1.scheduleUpdate();
        src2.scheduleUpdate();
        transitionStartTimer.restart();
    }

    function finishTransition(): void {
        transitionStartTimer.stop();
        transitionAnim.stop();

        // The blur was used only as the shader's old-wallpaper input. Remove
        // it atomically before exposing the completed wallpaper directly.
        root.clearLoadingBlur();
        root.blurTransition = false;

        root.isMedia1Active = !root.isMedia1Active;
        shaderEffect.progress = 0;
        shaderEffect.visible = false;

        const active = root.activeMedia();
        const inactive = root.inactiveMedia();
        inactive.source = "";
        active.resumeVideo();
    }

    color: "transparent"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Background
    Component.onCompleted: {
        currentGroupIndex = Math.floor(Math.random() * shaderGroups.length);
        pickNextShader();
    }
    onSourceChanged: {
        let active = root.activeMedia();

        // Settle on the previous target before accepting another rapid change.
        if (shaderEffect.visible) {
            root.finishTransition();
            active = root.activeMedia();
        }

        if (String(active.source) === "") {
            active.source = root.source;
            return;
        }

        if (String(active.source) === String(root.source)) {
            root.transitionPending = false;
            root.cancelVideoLoading(true);
            root.inactiveMedia().source = "";
            return;
        }

        if (root.isVideoSource(root.source)) {
            root.startVideoLoading();
            return;
        }

        root.cancelVideoLoading(true);
        const next = root.inactiveMedia();
        root.transitionPending = true;
        if (String(next.source) !== String(root.source)) {
            next.source = root.source;
        }
        if (next.ready)
            root.beginTransition();
    }
    onVideoPlaybackSuppressedChanged: root.reconcileVideoPlayback()

    function handleMediaStatus(media: WallpaperMedia, isReady: bool): void {
        const next = root.inactiveMedia();
        if (media !== next || String(media.source) !== String(root.source))
            return;

        if (isReady)
            root.beginTransition();
        else {
            root.transitionPending = false;
            root.cancelVideoLoading(true);
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    component WallpaperMedia : Item {
        id: mediaRoot

        property url source: ""
        property bool active: false
        property bool firstVideoFrameReady: false
        readonly property bool isVideo: root.isVideoSource(source)
        readonly property bool ready: isVideo ? firstVideoFrameReady : img.status === Image.Ready
        readonly property bool error: isVideo ? player.mediaStatus === MediaPlayer.InvalidMedia : img.status === Image.Error

        function pauseVideo(): void {
            if (mediaRoot.isVideo && player.playbackState === MediaPlayer.PlayingState)
                player.pause();
        }

        function playVideo(): void {
            if (!mediaRoot.isVideo || !mediaRoot.firstVideoFrameReady)
                return;
            if (root.videoPlaybackSuppressed) {
                mediaRoot.pauseVideo();
                return;
            }
            if (player.playbackState !== MediaPlayer.PlayingState)
                player.play();
        }

        function resumeVideo(): void {
            if (mediaRoot.active)
                mediaRoot.playVideo();
        }

        onSourceChanged: firstVideoFrameReady = false
        onActiveChanged: {
            if (active)
                resumeVideo();
            else
                pauseVideo();
        }

        onReadyChanged: {
            if (ready)
                mediaRoot.statusChanged(true);
        }
        onErrorChanged: {
            if (error)
                mediaRoot.statusChanged(false);
        }
        signal statusChanged(bool isReady)

        Image {
            id: img
            anchors.fill: parent
            source: mediaRoot.isVideo ? "" : mediaRoot.source
            visible: !mediaRoot.isVideo
            sourceSize: Qt.size(mediaRoot.width, mediaRoot.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        MediaPlayer {
            id: player
            source: mediaRoot.isVideo ? mediaRoot.source : ""
            videoOutput: videoOut
            loops: MediaPlayer.Infinite
            autoPlay: mediaRoot.isVideo
        }

        VideoOutput {
            id: videoOut
            anchors.fill: parent
            visible: mediaRoot.isVideo && mediaRoot.firstVideoFrameReady
            fillMode: VideoOutput.PreserveAspectCrop
        }

        Connections {
            target: videoOut.videoSink

            function onVideoFrameChanged(): void {
                if (!mediaRoot.isVideo || !player.hasVideo || mediaRoot.firstVideoFrameReady)
                    return;

                // The decoder is warm and VideoOutput owns a renderable frame.
                // Readiness immediately advances a pending transition, so the
                // incoming video can keep playing without pause/play churn.
                mediaRoot.firstVideoFrameReady = true;
                if (root.videoPlaybackSuppressed)
                    mediaRoot.pauseVideo();
            }
        }
    }

    WallpaperMedia {
        id: media1
        anchors.fill: parent
        active: root.isMedia1Active
        z: active ? 0 : (shaderEffect.visible ? 2 : -1)
        onStatusChanged: isReady => root.handleMediaStatus(media1, isReady)
    }

    WallpaperMedia {
        id: media2
        anchors.fill: parent
        active: !root.isMedia1Active
        z: active ? 0 : (shaderEffect.visible ? 2 : -1)
        onStatusChanged: isReady => root.handleMediaStatus(media2, isReady)
    }

    ShaderEffectSource {
        id: src1
        sourceItem: media1
        hideSource: shaderEffect.visible
        live: shaderEffect.visible && media1.isVideo && media1 === root.inactiveMedia()
    }

    ShaderEffectSource {
        id: src2
        sourceItem: media2
        hideSource: shaderEffect.visible
        live: shaderEffect.visible && media2.isVideo && media2 === root.inactiveMedia()
    }

    ShaderEffect {
        id: shaderEffect

        property variant source1: root.blurTransition ? loadingBlur : (root.isMedia1Active ? src1 : src2)
        property variant source2: root.isMedia1Active ? src2 : src1
        property real aspect: root.width / root.height
        property real progress: 0

        anchors.fill: parent
        visible: false
        z: 3
        fragmentShader: root.currentShader
    }

    MultiEffect {
        id: loadingBlur

        anchors.fill: parent
        source: root.isMedia1Active ? media1 : media2
        visible: false
        opacity: 0
        // This is the shader's old-wallpaper input. It never processes the
        // selected wallpaper or the shader's combined output.
        z: 1
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0.8
        blurMax: 32
    }

    NumberAnimation {
        id: blurInAnim

        target: loadingBlur
        property: "opacity"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: root.loadPendingVideo()
    }

    Timer {
        id: transitionStartTimer

        // Give the render thread one frame to refresh the two frozen textures.
        interval: 16
        repeat: false
        onTriggered: {
            if (shaderEffect.visible)
                transitionAnim.restart();
        }
    }

    NumberAnimation {
        id: transitionAnim

        target: shaderEffect
        property: "progress"
        from: 0
        to: 1
        duration: 850
        easing.type: Easing.OutCubic
        onFinished: root.finishTransition()
    }

}
