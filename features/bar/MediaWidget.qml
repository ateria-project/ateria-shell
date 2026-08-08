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
    readonly property real marqueeVelocity: 60
    readonly property real fixedContentWidth: root.leftContentMargin + root.rightContentMargin + root.artworkSize + root.playPauseButtonWidth + root.nextButtonWidth + Metrics.spacingXs + Metrics.spacingSm * 2
    readonly property real maximumTextWidth: root.maximumWidth - root.fixedContentWidth
    readonly property real fittedTextWidth: Math.min(titleText.implicitWidth, root.maximumTextWidth)
    readonly property bool playing: MprisService.isPlaying
    readonly property string mediaKey: [MprisService.identity, MprisService.artist, MprisService.title, MprisService.artworkUrl].join("\u001f")

    property bool inactiveHidden: false

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

    visible: root.isActive
    implicitWidth: root.isActive ? root.activeImplicitWidth : 0
    implicitHeight: 28
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer
    opacity: 1
    clip: true

    onMediaKeyChanged: root.updateInactivityState()
    onPlayingChanged: root.updateInactivityState()
    Component.onCompleted: root.updateInactivityState()

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

    Connections {
        target: MprisService

        function onAvailableChanged() {
            root.updateInactivityState();
        }
    }

    HoverHandler {
        id: mediaHoverHandler
    }

    RowLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: root.leftContentMargin
        width: root.activeImplicitWidth - root.leftContentMargin - root.rightContentMargin
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

            Item {
                anchors.fill: parent

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
        }

        Item {
            id: titleViewport

            readonly property real overflowDistance: Math.max(0, titleText.implicitWidth - titleViewport.width)

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: root.fittedTextWidth
            Layout.maximumWidth: root.maximumTextWidth
            Layout.preferredHeight: titleText.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            clip: true

            M3Text {
                id: titleText

                x: root.hovered ? -titleViewport.overflowDistance : 0
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                text: MprisService.displayText
                maximumLineCount: 1
                color: Theme.scheme.onSurface
                font.pixelSize: 12
                font.weight: Font.Medium

                Behavior on x {
                    SmoothedAnimation {
                        velocity: root.marqueeVelocity
                        maximumEasingTime: Motion.durationLong
                    }
                }
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
        }
    }
}
