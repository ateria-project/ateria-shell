import QtQuick
import Quickshell.Widgets
import qs.components
import qs.platform.media
import qs.theme

Rectangle {
    id: root

    readonly property bool hovered: mediaHoverHandler.hovered
    readonly property int maximumWidth: 260
    readonly property int artworkSize: 22
    readonly property int playPauseButtonWidth: 28
    readonly property int nextButtonWidth: 24
    readonly property int leftContentMargin: 3
    readonly property int rightContentMargin: 2
    readonly property real marqueeVelocity: 60
    readonly property real fixedContentWidth: root.leftContentMargin + root.rightContentMargin + root.artworkSize + root.playPauseButtonWidth + root.nextButtonWidth + Metrics.spacingXs + Metrics.spacingSm * 2
    readonly property real maximumTextWidth: root.maximumWidth - root.fixedContentWidth
    readonly property real fittedTextWidth: Math.min(titleText.implicitWidth, root.maximumTextWidth)
    readonly property bool playing: MprisService.isPlaying
    readonly property bool activeArtworkReady: {
        const active = root.activeArtworkSlot === 0 ? artworkA : artworkB;
        return active.status === Image.Ready && active.source.toString().length > 0;
    }

    property bool inactiveHidden: false
    property int activeArtworkSlot: 0
    property int pendingArtworkSlot: -1
    property string requestedArtworkUrl: ""
    property bool artworkInitialized: false
    property bool initialMarqueeActive: false

    readonly property bool isActive: MprisService.available && (!MediaSettings.hideWhenInactive || !root.inactiveHidden)
    readonly property real activeImplicitWidth: root.fixedContentWidth + root.fittedTextWidth

    function updateInactivityState() {
        if (!MediaSettings.hideWhenInactive || !MprisService.available) {
            inactivityTimer.stop();
            root.inactiveHidden = false;
            return;
        }
        if (root.playing) {
            inactivityTimer.stop();
            root.inactiveHidden = false;
            return;
        }
        root.inactiveHidden = false;
        inactivityTimer.restart();
    }

    function updateArtwork(source: string) {
        if (root.artworkInitialized && source === root.requestedArtworkUrl)
            return;

        root.requestedArtworkUrl = source;

        if (!root.artworkInitialized) {
            artworkA.source = source;
            root.activeArtworkSlot = 0;
            root.pendingArtworkSlot = -1;
            root.artworkInitialized = true;
            return;
        }

        const incomingSlot = root.activeArtworkSlot === 0 ? 1 : 0;
        const incoming = incomingSlot === 0 ? artworkA : artworkB;
        incoming.source = source;
        root.pendingArtworkSlot = incomingSlot;

        if (source.length === 0 || incoming.status === Image.Ready || incoming.status === Image.Error)
            root.activatePendingArtwork();
    }

    function activatePendingArtwork() {
        if (root.pendingArtworkSlot < 0)
            return;

        const previous = root.activeArtworkSlot === 0 ? artworkA : artworkB;
        root.activeArtworkSlot = root.pendingArtworkSlot;
        root.pendingArtworkSlot = -1;
        previous.source = "";
    }

    function updateArtworkRotation() {
        if (!root.isActive || !root.activeArtworkReady) {
            artworkRotation.stop();
            return;
        }

        if (!root.playing) {
            if (artworkRotation.running && !artworkRotation.paused)
                artworkRotation.pause();
            return;
        }

        if (!artworkRotation.running)
            artworkRotation.start();
        else if (artworkRotation.paused)
            artworkRotation.resume();
    }

    function stopMarquee() {
        marqueeAnimation.stop();
        marqueeReturn.stop();
    }

    function scheduleMarqueeSync() {
        // Text and implicitWidth commonly change in the same event-loop turn.
        // Coalesce those notifications so the marquee is configured once using
        // the final geometry instead of repeatedly stopping and restarting.
        Qt.callLater(root.syncMarquee);
    }

    function syncMarquee() {
        if (mediaWidthAnimation.running)
            return;

        if (root.initialMarqueeActive)
            root.startMarquee(true);
        else
            root.updateMarquee();
    }

    function updateMarquee() {
        if (root.initialMarqueeActive)
            return;

        if (root.hovered && titleViewport.overflowDistance > 0) {
            // Preserve the current x when reversing a return animation.
            root.startMarquee(false);
            return;
        }

        marqueeAnimation.stop();
        if (Math.abs(titleText.x) < 0.5) {
            titleText.x = 0;
            return;
        }

        marqueeReturn.from = titleText.x;
        marqueeReturn.to = 0;
        marqueeReturn.duration = Math.max(1, Math.round(Math.abs(titleText.x) / root.marqueeVelocity * 1000));
        marqueeReturn.restart();
    }

    function requestInitialMarquee() {
        root.stopMarquee();
        root.initialMarqueeActive = titleText.text.length > 0;
        titleText.x = 0;
        root.scheduleMarqueeSync();
    }

    function startMarquee(resetPosition: bool) {
        if (mediaWidthAnimation.running)
            return;

        root.stopMarquee();
        if (resetPosition)
            titleText.x = 0;

        const overflow = titleViewport.overflowDistance;
        if (overflow <= 0) {
            titleText.x = 0;
            root.initialMarqueeActive = false;
            return;
        }

        // The first leg may begin midway through the viewport when hover
        // reverses an in-progress return. Keep the same nominal velocity.
        const distanceToEnd = Math.abs(titleText.x + overflow);
        marqueeToEnd.duration = Math.max(1, Math.round(distanceToEnd / root.marqueeVelocity * 1000));
        marqueeToStart.duration = Math.max(1, Math.round(overflow / root.marqueeVelocity * 1000));
        marqueeAnimation.loops = root.initialMarqueeActive ? 1 : Animation.Infinite;
        marqueeAnimation.restart();
    }

    visible: root.isActive || root.implicitWidth > 0
    implicitWidth: root.isActive ? root.activeImplicitWidth : 0
    implicitHeight: 28
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer
    opacity: 1
    clip: true

    onPlayingChanged: {
        root.updateInactivityState();
        root.updateArtworkRotation();
    }
    onIsActiveChanged: root.updateArtworkRotation()
    onActiveArtworkReadyChanged: root.updateArtworkRotation()
    onHoveredChanged: root.updateMarquee()
    Component.onCompleted: {
        root.updateInactivityState();
        root.updateArtwork(MprisService.artworkUrl);
        root.updateArtworkRotation();
        root.requestInitialMarquee();
    }

    Connections {
        target: MprisService

        function onArtworkUrlChanged() {
            root.updateArtwork(MprisService.artworkUrl);
        }

        function onAvailableChanged() {
            root.updateInactivityState();
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            id: mediaWidthAnimation

            duration: Motion.durationSpatialDefault
            easing.type: Motion.easingExpressiveSpatial
            easing.bezierCurve: Motion.expressiveDefaultSpatialCurve
            onRunningChanged: {
                if (running) {
                    root.stopMarquee();
                    titleText.x = 0;
                } else {
                    root.syncMarquee();
                }
            }
        }
    }

    Timer {
        id: inactivityTimer

        interval: MediaSettings.inactiveTimeout * 1000
        repeat: false
        onTriggered: root.inactiveHidden = true
    }

    Connections {
        target: MediaSettings

        function onHideWhenInactiveChanged() {
            root.updateInactivityState();
        }

        function onInactiveTimeoutChanged() {
            root.updateInactivityState();
        }
    }

    HoverHandler {
        id: mediaHoverHandler
    }

    ClippingRectangle {
        id: artworkClip

        anchors.left: parent.left
        anchors.leftMargin: root.leftContentMargin
        anchors.verticalCenter: parent.verticalCenter
        width: root.artworkSize
        height: root.artworkSize
        radius: Metrics.radiusFull
        color: Theme.scheme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.scheme.outlineVariant
        contentUnderBorder: true
        transformOrigin: Item.Center

        // Cache the final clipped result. Rotation then transforms the tiny
        // cached texture instead of invalidating the clipping contents.
        layer.enabled: true
        layer.smooth: true

        Item {
            id: artworkRecord

            anchors.fill: parent

            M3Icon {
                anchors.centerIn: parent
                visible: !root.activeArtworkReady
                name: "music_note"
                size: 16
                filled: true
                color: Theme.scheme.onSurfaceVariant
            }

            Image {
                id: artworkA

                anchors.fill: parent
                visible: root.activeArtworkSlot === 0 && status === Image.Ready
                sourceSize.width: 44
                sourceSize.height: 44
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                onStatusChanged: {
                    if (root.pendingArtworkSlot === 0 && (status === Image.Ready || status === Image.Error))
                        root.activatePendingArtwork();
                }
            }

            Image {
                id: artworkB

                anchors.fill: parent
                visible: root.activeArtworkSlot === 1 && status === Image.Ready
                sourceSize.width: 44
                sourceSize.height: 44
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                onStatusChanged: {
                    if (root.pendingArtworkSlot === 1 && (status === Image.Ready || status === Image.Error))
                        root.activatePendingArtwork();
                }
            }
        }
    }

    M3Button {
        id: nextButton

        anchors.right: parent.right
        anchors.rightMargin: root.rightContentMargin
        anchors.verticalCenter: parent.verticalCenter
        width: root.nextButtonWidth
        height: 24
        enabled: MprisService.canGoNext
        style: M3Button.Text
        iconName: "skip_next"
        iconSize: 18
        iconFilled: true
        contentColor: Theme.scheme.onSurface
        leftPadding: 3
        rightPadding: 5
        topPadding: 3
        bottomPadding: 3
        Accessible.name: qsTr("Next track")
        onClicked: MprisService.nextTrack()
    }

    M3Button {
        id: playPauseButton

        anchors.right: nextButton.left
        anchors.rightMargin: Metrics.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: root.playPauseButtonWidth
        height: 24
        enabled: MprisService.canTogglePlayback
        style: M3Button.Tonal
        iconName: MprisService.isPlaying ? "pause" : "play_arrow"
        iconSize: 18
        iconFilled: true
        leftPadding: 5
        rightPadding: 5
        topPadding: 3
        bottomPadding: 3
        Accessible.name: MprisService.isPlaying ? qsTr("Pause") : qsTr("Play")
        onClicked: MprisService.togglePlayback()
    }

    Item {
        id: titleViewport

        readonly property real overflowDistance: Math.max(0, titleText.implicitWidth - titleViewport.width)

        anchors.left: artworkClip.right
        anchors.leftMargin: Metrics.spacingSm
        anchors.right: playPauseButton.left
        anchors.rightMargin: Metrics.spacingSm
        anchors.verticalCenter: parent.verticalCenter
        height: titleText.implicitHeight
        clip: true

        M3Text {
            id: titleText

            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            text: MprisService.displayText
            maximumLineCount: 1
            color: Theme.scheme.onSurface
            font.pixelSize: 12
            font.weight: Font.Medium
            onTextChanged: root.requestInitialMarquee()
            onImplicitWidthChanged: root.scheduleMarqueeSync()
        }
    }

    RotationAnimator {
        id: artworkRotation

        target: artworkClip
        from: 0
        to: 360
        duration: 12000
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        id: marqueeAnimation

        onFinished: {
            if (!root.initialMarqueeActive)
                return;

            root.initialMarqueeActive = false;
            root.updateMarquee();
        }

        NumberAnimation {
            id: marqueeToEnd

            target: titleText
            property: "x"
            to: -titleViewport.overflowDistance
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 1500
        }
        NumberAnimation {
            id: marqueeToStart

            target: titleText
            property: "x"
            to: 0
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: root.initialMarqueeActive ? 0 : 1500
        }
    }

    NumberAnimation {
        id: marqueeReturn

        target: titleText
        property: "x"
        easing.type: Easing.InOutSine
    }
}
