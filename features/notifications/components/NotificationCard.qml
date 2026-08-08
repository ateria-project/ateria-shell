pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.features.notifications
import qs.platform.notifications
import qs.theme

// Stable notification presentation. Only the active presentation is kept
// instantiated; the outer swipe container remains the single owner of card
// geometry and dismissal motion.
Item {
    id: root

    required property var group
    property bool expanded: false
    property var isMemberExpanded: notification => NotificationController.isExpanded(notification)
    property var toggleMemberExpanded: notification => NotificationController.toggleExpanded(notification)
    property bool memberSwipeEnabled: false
    property bool swipeEnabled: !root.grouped || !root.expanded
    property bool dismissLeftEnabled: true
    property bool showSeparator: false
    property bool drawSeparator: false
    property bool surfaceVisible: false
    property real maximumGroupContentHeight: 0
    property color surfaceColor: Theme.scheme.surfaceContainerHigh
    property color toggleContainerColor: Theme.scheme.surfaceContainerHighest

    readonly property bool grouped: Boolean(root.group && root.group.notifications && root.group.notifications.length > 1)
    readonly property var notification: root.group && root.group.notifications ? root.group.notifications[0] : null
    readonly property string groupKey: root.group ? String(root.group.key || "") : ""
    readonly property bool hovered: cardHoverHandler.hovered
    readonly property real targetContentHeight: contentLoader.height

    signal expansionRequested
    signal dismissRequested(string groupKey)

    implicitHeight: swipeContainer.implicitHeight

    function resetPosition() {
        swipeContainer.resetPosition();
    }

    function dismissAnimated(direction: int) {
        swipeContainer.dismissAnimated(direction);
    }

    function dismissMember(notification) {
        NotificationService.dismiss(notification);
    }

    onGroupKeyChanged: root.resetPosition()

    SwipeToDismiss {
        id: swipeContainer

        anchors.fill: parent
        contentHeight: root.targetContentHeight
        swipeEnabled: root.swipeEnabled
        dismissLeftEnabled: root.dismissLeftEnabled
        showSeparator: root.showSeparator
        collapseOnDismiss: true
        onDismissed: root.dismissRequested(root.groupKey)

        M3Panel {
            anchors.fill: parent
            radius: Metrics.radiusLg
            color: root.surfaceColor
            visible: root.surfaceVisible
        }

        // NotificationGroup and NotificationItem are both relatively heavy
        // controls. Keeping only the active one removes an entire hidden
        // layout/binding tree from every card without changing expand motion.
        Loader {
            id: contentLoader

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: item ? item.implicitHeight : 0
            focus: true
            asynchronous: false
            sourceComponent: root.grouped ? groupedComponent : singleComponent
        }
    }

    Component {
        id: groupedComponent

        NotificationGroup {
            group: root.group
            expanded: root.expanded
            showSeparator: root.showSeparator
            drawSeparator: root.drawSeparator
            maximumExpandedHeight: root.maximumGroupContentHeight
            toggleContainerColor: root.toggleContainerColor
            isMemberExpanded: root.isMemberExpanded
            toggleMemberExpanded: root.toggleMemberExpanded
            memberSwipeEnabled: root.memberSwipeEnabled
            dismissMember: root.dismissMember
            onExpansionRequested: root.expansionRequested()
        }
    }

    Component {
        id: singleComponent

        NotificationItem {
            notification: root.notification
            expanded: root.expanded
            relativeTime: NotificationController.relativeTime(notification)
            showSeparator: root.showSeparator
            drawSeparator: root.drawSeparator
            toggleContainerColor: root.toggleContainerColor
            onExpansionRequested: root.expansionRequested()
        }
    }

    HoverHandler {
        id: cardHoverHandler
    }
}
