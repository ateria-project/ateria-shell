pragma ComponentBehavior: Bound

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
    readonly property real targetPanelWidth: root.panelWidth
    readonly property real targetPanelHeight: Math.min(root.panelHeight > 0 ? root.panelHeight : root.naturalPanelHeight, root.maximumPanelHeight)

    screen: SurfaceController.activeScreen
    visible: root.open
    implicitWidth: root.panelWidth
    // Keep the input surface full-screen while open so clicks outside the
    // panel can dismiss it.
    // Keep the native layer surface stable while the masked panel animates.
    implicitHeight: root.maximumPanelHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    MouseArea {
        anchors {
            top: parent.top
            right: parent.right
            bottom: panelSurface.top
            left: parent.left
        }
        onClicked: SurfaceController.closeNotificationPanel()
    }

    MouseArea {
        anchors {
            top: panelSurface.bottom
            right: parent.right
            bottom: parent.bottom
            left: parent.left
        }
        onClicked: SurfaceController.closeNotificationPanel()
    }

    MouseArea {
        anchors {
            top: panelSurface.top
            right: panelSurface.left
            bottom: panelSurface.bottom
            left: parent.left
        }
        onClicked: SurfaceController.closeNotificationPanel()
    }

    MouseArea {
        anchors {
            top: panelSurface.top
            right: parent.right
            bottom: panelSurface.bottom
            left: panelSurface.right
        }
        onClicked: SurfaceController.closeNotificationPanel()
    }

    M3Panel {
        id: panelSurface

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 6
            rightMargin: 6
        }
        width: root.targetPanelWidth
        // Notification cards own the resize animation; follow their height directly.
        height: root.targetPanelHeight
        radius: Metrics.radiusLg
        color: Theme.scheme.surfaceContainer
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingEmphasized
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

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
                                id: notificationDelegate

                                required property int index
                                readonly property var notificationGroupData: NotificationController.notificationGroups[index]
                                readonly property bool grouped: notificationDelegate.notificationGroupData.notifications.length > 1
                                readonly property Item loadedNotification: notificationLoader.item

                                width: notificationList.width
                                implicitHeight: notificationDelegate.loadedNotification ? notificationDelegate.loadedNotification.implicitHeight : 0
                                swipeEnabled: !notificationDelegate.grouped || !NotificationController.isGroupExpanded(notificationDelegate.notificationGroupData)
                                showSeparator: notificationDelegate.index < NotificationController.notificationGroups.length - 1
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
                                    sourceComponent: notificationDelegate.grouped ? groupedNotificationComponent : singleNotificationComponent
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
