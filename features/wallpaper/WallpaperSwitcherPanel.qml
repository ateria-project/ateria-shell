pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.platform.workspace
import qs.shell
import qs.theme
import qs.features.wallpaper

TransientPanelWindow {
    id: root

    readonly property real panelWidth: 280
    readonly property real screenRatio: Screen.width > 0 && Screen.height > 0 ? Screen.width / Screen.height : 16 / 9

    // Image decode failures are remembered outside delegates because ListView
    // delegates may be destroyed/reused while scrolling.
    property var failedWallpapers: ({})
    property bool lastCycleForward: true
    property var thumbnailQueue: []
    property var queuedThumbnails: ({})
    property string thumbnailInFlight: ""
    property string pendingVideoSelection: ""
    readonly property var wallpaperModel: WallpaperController.wallpapers

    signal thumbnailReady(string fileUrl)

    readonly property int selectedIndex: {
        const selected = String(WallpaperSettings.selectedFile);
        return selected.length > 0 ? root.wallpaperModel.indexOf(selected) : -1;
    }

    open: SurfaceController.wallpaperSwitcherOpen
    targetScreen: SurfaceController.wallpaperSwitcherScreen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    transitionsEnabled: true
    color: "transparent"

    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-wallpaperswitcher"

    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    function closeSwitcher(): void {
        SurfaceController.closeWallpaperSwitcher();
    }

    function positionListAtTop(): void {
        wallpaperList.positionViewAtBeginning();
    }

    function selectWallpaper(url, isVideo): void {
        const selectedUrl = String(url);
        if (isVideo) {
            // Close without starting MediaPlayer work. Once the panel is gone,
            // the wallpaper renderer can load and reveal the video smoothly.
            root.pendingVideoSelection = selectedUrl;
            root.closeSwitcher();
            return;
        }

        root.pendingVideoSelection = "";
        WallpaperSettings.setSelectedFile(selectedUrl);
        root.closeSwitcher();
    }

    onFullyClosed: {
        if (root.pendingVideoSelection.length === 0)
            return;

        const selectedUrl = root.pendingVideoSelection;
        root.pendingVideoSelection = "";
        WallpaperSettings.setSelectedFile(selectedUrl);
    }

    function isWallpaperFailed(url): bool {
        return root.failedWallpapers[String(url)] === true;
    }

    function markWallpaperFailed(url): void {
        const key = String(url);
        if (key.length === 0 || root.failedWallpapers[key] === true)
            return;

        // Reassign the object so QML bindings observing failedWallpapers are notified.
        const updated = {};
        for (const existingKey in root.failedWallpapers)
            updated[existingKey] = root.failedWallpapers[existingKey];
        updated[key] = true;
        root.failedWallpapers = updated;

        if (String(WallpaperSettings.selectedFile) === key)
            Qt.callLater(() => root.cycleWallpaper(root.lastCycleForward));
    }

    function requestVideoThumbnail(url): void {
        const key = String(url);
        if (key.length === 0 || key === root.thumbnailInFlight || root.queuedThumbnails[key] === true)
            return;

        const queued = Object.assign({}, root.queuedThumbnails);
        queued[key] = true;
        root.queuedThumbnails = queued;
        root.thumbnailQueue = root.thumbnailQueue.concat([key]);
        root.startNextThumbnail();
    }

    function startNextThumbnail(): void {
        if (thumbnailGenProcess.running || root.thumbnailQueue.length === 0)
            return;

        const queue = root.thumbnailQueue.slice();
        root.thumbnailInFlight = queue.shift();
        root.thumbnailQueue = queue;

        const localPath = decodeURIComponent(root.thumbnailInFlight.replace(/^file:\/\//, ""));
        thumbnailGenProcess.exec([
            "bash",
            "-c",
            "n=\"$(basename \"$1\")\"; t=\"/tmp/ateria_thumbs/$n.jpg\"; if [ ! -f \"$t\" ]; then mkdir -p /tmp/ateria_thumbs && nice -n 19 ffmpeg -loglevel error -y -threads 1 -i \"$1\" -map 0:v:0 -frames:v 1 -vf 'scale=640:-2' -q:v 4 \"$t\" </dev/null; fi",
            "_",
            localPath
        ]);
    }

    function finishThumbnail(): void {
        const completedUrl = root.thumbnailInFlight;
        root.thumbnailInFlight = "";

        const queued = Object.assign({}, root.queuedThumbnails);
        // Keep completed attempts deduplicated for this panel session. A bad
        // video or missing ffmpeg must not create an immediate retry loop.
        if (completedUrl.length > 0)
            queued[completedUrl] = true;
        root.queuedThumbnails = queued;

        if (completedUrl.length > 0)
            root.thumbnailReady(completedUrl);
        root.startNextThumbnail();
    }

    function cycleWallpaper(forward): void {
        const count = root.wallpaperModel.count;
        if (count <= 0)
            return;

        root.lastCycleForward = forward;

        const currentIndex = root.selectedIndex;
        let searchIndex = currentIndex < 0 ? (forward ? -1 : 0) : currentIndex;

        for (let steps = 0; steps < count; ++steps) {
            searchIndex = forward ? (searchIndex + 1) % count : (searchIndex - 1 + count) % count;

            const nextUrl = String(root.wallpaperModel.get(searchIndex, "fileUrl"));
            if (nextUrl.length === 0 || root.isWallpaperFailed(nextUrl))
                continue;

            WallpaperSettings.setSelectedFile(nextUrl);
            return;
        }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            SurfaceController.openWallpaperSwitcher(root.fallbackScreen);
        }

        function close(): void {
            SurfaceController.closeWallpaperSwitcher();
        }

        function toggle(): void {
            if (SurfaceController.wallpaperSwitcherOpen)
                SurfaceController.closeWallpaperSwitcher();
            else
                SurfaceController.openWallpaperSwitcher(root.fallbackScreen);
        }
    }

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
        enabled: root.interactive
        onDismissed: root.closeSwitcher()
    }

    onOpenChanged: {
        if (!root.open) {
            // Do not decode thumbnails that have scrolled out of view after the
            // switcher closes. The one low-priority in-flight job may finish.
            root.thumbnailQueue = [];
            root.queuedThumbnails = ({});
            return;
        }

        // Reopening during an interrupted exit cancels its deferred selection.
        root.pendingVideoSelection = "";
        panelSurface.forceActiveFocus(Qt.PopupFocusReason);

        // Always present the collection from the beginning when reopened.
        Qt.callLater(root.positionListAtTop);
    }

    M3Surface {
        id: panelSurface

        focus: root.open
        width: root.panelWidth
        radius: 16

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: 6
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                const forward = !(event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier));
                root.cycleWallpaper(forward);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.cycleWallpaper(false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.closeSwitcher();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingLg
            spacing: Metrics.spacingMd

            M3Text {
                text: qsTr("Wallpapers")
                color: Theme.scheme.onSurface
                font.pixelSize: 20
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            Connections {
                target: root.wallpaperModel

                function onFolderChanged(): void {
                    root.failedWallpapers = ({});
                    root.thumbnailQueue = [];
                    root.queuedThumbnails = ({});
                }

                function onStatusChanged(): void {
                    if (root.wallpaperModel.status === FolderListModel.Ready && root.open)
                        Qt.callLater(root.positionListAtTop);
                }
            }

            Process {
                id: thumbnailGenProcess

                onExited: root.finishThumbnail()
            }

            ListView {
                id: wallpaperList

                readonly property bool scrollable: contentHeight > height + 0.5

                Layout.fillWidth: true
                Layout.fillHeight: true

                model: root.wallpaperModel
                currentIndex: root.selectedIndex
                spacing: Metrics.spacingSm
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false

                // Load only the visible neighborhood instead of every wallpaper.
                cacheBuffer: Math.max(0, Math.round(height))
                reuseItems: true

                // Keeping the current item visible is now the view's job rather than
                // manually mutating contentY.
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0
                highlightResizeDuration: 0

                ScrollBar.vertical: M3ScrollBar {
                    parent: panelSurface.presentationItem
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.spacingXs
                    y: wallpaperList.y + wallpaperList.parent.y
                    height: wallpaperList.height
                    z: 20
                    policy: wallpaperList.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                highlight: Component {
                    Rectangle {
                        z: 10
                        radius: 12
                        color: "transparent"
                        border.color: Theme.scheme.primary
                        border.width: 2
                        opacity: height > 0 ? 1.0 : 0.0

                        Behavior on x {
                            NumberAnimation {
                                duration: Motion.durationMedium
                                easing.type: Motion.easingEmphasizedDecelerate
                                easing.bezierCurve: Motion.emphasizedDecelerateCurve
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Motion.durationMedium
                                easing.type: Motion.easingEmphasizedDecelerate
                                easing.bezierCurve: Motion.emphasizedDecelerateCurve
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Motion.durationMedium
                                easing.type: Motion.easingEmphasized
                                easing.bezierCurve: Motion.emphasizedCurve
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: Motion.durationMedium
                                easing.type: Motion.easingEmphasized
                                easing.bezierCurve: Motion.emphasizedCurve
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                delegate: Item {
                    id: delegateRoot

                    required property int index
                    required property url fileUrl

                    readonly property string localFilePath: decodeURIComponent(String(fileUrl).replace(/^file:\/\//, ""))
                    readonly property string fileName: localFilePath.substring(localFilePath.lastIndexOf("/") + 1)
                    readonly property bool isVideo: /\.(mp4|webm|mkv|gif)$/i.test(fileName)
                    readonly property string thumbPath: isVideo ? "file:///tmp/ateria_thumbs/" + fileName + ".jpg" : String(fileUrl)

                    function requestThumbnail(): void {
                        if (delegateRoot.isVideo)
                            root.requestVideoThumbnail(delegateRoot.fileUrl);
                    }

                    width: wallpaperList.width
                    height: thumbImg.status === Image.Error && !isVideo ? 0 : Math.max(1, Math.round(width / root.screenRatio))
                    visible: height > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.scheme.surfaceContainerHighest

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 8
                            color: "transparent"
                            contentUnderBorder: false

                            Image {
                                id: thumbImg

                                anchors.fill: parent
                                source: delegateRoot.thumbPath
                                sourceSize: Qt.size(400, Math.max(1, Math.round(400 / root.screenRatio)))
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true

                                onStatusChanged: {
                                    if (status === Image.Error && !delegateRoot.isVideo) {
                                        root.markWallpaperFailed(delegateRoot.fileUrl);
                                    } else if (status === Image.Error) {
                                        delegateRoot.requestThumbnail();
                                    }
                                }
                            }

                            M3Icon {
                                anchors.centerIn: parent
                                name: "movie"
                                size: 36
                                color: Theme.scheme.onSurface
                                visible: delegateRoot.isVideo
                                filled: true
                            }

                            Connections {
                                target: root

                                function onThumbnailReady(fileUrl): void {
                                    if (String(fileUrl) !== String(delegateRoot.fileUrl))
                                        return;

                                    thumbImg.source = "";
                                    Qt.callLater(() => thumbImg.source = delegateRoot.thumbPath);
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: root.selectWallpaper(delegateRoot.fileUrl, delegateRoot.isVideo)

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Theme.scheme.onSurface
                                opacity: parent.containsMouse ? 0.1 : 0.0
                            }
                        }
                    }
                }
            }
        }
    }

    SlideTransition {
        id: panelTransition

        target: panelSurface.presentationItem
        hiddenOffsetX: -(panelSurface.width + panelSurface.anchors.margins + 5)
        hiddenOffsetY: 0
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
