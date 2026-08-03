pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.features.notifications
import qs.theme

Item {
    id: root

    required property var group
    property bool expanded: false
    property var isMemberExpanded: notification => false
    property var toggleMemberExpanded: notification => {}

    readonly property bool grouped: Boolean(root.group && root.group.notifications && root.group.notifications.length > 1)
    readonly property var notification: root.group && root.group.notifications ? root.group.notifications[0] : null
    readonly property string groupKey: root.group ? String(root.group.key || "") : ""
    readonly property bool hovered: overlayHoverHandler.hovered
    readonly property Item loadedNotification: notificationLoader.item

    signal expansionRequested
    signal dismissRequested(string groupKey)

    implicitHeight: root.loadedNotification ? root.loadedNotification.implicitHeight : 0

    SwipeToDismiss {
        anchors.fill: parent
        swipeEnabled: !root.grouped || !root.expanded
        onDismissed: root.dismissRequested(root.groupKey)

        M3Panel {
            anchors.fill: parent
            radius: Metrics.radiusLg
            color: Theme.scheme.surfaceContainerHigh
        }

        Loader {
            id: notificationLoader

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            sourceComponent: root.grouped ? groupedNotificationComponent : singleNotificationComponent
        }

        Component {
            id: groupedNotificationComponent

            NotificationGroup {
                group: root.group
                expanded: root.expanded
                showSeparator: false
                isMemberExpanded: root.isMemberExpanded
                toggleMemberExpanded: root.toggleMemberExpanded
                memberSwipeEnabled: root.expanded
                dismissMember: notification => NotificationOverlayController.hideNotification(notification)
                onExpansionRequested: root.expansionRequested()
            }
        }

        Component {
            id: singleNotificationComponent

            NotificationItem {
                notification: root.notification
                expanded: root.expanded
                relativeTime: NotificationController.relativeTime(notification)
                showSeparator: false
                onExpansionRequested: root.expansionRequested()
            }
        }
    }

    HoverHandler {
        id: overlayHoverHandler
    }
}
