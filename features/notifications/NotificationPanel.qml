pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import qs.components
import qs.features.notifications.components
import qs.platform.notifications
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    // Set panelHeight to 0 to use the bounded default height.
    property real panelWidth: 420
    property real panelHeight: 0
    property real fallbackPanelHeight: 480
    property real minimumViewportHeight: 80
    property real maximumHeightRatio: 0.6
    readonly property real maximumPanelHeight: root.screen
        ? Math.max(0, root.screen.height * root.maximumHeightRatio)
        : root.fallbackPanelHeight
    readonly property real footerHeight: NotificationService.hasNonTransientNotifications ? footer.implicitHeight : 0
    readonly property real footerSpacing: NotificationService.hasNonTransientNotifications ? Metrics.spacingSm : 0
    readonly property real maximumViewportHeight: Math.max(
        root.minimumViewportHeight,
        root.maximumPanelHeight - Metrics.spacingMd * 2 - root.footerHeight - root.footerSpacing
    )
    readonly property real contentViewportHeight: NotificationService.hasNonTransientNotifications
        ? Math.min(
            Math.max(root.minimumViewportHeight, notificationViewport.contentHeight),
            root.maximumViewportHeight
        )
        : Math.max(root.minimumViewportHeight, emptyState.implicitHeight + Metrics.spacingLg * 2)
    readonly property real naturalPanelHeight: root.contentViewportHeight
        + root.footerHeight
        + root.footerSpacing
        + Metrics.spacingMd * 2
    readonly property real targetPanelHeight: Math.min(
        root.panelHeight > 0 ? root.panelHeight : root.naturalPanelHeight,
        root.maximumPanelHeight
    )

    open: SurfaceController.notificationPanelOpen
    targetScreen: SurfaceController.notificationPanelScreen
    implicitWidth: root.panelWidth
    // Keep the native layer surface stable. The inner viewport can follow
    // content without issuing a Wayland configure.
    implicitHeight: root.maximumPanelHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    DismissibleOverlay {
        excludedItem: panelSurface
        enabled: root.interactive
        onDismissed: SurfaceController.closeNotificationPanel()
    }

    M3Surface {
        id: panelSurface

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 6
            rightMargin: 6
        }
        width: root.panelWidth
        // Only this inner item follows the bounded content height.
        height: root.targetPanelHeight
        radius: Metrics.radiusLg
        color: Theme.scheme.surfaceContainer
        ColumnLayout {
            id: panelContent

            anchors {
                fill: parent
                margins: Metrics.spacingMd
            }
            spacing: Metrics.spacingSm

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: root.contentViewportHeight
                radius: Metrics.radiusMd
                color: Theme.scheme.surfaceContainerHighest
                clip: true

                ListView {
                    id: notificationViewport

                    anchors.fill: parent
                    visible: NotificationService.hasNonTransientNotifications
                    model: NotificationController.notificationGroups
                    reuseItems: true
                    cacheBuffer: 128
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: SwipeToDismiss {
                        id: notificationDelegate

                        required property int index
                        required property var modelData
                        readonly property var notificationGroupData: modelData
                        readonly property bool grouped: notificationDelegate.notificationGroupData.notifications.length > 1
                        readonly property Item loadedNotification: notificationLoader.item

                        width: ListView.view.width
                        height: notificationDelegate.loadedNotification
                            ? notificationDelegate.loadedNotification.implicitHeight
                            : 0
                        swipeEnabled: true
                        showSeparator: notificationDelegate.index < NotificationController.notificationGroups.length - 1
                        ListView.onPooled: notificationDelegate.resetPosition()
                        ListView.onReused: notificationDelegate.resetPosition()
                        onDismissed: {
                            if (notificationDelegate.grouped)
                                NotificationService.dismissMany(notificationDelegate.notificationGroupData.notifications);
                            else
                                NotificationService.dismiss(notificationDelegate.notificationGroupData.notifications[0]);
                        }

                        Loader {
                            id: notificationLoader
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            asynchronous: false
                            sourceComponent: notificationDelegate.grouped
                                ? groupedNotificationComponent
                                : singleNotificationComponent
                        }

                        Component {
                            id: groupedNotificationComponent

                            NotificationGroup {
                                group: notificationDelegate.notificationGroupData
                                toggleContainerColor: Theme.scheme.surfaceVariant
                                expanded: NotificationController.isGroupExpanded(group)
                                showSeparator: notificationDelegate.index < NotificationController.notificationGroups.length - 1
                                drawSeparator: false
                                memberSwipeEnabled: expanded
                                dismissMember: notification => NotificationService.dismiss(notification)
                                onExpansionRequested: NotificationController.toggleGroupExpanded(group)
                            }
                        }

                        Component {
                            id: singleNotificationComponent

                            NotificationItem {
                                notification: notificationDelegate.notificationGroupData.notifications[0]
                                toggleContainerColor: Theme.scheme.surfaceVariant
                                expanded: NotificationController.isExpanded(notification)
                                relativeTime: NotificationController.relativeTime(notification)
                                showSeparator: notificationDelegate.index < NotificationController.notificationGroups.length - 1
                                drawSeparator: false
                                onExpansionRequested: NotificationController.toggleExpanded(notification)
                            }
                        }
                    }

                    ScrollBar.vertical: M3ScrollBar {}
                }

                Column {
                    id: emptyState

                    anchors.centerIn: parent
                    visible: !NotificationService.hasNonTransientNotifications
                    spacing: Metrics.spacingSm

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: 48
                        implicitHeight: 48

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.scheme.surfaceContainerHighest

                            M3Icon {
                                anchors.centerIn: parent
                                name: "notifications_none"
                                size: 26
                                color: Theme.scheme.onSurfaceVariant
                            }
                        }
                    }

                    M3Text {
                        text: qsTr("No notifications")
                        color: Theme.scheme.onSurfaceVariant
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }
            }

            Item {
                id: footer

                visible: NotificationService.hasNonTransientNotifications
                implicitHeight: clearAllButton.implicitHeight
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight

                M3Button {
                    id: clearAllButton

                    anchors.right: parent.right
                    text: qsTr("Clear all")
                    style: M3Button.Text
                    implicitHeight: 34
                    onClicked: NotificationService.dismissAll()
                }
            }
        }
    }
}
