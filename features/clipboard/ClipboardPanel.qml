pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.features.clipboard.components
import qs.platform.clipboard
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real clipboardWidth: 450
    property int maximumVisibleEntries: 5
    property int entryRowHeight: 56
    property real lastPointerSceneX: NaN
    property real lastPointerSceneY: NaN

    open: SurfaceController.clipboardOpen
    targetScreen: SurfaceController.clipboardScreen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    transitionsEnabled: true
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-clipboard"
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    ClipboardController {
        id: controller

        query: searchField.text
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            SurfaceController.openClipboard(root.fallbackScreen);
        }

        function close(): void {
            SurfaceController.closeClipboard();
        }

        function toggle(): void {
            if (SurfaceController.clipboardOpen)
                SurfaceController.closeClipboard();
            else
                SurfaceController.openClipboard(root.fallbackScreen);
        }

        function clear(): void {
            ClipboardService.clear();
        }
    }

    function closeClipboard() {
        SurfaceController.closeClipboard();
    }

    function copyEntry(entry) {
        if (!entry || !ClipboardService.copy(entry))
            return;

        root.closeClipboard();
    }

    function updateSelectionFromPointer(panelPosition, scenePosition) {
        const currentSceneX = Number(scenePosition.x);
        const currentSceneY = Number(scenePosition.y);
        const pointerPositionKnown = Number.isFinite(root.lastPointerSceneX) && Number.isFinite(root.lastPointerSceneY);
        const pointerMoved = pointerPositionKnown && (root.lastPointerSceneX !== currentSceneX || root.lastPointerSceneY !== currentSceneY);
        root.lastPointerSceneX = currentSceneX;
        root.lastPointerSceneY = currentSceneY;

        if (!pointerMoved || !entriesView.visible || entriesView.moving)
            return;

        const entriesPosition = entriesView.mapFromItem(panelSurface, panelPosition);
        if (!entriesView.contains(entriesPosition))
            return;

        const hoveredIndex = entriesView.indexAt(entriesPosition.x + entriesView.contentX, entriesPosition.y + entriesView.contentY);
        if (hoveredIndex >= 0)
            controller.currentIndex = hoveredIndex;
    }

    function resetEntriesScroll() {
        entriesView.cancelFlick();
        entriesView.positionViewAtBeginning();
        entriesView.contentY = entriesView.originY;
    }

    onOpenChanged: {
        root.lastPointerSceneX = NaN;
        root.lastPointerSceneY = NaN;
        root.resetEntriesScroll();

        if (root.open) {
            ClipboardService.refresh();
            controller.resetSelection();
            searchField.forceActiveFocus(Qt.PopupFocusReason);
        }
    }

    onFullyClosed: searchField.clear()

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
        enabled: root.interactive
        onDismissed: root.closeClipboard()
    }

    M3Surface {
        id: panelSurface

        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 6
            bottomMargin: 6
        }
        width: Math.min(root.clipboardWidth, Math.max(0, root.width - Metrics.spacingXl * 2))
        height: clipboardContent.implicitHeight + Metrics.spacingLg * 2
        radius: 16
        HoverHandler {
            id: pointerSelectionHandler

            enabled: root.open
            onPointChanged: root.updateSelectionFromPointer(pointerSelectionHandler.point.position, pointerSelectionHandler.point.scenePosition)
        }

        ColumnLayout {
            id: clipboardContent

            anchors {
                top: parent.top
                right: parent.right
                left: parent.left
                margins: Metrics.spacingLg
            }
            spacing: Metrics.spacingMd

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingMd

                M3TextField {
                    id: searchField

                    Layout.fillWidth: true
                    focus: root.open
                    leadingIconName: "search"
                    clearButtonEnabled: true
                    placeholderText: qsTr("Search clipboard")
                    Accessible.name: qsTr("Search clipboard history")

                    Keys.onEscapePressed: event => {
                        root.closeClipboard();
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        controller.moveSelection(1);
                        entriesView.positionViewAtIndex(controller.currentIndex, ListView.Contain);
                        event.accepted = true;
                    }
                    Keys.onUpPressed: event => {
                        controller.moveSelection(-1);
                        entriesView.positionViewAtIndex(controller.currentIndex, ListView.Contain);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: event => {
                        root.copyEntry(controller.currentEntry);
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        root.copyEntry(controller.currentEntry);
                        event.accepted = true;
                    }
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "clear_all"
                    iconSize: 24
                    enabled: ClipboardService.entries.length > 0 && !ClipboardService.busy
                    Accessible.name: qsTr("Clear clipboard history")
                    onClicked: ClipboardService.clear()

                    ToolTip {
                        visible: parent.hovered && parent.enabled
                        text: qsTr("Clear clipboard history")
                        delay: 250
                        padding: Metrics.spacingSm

                        contentItem: M3Text {
                            text: qsTr("Clear clipboard history")
                            color: Theme.scheme.inverseOnSurface
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        background: Rectangle {
                            color: Theme.scheme.inverseSurface
                            radius: 4
                        }
                    }
                }
            }

            ListView {
                id: entriesView

                readonly property real naturalHeight: count > 0 ? count * root.entryRowHeight + Math.max(0, count - 1) * spacing : 0
                readonly property real maximumViewportHeight: root.maximumVisibleEntries * root.entryRowHeight + Math.max(0, root.maximumVisibleEntries - 1) * spacing

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Math.min(entriesView.naturalHeight, entriesView.maximumViewportHeight) : 0
                visible: controller.results.length > 0
                model: controller.results
                spacing: Metrics.spacingXs
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: controller.currentIndex
                reuseItems: true
                cacheBuffer: entriesView.maximumViewportHeight
                onModelChanged: root.resetEntriesScroll()

                delegate: ClipboardEntry {
                    required property int index
                    required property var modelData

                    width: entriesView.width
                    height: root.entryRowHeight
                    entry: modelData
                    selected: index === controller.currentIndex
                    onClicked: root.copyEntry(modelData)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 104 : 0
                visible: controller.results.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.spacingSm

                    M3Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: ClipboardService.loading ? "sync" : "content_paste_off"
                        size: 32
                        color: Theme.scheme.onSurfaceVariant
                    }

                    M3Text {
                        text: ClipboardService.available ? qsTr("No clipboard entries found") : qsTr("Clipboard history unavailable")
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
        hiddenOffsetY: panelSurface.height + panelSurface.anchors.bottomMargin + 5
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
