pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.features.notifications.components
import qs.platform.notifications
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real overlayWidth: 400
    property real topMargin: Metrics.spacingSm
    property real rightMargin: Metrics.spacingMd
    property real maximumHeightRatio: 0.6
    property int maximumCollapsedGroups: 3
    property string expandedGroupKey: ""
    property var expansionOverridesByKey: ({})
    property var expandedNotificationsById: ({})
    property bool hidingByGesture: false

    readonly property real maximumOverlayHeight: root.screen ? Math.max(0, root.screen.height * root.maximumHeightRatio) : overlayColumn.implicitHeight
    readonly property var displayedGroupKeys: {
        const keys = NotificationOverlayController.notificationGroupKeys;
        if (root.expandedGroupKey.length > 0 && keys.includes(root.expandedGroupKey))
            return [root.expandedGroupKey];
        return keys.slice(0, root.maximumCollapsedGroups);
    }
    ListModel {
        id: overlayGroupModel
    }

    function syncOverlayModel() {
        NotificationController.reconcileKeyModel(overlayGroupModel, root.displayedGroupKeys);
    }

    onDisplayedGroupKeysChanged: root.syncOverlayModel()
    Component.onCompleted: root.syncOverlayModel()

    readonly property real targetOverlayHeight: Math.min(overlayColumn.implicitHeight, root.maximumOverlayHeight)

    open: NotificationOverlayController.visibleRequested && !SurfaceController.notificationPanelOpen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    transitionsEnabled: true
    implicitWidth: root.overlayWidth
    // The layer surface never participates in content animation. Only the
    // inner presentation changes size, avoiding Wayland configure loops.
    implicitHeight: root.maximumOverlayHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    onTransitionRequested: (entering, generation) => overlayTransition.transition(entering, generation)
    interactiveMask: Region {
        item: overlayViewport
    }

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.topMargin
        right: root.rightMargin
    }

    function groupExpanded(group): bool {
        if (!group)
            return false;
        if (Object.prototype.hasOwnProperty.call(root.expansionOverridesByKey, group.key))
            return Boolean(root.expansionOverridesByKey[group.key]);
        if (root.expandedGroupKey.length > 0)
            return root.expandedGroupKey === group.key;
        return root.displayedGroupKeys.length === 1 && group.notifications.length === 1;
    }

    function toggleGroupExpanded(group) {
        if (!group)
            return;

        const key = String(group.key);
        const expanded = !root.groupExpanded(group);
        const overrides = Object.assign({}, root.expansionOverridesByKey);
        overrides[key] = expanded;
        root.expansionOverridesByKey = overrides;
        root.expandedGroupKey = expanded ? key : "";
    }

    function notificationExpanded(notification): bool {
        return Boolean(root.expandedNotificationsById[NotificationController.notificationKey(notification)]);
    }

    function toggleNotificationExpanded(notification) {
        const key = NotificationController.notificationKey(notification);
        if (key.length === 0)
            return;

        const expanded = Object.assign({}, root.expandedNotificationsById);
        if (expanded[key])
            delete expanded[key];
        else
            expanded[key] = true;
        root.expandedNotificationsById = expanded;
    }

    function finishVerticalGesture() {
        const dismissDistance = Math.min(96, overlayViewport.height / 3);
        root.hidingByGesture = overlayGesturePresentation.offsetY <= -dismissDistance;
        gestureSettle.to = root.hidingByGesture ? -overlayViewport.height : 0;
        gestureSettle.restart();
    }

    Connections {
        target: NotificationOverlayController

        function onExpansionRevisionChanged() {
            root.expandedGroupKey = "";
            root.expansionOverridesByKey = ({});
            root.expandedNotificationsById = ({});
        }
    }

    Connections {
        target: SurfaceController

        function onNotificationPanelOpenChanged() {
            if (SurfaceController.notificationPanelOpen)
                NotificationOverlayController.hide();
        }
    }

    Item {
        id: overlayViewport

        anchors {
            top: parent.top
            right: parent.right
        }
        width: root.overlayWidth
        height: root.targetOverlayHeight
        clip: true

        PresentationLayer {
            id: overlayPresentation

            anchors.fill: parent

            PresentationLayer {
                id: overlayGesturePresentation

                anchors.fill: parent

                Column {
                    id: overlayColumn

                    width: root.overlayWidth
                    spacing: Metrics.spacingSm

                    Repeater {
                        model: overlayGroupModel

                        delegate: NotificationCard {
                            required property string key

                            width: overlayColumn.width
                            group: NotificationOverlayController.notificationGroupsByKey[key]
                            expanded: root.groupExpanded(group)
                            surfaceVisible: true
                            memberSwipeEnabled: expanded
                            dismissLeftEnabled: false
                            maximumGroupContentHeight: Math.max(120, root.maximumOverlayHeight - 96)
                            isMemberExpanded: notification => root.notificationExpanded(notification)
                            toggleMemberExpanded: notification => root.toggleNotificationExpanded(notification)
                            onExpansionRequested: root.toggleGroupExpanded(group)
                            onDismissRequested: {
                                if (group)
                                    NotificationOverlayController.dismissGroup(group);
                            }
                        }
                    }
                }
            }
        }

        // A handler on the shared ancestor observes vertical drags without
        // covering buttons or the expanded member viewport.
        DragHandler {
            id: verticalHideHandler

            target: null
            enabled: root.interactive && !root.hidingByGesture
            xAxis.enabled: false
            yAxis.enabled: true
            onActiveChanged: {
                if (active) {
                    gestureSettle.stop();
                    NotificationOverlayController.setHovered(true);
                } else {
                    root.finishVerticalGesture();
                }
            }
            onTranslationChanged: {
                if (active)
                    overlayGesturePresentation.offsetY = Math.min(0, activeTranslation.y);
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (!verticalHideHandler.active)
                    NotificationOverlayController.setHovered(hovered);
            }
        }

        NumberAnimation {
            id: gestureSettle

            target: overlayGesturePresentation
            property: "offsetY"
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
            onFinished: {
                if (root.hidingByGesture)
                    NotificationOverlayController.hide();
            }
        }
    }

    SlideTransition {
        id: overlayTransition

        target: overlayPresentation
        hiddenOffsetY: -(root.targetOverlayHeight + root.topMargin + 5)
        easingType: Motion.easingEmphasized
        easingCurve: Motion.emphasizedCurve
        onTransitionFinished: generation => root.completeTransition(generation)
    }

    onFullyClosed: {
        overlayGesturePresentation.offsetY = 0;
        root.hidingByGesture = false;
        NotificationOverlayController.completeExit();
    }
}
