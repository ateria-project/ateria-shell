pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.features.launcher.components
import qs.platform.compositor
import qs.shell
import qs.theme

PanelWindow {
    id: root

    property bool open: SurfaceController.launcherOpen
    property real launcherWidth: 600
    property int maximumVisibleResults: 6
    property int resultRowHeight: 56
    property real lastPointerSceneX: NaN
    property real lastPointerSceneY: NaN

    readonly property string focusedOutputName: {
        const focusedWorkspace = NiriService.workspaces.find(workspace => {
            return workspace.focused;
        });
        return focusedWorkspace ? focusedWorkspace.output : "";
    }
    readonly property var preferredScreen: {
        const screens = Quickshell.screens;
        const focusedScreen = screens.find(candidate => {
            return candidate.name === root.focusedOutputName;
        });
        return focusedScreen ?? SurfaceController.activeScreen ?? (screens.length > 0 ? screens[0] : null);
    }

    screen: SurfaceController.activeScreen ?? root.preferredScreen
    visible: root.open || panelSurface.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-launcher"

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    LauncherController {
        id: controller

        query: searchField.text
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            SurfaceController.openLauncher(root.preferredScreen);
        }

        function close(): void {
            SurfaceController.closeLauncher();
        }

        function toggle(): void {
            if (SurfaceController.launcherOpen)
                SurfaceController.closeLauncher();
            else
                SurfaceController.openLauncher(root.preferredScreen);
        }
    }

    function closeLauncher() {
        SurfaceController.closeLauncher();
    }

    function launch(desktopEntry) {
        if (!desktopEntry)
            return;

        LauncherSettings.recordLaunch(desktopEntry);
        SurfaceController.closeLauncher();
        desktopEntry.execute();
    }

    function updateSelectionFromPointer(panelPosition, scenePosition) {
        const currentSceneX = Number(scenePosition.x);
        const currentSceneY = Number(scenePosition.y);
        const pointerPositionKnown = Number.isFinite(root.lastPointerSceneX) && Number.isFinite(root.lastPointerSceneY);
        const pointerMoved = pointerPositionKnown && (root.lastPointerSceneX !== currentSceneX || root.lastPointerSceneY !== currentSceneY);
        root.lastPointerSceneX = currentSceneX;
        root.lastPointerSceneY = currentSceneY;

        // Hover state can change when search results move underneath a
        // stationary pointer. Only an actual scene-position change should move
        // the selection away from the first search result.
        if (!pointerMoved)
            return;

        if (!resultsView.visible || resultsView.moving)
            return;

        const resultsPosition = resultsView.mapFromItem(panelSurface, panelPosition);
        if (!resultsView.contains(resultsPosition))
            return;

        const hoveredIndex = resultsView.indexAt(resultsPosition.x + resultsView.contentX, resultsPosition.y + resultsView.contentY);
        if (hoveredIndex >= 0)
            controller.currentIndex = hoveredIndex;
    }

    function resetResultsScroll() {
        resultsView.cancelFlick();
        resultsView.positionViewAtBeginning();
        resultsView.contentY = resultsView.originY;
    }

    onOpenChanged: {
        root.lastPointerSceneX = NaN;
        root.lastPointerSceneY = NaN;
        root.resetResultsScroll();

        if (root.open) {
            controller.refreshUsageRanking();
            controller.resetSelection();
            Qt.callLater(() => searchField.forceActiveFocus());
        }
    }

    onVisibleChanged: {
        if (!root.visible && !root.open)
            searchField.clear();
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Theme.scheme.scrim
        opacity: root.open ? 0.2 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.durationShort
                easing.type: root.open ? Motion.easingStandardDecelerate : Motion.easingStandardAccelerate
                easing.bezierCurve: root.open ? Motion.standardDecelerateCurve : Motion.standardAccelerateCurve
            }
        }
    }

    MouseArea {
        anchors {
            top: parent.top
            right: parent.right
            bottom: panelSurface.top
            left: parent.left
        }
        onClicked: root.closeLauncher()
    }

    MouseArea {
        anchors {
            top: panelSurface.bottom
            right: parent.right
            bottom: parent.bottom
            left: parent.left
        }
        onClicked: root.closeLauncher()
    }

    MouseArea {
        anchors {
            top: panelSurface.top
            right: panelSurface.left
            bottom: panelSurface.bottom
            left: parent.left
        }
        onClicked: root.closeLauncher()
    }

    MouseArea {
        anchors {
            top: panelSurface.top
            right: parent.right
            bottom: panelSurface.bottom
            left: panelSurface.right
        }
        onClicked: root.closeLauncher()
    }

    M3Panel {
        id: panelSurface

        anchors.centerIn: parent
        width: Math.min(root.launcherWidth, Math.max(0, root.width - Metrics.spacingXl * 2))
        height: launcherContent.implicitHeight + Metrics.spacingLg * 2
        radius: Metrics.radiusXl
        clip: true
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94

        Behavior on height {
            NumberAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.open ? Motion.durationMedium : Motion.durationShort
                easing.type: root.open ? Motion.easingStandardDecelerate : Motion.easingStandardAccelerate
                easing.bezierCurve: root.open ? Motion.standardDecelerateCurve : Motion.standardAccelerateCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? Motion.durationMedium : Motion.durationShort
                easing.type: root.open ? Motion.easingStandardDecelerate : Motion.easingStandardAccelerate
                easing.bezierCurve: root.open ? Motion.standardDecelerateCurve : Motion.standardAccelerateCurve
            }
        }

        HoverHandler {
            id: pointerSelectionHandler

            enabled: root.open
            onPointChanged: root.updateSelectionFromPointer(pointerSelectionHandler.point.position, pointerSelectionHandler.point.scenePosition)
        }

        ColumnLayout {
            id: launcherContent

            anchors {
                top: parent.top
                right: parent.right
                left: parent.left
                margins: Metrics.spacingLg
            }
            spacing: Metrics.spacingMd

            M3TextField {
                id: searchField

                Layout.fillWidth: true
                focus: root.open
                leadingIconName: "search"
                clearButtonEnabled: true
                placeholderText: qsTr("Search applications")
                Accessible.name: qsTr("Search applications")

                Keys.onEscapePressed: event => {
                    root.closeLauncher();
                    event.accepted = true;
                }
                Keys.onDownPressed: event => {
                    controller.moveSelection(1);
                    resultsView.positionViewAtIndex(controller.currentIndex, ListView.Contain);
                    event.accepted = true;
                }
                Keys.onUpPressed: event => {
                    controller.moveSelection(-1);
                    resultsView.positionViewAtIndex(controller.currentIndex, ListView.Contain);
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    root.launch(controller.currentApplication);
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    root.launch(controller.currentApplication);
                    event.accepted = true;
                }
            }

            ListView {
                id: resultsView

                readonly property real naturalHeight: count > 0 ? count * root.resultRowHeight + Math.max(0, count - 1) * spacing : 0
                readonly property real maximumViewportHeight: root.maximumVisibleResults * root.resultRowHeight + Math.max(0, root.maximumVisibleResults - 1) * spacing

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Math.min(resultsView.naturalHeight, resultsView.maximumViewportHeight) : 0
                visible: controller.results.length > 0
                model: controller.results
                spacing: Metrics.spacingXs
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: controller.currentIndex
                reuseItems: true
                cacheBuffer: resultsView.maximumViewportHeight
                onModelChanged: root.resetResultsScroll()

                delegate: LauncherResult {
                    required property int index
                    required property var modelData

                    width: resultsView.width
                    height: root.resultRowHeight
                    desktopEntry: modelData
                    selected: index === controller.currentIndex
                    onClicked: root.launch(modelData)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 112 : 0
                visible: controller.results.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.spacingSm

                    M3Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "search_off"
                        size: 32
                        color: Theme.scheme.onSurfaceVariant
                    }

                    M3Text {
                        text: qsTr("No applications found")
                        color: Theme.scheme.onSurfaceVariant
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
