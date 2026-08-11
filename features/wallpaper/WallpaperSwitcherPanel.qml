pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.platform.wallpaper
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
    property string pendingVideoSelection: ""
    readonly property var wallpaperModel: WallpaperController.wallpapers

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
        if (isVideo && !WallpaperCacheService.isSelectable(selectedUrl))
            return;

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
            if (nextUrl.length === 0 || root.isWallpaperFailed(nextUrl)
                    || !WallpaperCacheService.isSelectable(nextUrl))
                continue;

            WallpaperSettings.setSelectedFile(nextUrl);
            return;
        }
    }

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
        enabled: root.interactive
        onDismissed: root.closeSwitcher()
    }

    onOpenChanged: {
        if (!root.open)
            return;

        // Cache discovery is deliberately deferred during shell startup. An
        // explicit panel open makes it user-facing work and accelerates it.
        WallpaperController.expediteWallpaperVideoReconcile();
        WallpaperCacheService.expeditePendingWork();

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

            RowLayout {
                Layout.fillWidth: true

                M3Text {
                    text: qsTr("Wallpapers")
                    color: Theme.scheme.onSurface
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "refresh"
                    iconSize: 20
                    enabled: !WallpaperCacheService.busy && WallpaperCacheService.knownSources.length > 0
                    Accessible.name: qsTr("Rebuild video cache")
                    ToolTip.visible: hovered
                    ToolTip.delay: 350
                    ToolTip.text: qsTr("Delete cached videos and transcode them again")
                    onClicked: WallpaperCacheService.rebuild()
                }
            }

            Connections {
                target: root.wallpaperModel

                function onFolderChanged(): void {
                    root.failedWallpapers = ({});
                }

                function onStatusChanged(): void {
                    if (root.wallpaperModel.status === FolderListModel.Ready && root.open)
                        Qt.callLater(root.positionListAtTop);
                }
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
                cacheBuffer: Math.max(0, Math.round(height * 0.25))
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

                    readonly property bool isVideo: WallpaperCacheService.isVideo(fileUrl)
                    readonly property var wallpaperVideoEntry: isVideo ? WallpaperCacheService.entryFor(fileUrl) : null
                    readonly property string cacheStatus: String(wallpaperVideoEntry?.status ?? "checking")
                    readonly property string thumbPath: isVideo
                        ? (wallpaperVideoEntry?.thumbnailStatus === "ready"
                            ? String(wallpaperVideoEntry.thumbnailSource ?? "") : "")
                        : String(fileUrl)
                    readonly property bool selectable: !isVideo || cacheStatus === "ready" || cacheStatus === "original"
                    readonly property bool preparing: isVideo && (cacheStatus === "checking" || cacheStatus === "queued" || cacheStatus === "converting")
                    readonly property bool conversionFailed: isVideo && (cacheStatus === "invalid" || cacheStatus === "failed")
                    readonly property real conversionProgress: Math.max(0, Math.min(1, Number(wallpaperVideoEntry?.progress ?? 0)))
                    readonly property bool conversionDeterminate: cacheStatus === "converting" && conversionProgress > 0
                    readonly property string preparationStatus: {
                        switch (cacheStatus) {
                        case "queued":
                            return qsTr("Queued");
                        case "converting":
                            return conversionDeterminate
                                ? qsTr("Converting %1%").arg(Math.round(conversionProgress * 100))
                                : qsTr("Converting");
                        default:
                            return qsTr("Checking");
                        }
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
                                cache: false
                                opacity: delegateRoot.selectable ? 1 : 0.55

                                onStatusChanged: {
                                    if (status === Image.Error && !delegateRoot.isVideo)
                                        root.markWallpaperFailed(delegateRoot.fileUrl);
                                }
                            }

                            M3Icon {
                                anchors.centerIn: parent
                                name: "movie"
                                size: 36
                                color: Theme.scheme.onSurface
                                visible: delegateRoot.isVideo && delegateRoot.selectable
                                filled: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.scheme.scrim
                                opacity: 0.32
                                visible: !delegateRoot.selectable
                            }

                            Loader {
                                id: progressLoader

                                anchors.centerIn: parent
                                width: Math.min(208, parent.width - Metrics.spacingLg * 2)
                                height: 52
                                active: delegateRoot.preparing
                                asynchronous: false

                                sourceComponent: Rectangle {
                                    radius: Metrics.radiusMd
                                    color: Theme.scheme.surfaceContainerHigh

                                    Column {
                                        width: parent.width - Metrics.spacingMd * 2
                                        anchors.centerIn: parent
                                        spacing: Metrics.spacingSm

                                        M3Text {
                                            width: parent.width
                                            text: delegateRoot.preparationStatus
                                            color: Theme.scheme.onSurface
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }

                                        M3ProgressBar {
                                            width: parent.width
                                            progress: delegateRoot.conversionProgress
                                            indeterminate: !delegateRoot.conversionDeterminate
                                            phaseOffset: (delegateRoot.index * 0.173) % 1
                                            accessibleName: delegateRoot.preparationStatus
                                        }
                                    }
                                }
                            }

                            M3Icon {
                                anchors.centerIn: parent
                                name: "error"
                                size: 34
                                color: Theme.scheme.error
                                visible: delegateRoot.conversionFailed
                                filled: true
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: delegateRoot.selectable ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            ToolTip.visible: containsMouse && !delegateRoot.selectable
                            ToolTip.delay: 350
                            ToolTip.text: WallpaperCacheService.statusText(delegateRoot.fileUrl)

                            onClicked: {
                                if (delegateRoot.selectable)
                                    root.selectWallpaper(delegateRoot.fileUrl, delegateRoot.isVideo);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Theme.scheme.onSurface
                                opacity: parent.containsMouse && delegateRoot.selectable ? 0.1 : 0.0
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
