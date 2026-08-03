import QtQuick
import QtQuick.Layouts
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
    readonly property int marqueeStartDelay: 1000
    readonly property int marqueeEndHold: 800
    readonly property real marqueeVelocity: 60
    readonly property real fixedContentWidth: root.leftContentMargin + root.rightContentMargin + root.artworkSize + root.playPauseButtonWidth + root.nextButtonWidth + Metrics.spacingXs + Metrics.spacingSm * 2
    readonly property real maximumTextWidth: root.maximumWidth - root.fixedContentWidth
    readonly property real fittedTextWidth: Math.min(titleText.implicitWidth, root.maximumTextWidth)
    readonly property bool playing: MprisService.isPlaying
    readonly property string mediaKey: [MprisService.identity, MprisService.artist, MprisService.title, MprisService.artworkUrl].join("\u001f")

    function restartMarquee() {
        marqueeAnimation.stop();
        hoverAnimation.stop();
        titleText.x = 0;

        if (root.visible && titleViewport.overflowDistance > 0)
            marqueeAnimation.restart();
    }

    function startHoverMarquee(hovered: bool) {
        hoverAnimation.stop();
        if (titleViewport.overflowDistance <= 0) {
            titleText.x = 0;
            return;
        }

        hoverAnimation.to = hovered ? -titleViewport.overflowDistance : 0;
        hoverAnimation.restart();
    }

    function updateHoverMarquee(hovered: bool) {
        if (!marqueeAnimation.running)
            root.startHoverMarquee(hovered);
    }

    visible: MprisService.available
    implicitWidth: root.fixedContentWidth + root.fittedTextWidth
    implicitHeight: 28
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer

    onMediaKeyChanged: root.restartMarquee()
    onPlayingChanged: {
        if (root.playing)
            root.restartMarquee();
    }
    onVisibleChanged: root.restartMarquee()
    Component.onCompleted: root.restartMarquee()

    HoverHandler {
        id: mediaHoverHandler

        onHoveredChanged: root.updateHoverMarquee(hovered)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.leftContentMargin
        anchors.rightMargin: root.rightContentMargin
        spacing: Metrics.spacingSm

        ClippingRectangle {
            Layout.preferredWidth: root.artworkSize
            Layout.preferredHeight: root.artworkSize
            Layout.alignment: Qt.AlignVCenter
            radius: Metrics.radiusFull
            color: Theme.scheme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.scheme.outlineVariant
            contentUnderBorder: true

            M3Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: 16
                filled: true
                color: Theme.scheme.onSurfaceVariant
            }

            Image {
                anchors.fill: parent
                visible: MprisService.artworkUrl.length > 0
                source: MprisService.artworkUrl
                sourceSize.width: 44
                sourceSize.height: 44
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
            }
        }

        Item {
            id: titleViewport

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: root.fittedTextWidth
            Layout.maximumWidth: root.maximumTextWidth
            Layout.preferredHeight: titleText.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            clip: true

            readonly property real overflowDistance: Math.max(0, titleText.implicitWidth - titleViewport.width)

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
            }
        }

        RowLayout {
            spacing: Metrics.spacingXs

            M3Button {
                Layout.preferredWidth: root.playPauseButtonWidth
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
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

            M3Button {
                Layout.preferredWidth: root.nextButtonWidth
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                enabled: MprisService.canGoNext
                style: M3Button.Text
                iconName: "skip_next"
                iconSize: 20
                iconFilled: true
                contentColor: Theme.scheme.onSurface
                leftPadding: 3
                rightPadding: 5
                topPadding: 3
                bottomPadding: 3
                Accessible.name: qsTr("Next track")
                onClicked: MprisService.nextTrack()
            }
        }
    }

    SequentialAnimation {
        id: marqueeAnimation

        PauseAnimation {
            duration: root.marqueeStartDelay
        }

        SmoothedAnimation {
            target: titleText
            property: "x"
            to: -titleViewport.overflowDistance
            velocity: root.marqueeVelocity
            maximumEasingTime: Motion.durationLong
        }

        PauseAnimation {
            duration: root.marqueeEndHold
        }

        SmoothedAnimation {
            target: titleText
            property: "x"
            to: 0
            velocity: root.marqueeVelocity
            maximumEasingTime: Motion.durationLong
        }

        onFinished: {
            if (root.hovered)
                root.startHoverMarquee(true);
        }
    }

    SmoothedAnimation {
        id: hoverAnimation

        target: titleText
        property: "x"
        to: 0
        velocity: root.marqueeVelocity
        maximumEasingTime: Motion.durationLong
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.durationLong
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }
}
