pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.features.launcher.components
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real launcherWidth: 500
    property int maximumVisibleResults: 6
    property int resultRowHeight: 56
    property real lastPointerSceneX: NaN
    property real lastPointerSceneY: NaN

    open: SurfaceController.launcherOpen
    targetScreen: SurfaceController.launcherScreen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    transitionsEnabled: true
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-launcher"
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

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

    function closeLauncher() {
        SurfaceController.closeLauncher();
    }

    // tools/ateria-shell applies shell-specific tuning (one EGL vendor and a
    // bounded jemalloc arena set). Do not leak that tuning into applications
    // the user launches, since they may legitimately want the other GPU or
    // their own allocator settings. Matching DesktopEntry::execute() also
    // preserves its detached launch semantics.
    readonly property bool runtimeTuningApplied: {
        const egl = String(Quickshell.env("ATERIA_EGL_VENDOR_APPLIED") ?? "");
        const malloc = String(Quickshell.env("ATERIA_MALLOC_CONF_APPLIED") ?? "");
        return egl === "1" || malloc === "1";
    }

    function launch(desktopEntry) {
        if (!desktopEntry)
            return;

        LauncherSettings.recordLaunch(desktopEntry);
        SurfaceController.closeLauncher();

        if (root.runtimeTuningApplied
                && desktopEntry.command
                && desktopEntry.command.length > 0) {
            const command = [
                "sh", "-c",
                'wd=$1; shift; if [ -n "$wd" ]; then cd "$wd" || exit 1; fi; '
                    + 'if [ "${ATERIA_EGL_VENDOR_APPLIED:-}" = 1 ]; then unset __EGL_VENDOR_LIBRARY_FILENAMES; fi; '
                    + 'if [ "${ATERIA_MALLOC_CONF_APPLIED:-}" = 1 ]; then unset MALLOC_CONF; fi; '
                    + 'unset ATERIA_EGL_VENDOR_APPLIED ATERIA_MALLOC_CONF_APPLIED; exec "$@"',
                "ateria-launcher", desktopEntry.workingDirectory ?? ""
            ];
            for (let index = 0; index < desktopEntry.command.length; ++index)
                command.push(desktopEntry.command[index]);
            Quickshell.execDetached(command);
            return;
        }

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
            searchField.forceActiveFocus(Qt.PopupFocusReason);
        }
    }

    onFullyClosed: searchField.clear()

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
        enabled: root.interactive
        onDismissed: root.closeLauncher()
    }

    M3Surface {
        id: panelSurface

        anchors {
            top: parent.top
            left: parent.left
            topMargin: 6
            leftMargin: 6
        }
        width: Math.min(root.launcherWidth, Math.max(0, root.width - Metrics.spacingXl * 2))
        height: launcherContent.implicitHeight + Metrics.spacingLg * 2
        radius: 16
        contentClipped: panelHeightAnimation.running

        Behavior on height {
            PanelResizeAnimation { id: panelHeightAnimation }
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

    SlideTransition {
        id: panelTransition

        target: panelSurface.presentationItem
        hiddenOffsetY: -(panelSurface.height + panelSurface.anchors.topMargin + 5)
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
