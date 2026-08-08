pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.features.notifications.components
import qs.platform.workspace
import qs.platform.notifications
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real overlayWidth: 400
    property real topMargin: Metrics.spacingSm
    property real rightMargin: Metrics.spacingMd
    property real maximumHeightRatio: 0.6
    property real maximumOverlayHeight: root.screen ? Math.max(0, root.screen.height * root.maximumHeightRatio) : overlayColumn.implicitHeight
    readonly property real targetOverlayHeight: Math.min(overlayColumn.implicitHeight, root.maximumOverlayHeight)
    property var expandedGroupsByKey: ({})
    property var expandedNotificationsById: ({})
    property var hoveredGroupsByKey: ({})

    readonly property var protectedGroupKeys: {
        const groups = NotificationOverlayController.notificationGroups;
        const hoveredGroups = root.hoveredGroupsByKey;
        const protectedGroups = {};

        for (const group of groups) {
            if (hoveredGroups[group.key])
                protectedGroups[group.key] = true;
        }

        return protectedGroups;
    }

    open: NotificationOverlayController.hasNotifications && !SurfaceController.notificationPanelOpen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    implicitWidth: root.overlayWidth
    // Keep the native layer surface stable; only the masked viewport follows
    // notification content size.
    implicitHeight: root.maximumOverlayHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
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

        if (Object.prototype.hasOwnProperty.call(root.expandedGroupsByKey, group.key))
            return Boolean(root.expandedGroupsByKey[group.key]);

        const groups = NotificationOverlayController.notificationGroups;
        return groups.length > 0
            && groups[0].key === group.key
            && group.notifications.length === 1;
    }

    function toggleGroupExpanded(group) {
        if (!group)
            return;

        const nextExpanded = Object.assign({}, root.expandedGroupsByKey);
        nextExpanded[group.key] = !root.groupExpanded(group);
        root.expandedGroupsByKey = nextExpanded;
    }

    function setGroupHovered(key: string, hovered: bool) {
        if (key.length === 0)
            return;
        if (Boolean(root.hoveredGroupsByKey[key]) === hovered)
            return;

        const nextHoveredGroups = Object.assign({}, root.hoveredGroupsByKey);
        if (hovered)
            nextHoveredGroups[key] = true;
        else
            delete nextHoveredGroups[key];
        root.hoveredGroupsByKey = nextHoveredGroups;
    }

    function retainHoveredGroups() {
        const activeGroups = {};
        for (const group of NotificationOverlayController.notificationGroups)
            activeGroups[group.key] = true;

        const nextHoveredGroups = {};
        for (const key of Object.keys(root.hoveredGroupsByKey)) {
            if (activeGroups[key] && root.hoveredGroupsByKey[key])
                nextHoveredGroups[key] = true;
        }
        root.hoveredGroupsByKey = nextHoveredGroups;
    }

    function notificationExpanded(notification): bool {
        const key = NotificationController.notificationKey(notification);
        return Boolean(root.expandedNotificationsById[key]);
    }

    function toggleNotificationExpanded(notification) {
        const key = NotificationController.notificationKey(notification);
        if (key.length === 0)
            return;

        const nextExpanded = Object.assign({}, root.expandedNotificationsById);
        if (nextExpanded[key])
            delete nextExpanded[key];
        else
            nextExpanded[key] = true;
        root.expandedNotificationsById = nextExpanded;
    }

    Connections {
        target: NotificationOverlayController

        function onExpansionRevisionChanged() {
            root.expandedGroupsByKey = ({});
            root.expandedNotificationsById = ({});
            root.retainHoveredGroups();
        }
    }

    onProtectedGroupKeysChanged: NotificationOverlayController.setProtectedGroupKeys(root.protectedGroupKeys)
    Component.onCompleted: NotificationOverlayController.setProtectedGroupKeys(root.protectedGroupKeys)
    Component.onDestruction: NotificationOverlayController.setProtectedGroupKeys(({}))

    Flickable {
        id: overlayViewport

        anchors {
            top: parent.top
            right: parent.right
        }
        width: root.overlayWidth
        // The viewport owns its content-derived height directly.
        height: root.targetOverlayHeight
        contentWidth: width
        contentHeight: overlayColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        Column {
            id: overlayColumn

            width: overlayViewport.width
            spacing: Metrics.spacingSm

            Repeater {
                // Visibility must not own delegate lifetime. Keeping the
                // cards mounted prevents model construction from changing
                // geometry during a future entrance.
                model: NotificationOverlayController.notificationGroups

                delegate: NotificationOverlayEntry {
                    required property int index
                    required property var modelData
                    readonly property var notificationGroupData: modelData

                    width: overlayColumn.width
                    group: notificationGroupData
                    expanded: root.groupExpanded(group)
                    isMemberExpanded: notification => root.notificationExpanded(notification)
                    toggleMemberExpanded: notification => root.toggleNotificationExpanded(notification)
                    onHoveredChanged: root.setGroupHovered(group.key, hovered)
                    onExpansionRequested: root.toggleGroupExpanded(group)
                    onDismissRequested: groupKey => {
                        root.setGroupHovered(groupKey, false);
                        if (group.notifications.length > 1) {
                            NotificationService.dismissMany(group.notifications);
                        } else {
                            NotificationService.dismiss(group.notifications[0]);
                        }
                    }
                    Component.onCompleted: root.setGroupHovered(group.key, hovered)
                }
            }
        }

        ScrollBar.vertical: M3ScrollBar {
            policy: overlayColumn.implicitHeight > overlayViewport.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }
    }
}
