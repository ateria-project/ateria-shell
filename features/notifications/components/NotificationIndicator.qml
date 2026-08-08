import QtQuick
import QtQuick.Controls.Basic
import qs.components
import qs.platform.notifications
import qs.shell
import qs.theme

AbstractButton {
    id: root

    property var screen: null
    readonly property int notificationCount: NotificationService.nonTransientCount
    readonly property string displayedCount: root.notificationCount > 99 ? "99+" : String(root.notificationCount)
    readonly property bool active: SurfaceController.notificationPanelOpen && SurfaceController.notificationPanelScreen === root.screen
    readonly property color contentColor: root.active ? Theme.scheme.onPrimary : Theme.scheme.onSurface

    implicitWidth: 44
    implicitHeight: 28
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    horizontalPadding: 10
    scale: root.down ? 0.96 : 1
    Accessible.name: root.notificationCount > 0 ? qsTr("%1 notifications").arg(root.notificationCount) : qsTr("No notifications")
    onClicked: SurfaceController.toggleNotificationPanel(root.screen)

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Metrics.radiusFull
        color: root.active ? Theme.scheme.primary : Theme.scheme.surfaceContainer

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.contentColor
            opacity: root.down ? 0.12 : root.hovered ? 0.08 : root.visualFocus ? 0.12 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.durationShort
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }
    }

    contentItem: Item {
        M3Icon {
            anchors.centerIn: parent
            visible: root.notificationCount === 0
            name: "notifications_none"
            size: 20
            filled: false
            color: root.contentColor
        }

        M3Text {
            anchors.centerIn: parent
            visible: root.notificationCount > 0
            text: root.displayedCount
            color: root.contentColor
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
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
