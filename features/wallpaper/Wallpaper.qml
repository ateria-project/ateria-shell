pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.platform.power
import qs.platform.workspace
import qs.theme

PanelWindow {
    id: root

    property url source: WallpaperController.source
    property bool isMedia1Active: true
    property bool transitionPending: false
    property bool videoLoading: false
    property bool previewFadingOut: false
    property var previewSourceMedia: null
    property int currentGroupIndex: 0
    property string currentShader: transitionGroups[0].shader
    property int transitionDuration: transitionGroups[0].minDuration
    property int transitionEasingType: transitionGroups[0].easingType
    property var transitionEasingCurve: transitionGroups[0].easingCurve
    property real transitionVariant: transitionGroups[0].variants[0]
    property var previousVariants: ({})
    readonly property real transitionTextureScale: PowerService.powerSaver ? 0.5 : 0.75
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
    // Each full-screen transition follows a Material motion role: expanding
    // surfaces settle into place, while the directional wave keeps a more
    // even on-screen path. Longer transformations get more time to travel.
    readonly property var transitionGroups: [
        {
            "shader": "shaders/circle_reveal_center.frag.qsb",
            "minDuration": 1200,
            "maxDuration": 1450,
            "easingType": Motion.easingEmphasizedDecelerate,
            "easingCurve": Motion.emphasizedDecelerateCurve,
            "variants": [0, 1, 2, 3, 4, 5, 6, 7]
        },
        {
            "shader": "shaders/star.frag.qsb",
            "minDuration": 1800,
            "maxDuration": 2200,
            "easingType": Motion.easingStandard,
            "easingCurve": Motion.standardCurve,
            "variants": [0, 1, 2, 3, 4, 5]
        },
        {
            "shader": "shaders/wave.frag.qsb",
            "minDuration": 1200,
            "maxDuration": 1400,
            "easingType": Motion.easingStandard,
            "easingCurve": Motion.standardCurve,
            "variants": [0, 1, 2, 3]
        },
        {
            "shader": "shaders/ripple_reveal.frag.qsb",
            "minDuration": 1450,
            "maxDuration": 1750,
            "easingType": Motion.easingEmphasizedDecelerate,
            "easingCurve": Motion.emphasizedDecelerateCurve,
            "variants": [0, 1, 2, 3, 4, 5]
        },
        {
            "shader": "shaders/tv_on.frag.qsb",
            "minDuration": 1200,
            "maxDuration": 1350,
            "easingType": Motion.easingStandardDecelerate,
            "easingCurve": Motion.standardDecelerateCurve,
            "variants": [0, 1, 2, 3, 4]
        }
    ]

    function pickNextTransition() {
        const group = transitionGroups[currentGroupIndex];
        const previousVariant = previousVariants[currentGroupIndex];
        let variantIndex = Math.floor(Math.random() * group.variants.length);
        if (group.variants.length > 1 && group.variants[variantIndex] === previousVariant)
            variantIndex = (variantIndex + 1 + Math.floor(Math.random() * (group.variants.length - 1))) % group.variants.length;

        const nextVariant = group.variants[variantIndex];
        const updatedVariants = Object.assign({}, previousVariants);
        updatedVariants[currentGroupIndex] = nextVariant;
        previousVariants = updatedVariants;

        currentShader = group.shader;
        transitionDuration = group.minDuration + Math.floor(Math.random() * (group.maxDuration - group.minDuration + 1));
        transitionEasingType = group.easingType;
        transitionEasingCurve = group.easingCurve;
        transitionVariant = nextVariant;
        currentGroupIndex = (currentGroupIndex + 1) % transitionGroups.length;
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
        root.wakeRenderer();
        if (root.videoPlaybackSuppressed) {
            // Do not stop a newly selected video before its first frame. It
            // must finish warming up so the pending transition can proceed.
            if (media1.firstVideoFrameReady)
                media1.pauseVideo();
            if (media2.firstVideoFrameReady)
                media2.pauseVideo();
            videoHibernateTimer.restart();
            root.maybeFreezeRenderer();
            return;
        }

        videoHibernateTimer.stop();
        media1.wakeVideoBackend();
        media2.wakeVideoBackend();

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

    function wakeRenderer(): void {
        settleRendererTimer.stop();
        root.updatesEnabled = true;
    }

    function maybeFreezeRenderer(): void {
        const active = root.activeMedia();
        if (root.transitionPending || root.videoLoading || shaderEffect.visible || !active.ready)
            return;
        if (active.isVideo && !root.videoPlaybackSuppressed)
            return;

        // Delay the freeze by two frames so the final image reaches the
        // compositor before render-loop updates are suspended.
        settleRendererTimer.restart();
    }

    function startVideoLoading(): void {
        root.wakeRenderer();
        root.previewSourceMedia = root.activeMedia();
        root.previewFadingOut = false;
        root.transitionPending = true;
        root.videoLoading = true;
        root.activeMedia().pauseVideo();
        root.inactiveMedia().source = "";

        loadingPreview.visible = true;
        loadingPreview.scale = 1;
        previewDriftAnim.restart();
        loadingPreview.scheduleUpdate();
        if (loadingPreview.opacity >= 0.99) {
            root.loadPendingVideo();
            return;
        }

        previewInAnim.from = loadingPreview.opacity;
        previewInAnim.restart();
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

    function clearLoadingPreview(): void {
        previewInAnim.stop();
        previewOutAnim.stop();
        previewDriftAnim.stop();
        loadingPreview.opacity = 0;
        loadingPreview.scale = 1;
        loadingPreview.visible = false;
        root.previewFadingOut = false;
        root.previewSourceMedia = null;
    }

    function cancelVideoLoading(resumeActive): void {
        root.videoLoading = false;
        root.clearLoadingPreview();
        if (resumeActive)
            root.activeMedia().resumeVideo();
    }

    function beginTransition(): void {
        const next = root.inactiveMedia();
        if (!root.transitionPending || !next.ready || String(next.source) !== String(root.source))
            return;

        if (root.videoLoading) {
            // The zoomed preview is only a loading placeholder. Once the
            // decoder has a frame, transition from the real outgoing
            // wallpaper underneath it, then fade the preview independently.
            next.playVideo();
            root.videoLoading = false;
            root.previewFadingOut = true;
            root.startShaderTransition();
            previewOutAnim.from = loadingPreview.opacity;
            previewOutAnim.restart();
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
        root.wakeRenderer();
        root.transitionPending = false;
        active.pauseVideo();
        next.playVideo();
        root.pickNextTransition();
        shaderEffect.progress = 0;
        shaderEffect.visible = true;
        if (media1.isVideo)
            src1.scheduleUpdate();
        if (media2.isVideo)
            src2.scheduleUpdate();
        transitionStartTimer.restart();
    }

    function finishTransition(): void {
        transitionStartTimer.stop();
        transitionAnim.stop();

        // Remove any remaining loading preview before exposing the completed
        // wallpaper directly.
        root.clearLoadingPreview();
        root.isMedia1Active = !root.isMedia1Active;
        shaderEffect.progress = 0;
        shaderEffect.visible = false;

        const active = root.activeMedia();
        const inactive = root.inactiveMedia();
        inactive.source = "";
        active.resumeVideo();
        root.maybeFreezeRenderer();
    }

    color: "black"
    surfaceFormat.opaque: true
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Background
    Component.onCompleted: {
        currentGroupIndex = Math.floor(Math.random() * transitionGroups.length);
        pickNextTransition();
        root.wakeRenderer();
    }
    onSourceChanged: {
        root.wakeRenderer();
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
        if (media === root.activeMedia() && String(media.source) === String(root.source)) {
            if (isReady)
                root.maybeFreezeRenderer();
            return;
        }
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
        property bool videoBackendEnabled: true
        readonly property bool isVideo: root.isVideoSource(source)
        readonly property var imageTexture: img
        readonly property var videoBackend: videoLoader.item
        readonly property bool firstVideoFrameReady: isVideo && videoBackend?.firstFrameReady === true
        readonly property vector4d textureCrop: {
            if (isVideo || img.implicitWidth <= 0 || img.implicitHeight <= 0 || mediaRoot.width <= 0 || mediaRoot.height <= 0)
                return Qt.vector4d(1, 1, 0, 0);

            const sourceAspect = img.implicitWidth / img.implicitHeight;
            const targetAspect = mediaRoot.width / mediaRoot.height;
            if (sourceAspect > targetAspect) {
                const scale = targetAspect / sourceAspect;
                return Qt.vector4d(scale, 1, (1 - scale) * 0.5, 0);
            }

            const scale = sourceAspect / targetAspect;
            return Qt.vector4d(1, scale, 0, (1 - scale) * 0.5);
        }
        readonly property bool ready: isVideo ? firstVideoFrameReady : img.status === Image.Ready
        readonly property bool error: isVideo ? videoBackend?.error === true : img.status === Image.Error

        function pauseVideo(): void {
            if (mediaRoot.isVideo)
                mediaRoot.videoBackend?.pauseVideo();
        }

        function hibernateVideoBackend(): void {
            if (mediaRoot.isVideo && mediaRoot.firstVideoFrameReady) {
                mediaRoot.pauseVideo();
                mediaRoot.videoBackendEnabled = false;
            }
        }

        function wakeVideoBackend(): void {
            if (mediaRoot.isVideo)
                mediaRoot.videoBackendEnabled = true;
        }

        function playVideo(): void {
            if (!mediaRoot.isVideo || !mediaRoot.firstVideoFrameReady)
                return;
            if (root.videoPlaybackSuppressed) {
                mediaRoot.pauseVideo();
                return;
            }
            mediaRoot.videoBackend?.playVideo();
        }

        function resumeVideo(): void {
            if (mediaRoot.active)
                mediaRoot.playVideo();
        }

        onSourceChanged: videoBackendEnabled = true
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
            cache: false
            smooth: true
            mipmap: false
        }

        LazyLoader {
            id: videoLoader

            active: mediaRoot.isVideo && mediaRoot.videoBackendEnabled

            Item {
                id: backend

                parent: mediaRoot
                anchors.fill: parent
                property bool firstFrameReady: false
                readonly property bool error: player.mediaStatus === MediaPlayer.InvalidMedia

                function pauseVideo(): void {
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause();
                }

                function playVideo(): void {
                    if (backend.firstFrameReady && player.playbackState !== MediaPlayer.PlayingState)
                        player.play();
                }

                MediaPlayer {
                    id: player

                    source: mediaRoot.source
                    videoOutput: videoOut
                    loops: MediaPlayer.Infinite
                    autoPlay: true
                }

                VideoOutput {
                    id: videoOut

                    anchors.fill: parent
                    visible: backend.firstFrameReady
                    fillMode: VideoOutput.PreserveAspectCrop
                }

                Connections {
                    target: videoOut.videoSink

                    function onVideoFrameChanged(): void {
                        if (!player.hasVideo || backend.firstFrameReady)
                            return;

                        // The decoder is warm and VideoOutput owns a renderable frame.
                        backend.firstFrameReady = true;
                        if (root.videoPlaybackSuppressed)
                            backend.pauseVideo();
                    }
                }
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
        sourceItem: media1.isVideo && (root.transitionPending || shaderEffect.visible) ? media1 : null
        hideSource: shaderEffect.visible
        live: shaderEffect.visible && media1.isVideo && media1 === root.inactiveMedia()
        textureSize: Qt.size(Math.max(1, Math.round(root.width * root.transitionTextureScale)), Math.max(1, Math.round(root.height * root.transitionTextureScale)))
    }

    ShaderEffectSource {
        id: src2
        sourceItem: media2.isVideo && (root.transitionPending || shaderEffect.visible) ? media2 : null
        hideSource: shaderEffect.visible
        live: shaderEffect.visible && media2.isVideo && media2 === root.inactiveMedia()
        textureSize: src1.textureSize
    }

    ShaderEffect {
        id: shaderEffect

        property variant source1: root.isMedia1Active ? (media1.isVideo ? src1 : media1.imageTexture) : (media2.isVideo ? src2 : media2.imageTexture)
        property variant source2: root.isMedia1Active ? (media2.isVideo ? src2 : media2.imageTexture) : (media1.isVideo ? src1 : media1.imageTexture)
        property vector4d crop1: root.activeMedia().textureCrop
        property vector4d crop2: root.inactiveMedia().textureCrop
        property real aspect: root.width / root.height
        property real progress: 0
        property real variant: root.transitionVariant

        anchors.fill: parent
        visible: false
        blending: false
        z: 3
        fragmentShader: root.currentShader
    }

    ShaderEffectSource {
        id: loadingPreview

        // Keep the preview pinned to the outgoing slot. activeMedia() changes
        // when the transition settles and must never redirect this texture to
        // the newly revealed wallpaper for a frame.
        sourceItem: (root.videoLoading || root.previewFadingOut) ? root.previewSourceMedia : null
        // The wallpaper window may have been frozen before this source was
        // attached. Keep it live during fade-in so the first black allocation
        // is replaced by a rendered outgoing frame, then freeze that frame
        // while the video loads and transitions.
        live: root.videoLoading
        textureSize: Qt.size(Math.max(1, Math.round(root.width * (PowerService.powerSaver ? 0.75 : 1.0))), Math.max(1, Math.round(root.height * (PowerService.powerSaver ? 0.75 : 1.0))))
        smooth: true
        anchors.fill: parent
        visible: false
        opacity: 0
        // During video preparation this cached preview drifts subtly. Once the
        // transition starts it remains above the shader briefly and fades.
        z: 4
    }

    NumberAnimation {
        id: previewInAnim

        target: loadingPreview
        property: "opacity"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: root.loadPendingVideo()
    }

    NumberAnimation {
        id: previewOutAnim

        target: loadingPreview
        property: "opacity"
        to: 0
        duration: 600
        easing.type: Easing.OutCubic
        onFinished: root.clearLoadingPreview()
    }

    NumberAnimation {
        id: previewDriftAnim

        target: loadingPreview
        property: "scale"
        from: 1
        to: 1.02
        duration: 1400
        easing.type: Easing.OutCubic
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

    Timer {
        id: settleRendererTimer

        interval: 32
        repeat: false
        onTriggered: root.updatesEnabled = false
    }

    Timer {
        id: videoHibernateTimer

        // Pausing is instant; release decoder state only after a sustained
        // cover/power-saving interval to avoid churn during normal window use.
        interval: 30000
        repeat: false
        onTriggered: {
            media1.hibernateVideoBackend();
            media2.hibernateVideoBackend();
            root.maybeFreezeRenderer();
        }
    }

    NumberAnimation {
        id: transitionAnim

        target: shaderEffect
        property: "progress"
        from: 0
        to: 1
        duration: root.transitionDuration
        easing.type: root.transitionEasingType
        easing.bezierCurve: root.transitionEasingCurve
        onFinished: root.finishTransition()
    }

}
