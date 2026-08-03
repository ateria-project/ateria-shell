pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.features.notifications
import qs.theme

Control {
    id: root

    clip: true

    required property var group
    property bool expanded: false
    property bool showSeparator: true
    property bool drawSeparator: true
    property int previewLimit: 4
    property var isMemberExpanded: notification => NotificationController.isExpanded(notification)
    property var toggleMemberExpanded: notification => NotificationController.toggleExpanded(notification)
    property bool memberSwipeEnabled: false
    property var dismissMember: notification => {}
    property color toggleContainerColor: Theme.scheme.surfaceContainerHighest
    property bool animatingGroupExpansion: false

    readonly property var latestNotification: root.group ? root.group.latestNotification : null
    readonly property int notificationCount: root.group && root.group.notifications ? root.group.notifications.length : 0
    readonly property string appIconSource: root.group ? String(root.group.appIconSource || "") : ""

    signal expansionRequested

    onExpandedChanged: {
        root.animatingGroupExpansion = true;
    }

    Behavior on implicitHeight {
        enabled: root.animatingGroupExpansion

        NumberAnimation {
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
            onRunningChanged: {
                if (!running)
                    root.animatingGroupExpansion = false;
            }
        }
    }

    leftPadding: Metrics.spacingLg
    rightPadding: Metrics.spacingLg
    topPadding: Metrics.spacingLg
    bottomPadding: root.expanded ? Metrics.spacingSm : Metrics.spacingLg

    contentItem: Item {
        implicitWidth: groupContent.implicitWidth
        implicitHeight: groupContent.implicitHeight

        ColumnLayout {
            id: groupContent

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Metrics.spacingMd

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Metrics.spacingLg
                rowSpacing: Metrics.spacingSm

                Item {
                    Layout.row: 0
                    Layout.column: 0
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Metrics.radiusFull
                        color: Theme.scheme.primaryContainer
                        visible: !groupIcon.visible

                        M3Icon {
                            anchors.centerIn: parent
                            name: "notifications"
                            size: 19
                            color: Theme.scheme.onPrimaryContainer
                        }
                    }

                    Image {
                        id: groupIcon

                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: root.appIconSource
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: source.toString().length > 0 && status !== Image.Error
                    }
                }

                M3Text {
                    Layout.row: 0
                    Layout.column: 1
                    Layout.fillWidth: true
                    text: qsTr("%1  •  %2").arg(root.group ? root.group.sourceName : qsTr("Notification")).arg(NotificationController.relativeTime(root.latestNotification))
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 14
                }

                AbstractButton {
                    id: groupToggle

                    Layout.row: 0
                    Layout.column: 2
                    Layout.alignment: Qt.AlignVCenter
                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true
                    leftPadding: Metrics.spacingSm
                    rightPadding: Metrics.spacingSm
                    topPadding: Metrics.spacingXs
                    bottomPadding: Metrics.spacingXs
                    spacing: Metrics.spacingXs
                    scale: down ? 0.96 : 1
                    Accessible.name: root.expanded ? qsTr("Collapse %1 notifications").arg(root.notificationCount) : qsTr("Expand %1 notifications").arg(root.notificationCount)
                    onClicked: root.expansionRequested()

                    contentItem: Item {
                        implicitWidth: toggleContent.implicitWidth
                        implicitHeight: toggleContent.implicitHeight

                        Row {
                            id: toggleContent

                            anchors.centerIn: parent
                            spacing: groupToggle.spacing

                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !root.expanded
                                text: String(root.notificationCount)
                                color: Theme.scheme.onSurfaceVariant
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.expanded ? "expand_less" : "expand_more"
                                size: 18
                                color: Theme.scheme.onSurfaceVariant
                            }
                        }
                    }

                    background: Rectangle {
                        radius: Metrics.radiusFull
                        color: root.toggleContainerColor

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.scheme.onSurfaceVariant
                            opacity: groupToggle.down ? 0.12 : groupToggle.hovered ? 0.08 : groupToggle.visualFocus ? 0.12 : 0
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    Behavior on scale {
                        SpringAnimation {
                            spring: Motion.fastSpatialSpring
                            damping: Motion.fastSpatialDamping
                            mass: Motion.fastSpatialMass
                            epsilon: Motion.fastSpatialEpsilon
                        }
                    }
                }

                ColumnLayout {
                    visible: !root.expanded
                    Layout.row: 1
                    Layout.column: 1
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSm

                    Repeater {
                        model: root.visible && !root.expanded ? Math.min(root.notificationCount, root.previewLimit) : 0

                        delegate: M3Text {
                            required property int index
                            readonly property var previewNotification: root.group.notifications[index]

                            Layout.fillWidth: true
                            text: NotificationController.previewText(previewNotification)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.scheme.onSurfaceVariant
                            font.pixelSize: 14
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.expanded
                Layout.fillWidth: true
                spacing: Metrics.spacingSm

                Repeater {
                    model: root.visible && root.expanded ? root.notificationCount : 0

                    delegate: SwipeToDismiss {
                        required property int index
                        readonly property var memberNotification: root.group.notifications[index]

                        Layout.fillWidth: true
                        implicitHeight: memberItem.implicitHeight
                        swipeEnabled: root.memberSwipeEnabled
                        showSeparator: index < root.notificationCount - 1
                        onDismissed: {
                            if (root && typeof root.dismissMember === "function" && memberNotification)
                                root.dismissMember(memberNotification);
                        }

                        NotificationItem {
                            id: memberItem

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            notification: memberNotification
                            grouped: true
                            toggleContainerColor: root.toggleContainerColor
                            expanded: Boolean(root && typeof root.isMemberExpanded === "function" && notification && root.isMemberExpanded(notification))
                            relativeTime: NotificationController.relativeTime(notification)
                            showSeparator: index < root.notificationCount - 1
                            drawSeparator: false
                            onExpansionRequested: {
                                if (root && typeof root.toggleMemberExpanded === "function")
                                    root.toggleMemberExpanded(notification);
                            }
                        }
                    }
                }
            }
        }
    }

    background: Item {
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.scheme.outlineVariant
            opacity: 0.6
            visible: root.showSeparator && root.drawSeparator
        }
    }
}
