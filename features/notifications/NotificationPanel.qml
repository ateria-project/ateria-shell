import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.features.notifications.components
import qs.platform.notifications
import qs.shell
import qs.theme

PanelWindow {
    id: root

    property bool open: SurfaceController.notificationPanelOpen
    // Set panelHeight to 0 to size the panel from its content.
    property real panelWidth: 420
    property real panelHeight: 0
    property real maximumHeightRatio: 0.6
    readonly property real maximumPanelHeight: root.screen ? Math.max(0, root.screen.height * root.maximumHeightRatio) : panelContent.implicitHeight + Metrics.spacingMd * 2
    readonly property real naturalPanelHeight: panelContent.implicitHeight + Metrics.spacingMd * 2

    screen: SurfaceController.activeScreen
    visible: root.open
    implicitWidth: root.panelWidth
    implicitHeight: Math.min(root.panelHeight > 0 ? root.panelHeight : root.naturalPanelHeight, root.maximumPanelHeight)
    color: "transparent"
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: 6
        right: 6
    }

    M3Panel {
        id: panelSurface

        anchors.fill: parent
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
                id: notificationGroup

                readonly property real contentHeight: NotificationService.hasNonTransientNotifications ? notificationList.implicitHeight : emptyState.implicitHeight + Metrics.spacingLg * 2

                implicitHeight: Math.min(contentHeight, Math.max(0, root.maximumPanelHeight - footer.implicitHeight - Metrics.spacingMd * 2 - panelContent.spacing))
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: implicitHeight
                radius: Metrics.radiusMd
                color: Theme.scheme.surfaceContainerHighest
                clip: true

                Flickable {
                    id: notificationViewport

                    anchors.fill: parent
                    visible: NotificationService.hasNonTransientNotifications
                    contentWidth: width
                    contentHeight: notificationList.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: notificationList

                        width: notificationViewport.width

                        Repeater {
                            model: root.open ? NotificationController.notificationGroups.length : 0

                            delegate: SwipeToDismiss {
                                required property int index
                                readonly property var notificationGroupData: NotificationController.notificationGroups[index]

                                width: notificationList.width
                                implicitHeight: notificationGroupData.notifications.length > 1 ? groupedNotification.implicitHeight : singleNotification.implicitHeight
                                swipeEnabled: notificationGroupData.notifications.length === 1 || !NotificationController.isGroupExpanded(notificationGroupData)
                                showSeparator: index < NotificationController.notificationGroups.length - 1
                                onDismissed: {
                                    if (notificationGroupData.notifications.length > 1)
                                        NotificationService.dismissMany(notificationGroupData.notifications);
                                    else
                                        NotificationService.dismiss(notificationGroupData.notifications[0]);
                                }

                                NotificationGroup {
                                    id: groupedNotification

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                    }
                                    visible: notificationGroupData.notifications.length > 1
                                    group: notificationGroupData
                                    toggleContainerColor: Theme.scheme.surfaceVariant
                                    expanded: NotificationController.isGroupExpanded(group)
                                    showSeparator: index < NotificationController.notificationGroups.length - 1
                                    drawSeparator: false
                                    memberSwipeEnabled: expanded
                                    dismissMember: notification => NotificationService.dismiss(notification)
                                    onExpansionRequested: NotificationController.toggleGroupExpanded(group)
                                }

                                NotificationItem {
                                    id: singleNotification

                                    readonly property var singleNotificationData: notificationGroupData.notifications[0]

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                    }
                                    visible: notificationGroupData.notifications.length === 1
                                    notification: singleNotificationData
                                    toggleContainerColor: Theme.scheme.surfaceVariant
                                    expanded: NotificationController.isExpanded(notification)
                                    relativeTime: NotificationController.relativeTime(notification)
                                    showSeparator: index < NotificationController.notificationGroups.length - 1
                                    drawSeparator: false
                                    onExpansionRequested: NotificationController.toggleExpanded(notification)
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: M3ScrollBar {
                        policy: notificationList.implicitHeight > notificationViewport.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }
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
