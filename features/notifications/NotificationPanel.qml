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

TransientPanelWindow {
    id: root

    property real panelWidth: 420
    property real panelHeight: 0
    property real fallbackPanelHeight: 480
    property real minimumViewportHeight: 80
    property real maximumHeightRatio: 0.6
    property bool clearingAll: false
    property var clearAllTargetKeys: ({})
    property real footerReveal: NotificationService.hasNonTransientNotifications || root.clearingAll ? 1 : 0

    readonly property real maximumPanelHeight: root.screen ? Math.max(0, root.screen.height * root.maximumHeightRatio) : root.fallbackPanelHeight
    readonly property real footerHeight: clearAllButton.implicitHeight * root.footerReveal
    readonly property real footerSpacing: Metrics.spacingSm * root.footerReveal
    readonly property real maximumViewportHeight: Math.max(root.minimumViewportHeight, root.maximumPanelHeight - Metrics.spacingMd * 2 - root.footerHeight - root.footerSpacing)
    readonly property real emptyViewportHeight: Math.max(root.minimumViewportHeight, emptyState.implicitHeight + Metrics.spacingLg * 2)
    readonly property real contentViewportHeight: NotificationService.hasNonTransientNotifications ? Math.min(Math.max(root.minimumViewportHeight, notificationViewport.contentHeight), root.maximumViewportHeight) : root.emptyViewportHeight
    readonly property real naturalPanelHeight: root.contentViewportHeight + root.footerHeight + root.footerSpacing + Metrics.spacingMd * 2
    readonly property real targetPanelHeight: Math.min(root.panelHeight > 0 ? root.panelHeight : root.naturalPanelHeight, root.maximumPanelHeight)

    Behavior on footerReveal {
        NumberAnimation {
            duration: Motion.durationNotification
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    function updateClearingAllState() {
        if (!root.clearingAll)
            return;

        for (const notification of NotificationService.nonTransientNotifications) {
            const key = NotificationController.notificationKey(notification);
            if (key.length > 0 && root.clearAllTargetKeys[key])
                return;
        }

        root.clearingAll = false;
        root.clearAllTargetKeys = ({});
    }

    function clearAllNotifications() {
        if (root.clearingAll || !NotificationService.hasNonTransientNotifications)
            return;

        const targets = {};
        for (const notification of NotificationService.nonTransientNotifications) {
            const key = NotificationController.notificationKey(notification);
            if (key.length > 0)
                targets[key] = true;
        }
        root.clearAllTargetKeys = targets;
        root.clearingAll = true;

        const animatedGroups = {};
        for (let index = 0; index < notificationViewport.count; index++) {
            const item = notificationViewport.itemAtIndex(index);
            if (!item || !item.group || item.height <= 0)
                continue;
            animatedGroups[item.groupKey] = true;
            item.dismissAnimated(1);
        }

        // Delegates outside the viewport have no visual state to animate.
        for (const group of NotificationController.notificationGroups) {
            if (!animatedGroups[group.key])
                NotificationService.dismissMany(group.notifications);
        }
    }

    open: SurfaceController.notificationPanelOpen
    targetScreen: SurfaceController.notificationPanelScreen
    transitionsEnabled: true
    implicitWidth: root.panelWidth
    implicitHeight: root.maximumPanelHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
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
        // Card geometry already advances frame by frame. Following it directly
        // avoids a second animation that continually retargets and lags behind.
        height: root.targetPanelHeight
        radius: Metrics.radiusLg
        color: Theme.scheme.surfaceContainer

        ColumnLayout {
            anchors {
                fill: parent
                margins: Metrics.spacingMd
            }
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: root.contentViewportHeight
                Layout.bottomMargin: root.footerSpacing
                radius: Metrics.radiusMd
                color: Theme.scheme.surfaceContainerHighest
                clip: true

                ListView {
                    id: notificationViewport

                    anchors.fill: parent
                    model: NotificationController.notificationGroupModel
                    reuseItems: true
                    cacheBuffer: 128
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: NotificationCard {
                        id: notificationDelegate

                        required property int index
                        required property string key

                        group: NotificationController.notificationGroupsByKey[key]
                        width: ListView.view.width
                        expanded: grouped ? NotificationController.isGroupExpanded(group) : NotificationController.isExpanded(notification)
                        showSeparator: index < notificationViewport.count - 1
                        toggleContainerColor: Theme.scheme.surfaceVariant
                        memberSwipeEnabled: grouped && expanded
                        onDismissRequested: {
                            if (!group)
                                return;
                            NotificationService.dismissMany(group.notifications);
                        }
                        onExpansionRequested: {
                            if (grouped)
                                NotificationController.toggleGroupExpanded(group);
                            else
                                NotificationController.toggleExpanded(notification);
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: Motion.durationNotification
                            easing.type: Motion.easingEmphasized
                            easing.bezierCurve: Motion.emphasizedCurve
                        }
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
                visible: root.footerReveal > 0
                opacity: root.footerReveal
                implicitHeight: root.footerHeight
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight

                M3Button {
                    id: clearAllButton

                    anchors.right: parent.right
                    text: qsTr("Clear all")
                    style: M3Button.Text
                    implicitHeight: 34
                    enabled: !root.clearingAll
                    onClicked: root.clearAllNotifications()
                }
            }
        }
    }

    Connections {
        target: NotificationService

        function onHasNonTransientNotificationsChanged() {
            root.updateClearingAllState();
        }
    }

    Connections {
        target: NotificationService.notificationModel

        function onValuesChanged() {
            root.updateClearingAllState();
        }
    }

    SlideTransition {
        id: panelTransition

        target: panelSurface.presentationItem
        hiddenOffsetY: -(panelSurface.height + panelSurface.anchors.topMargin + 5)
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
