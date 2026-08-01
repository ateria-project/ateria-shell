import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import qs.components
import qs.shell
import qs.theme

AbstractButton {
    id: root

    property var screen: null

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    onClicked: SurfaceController.toggleCalendar(root.screen)
    scale: root.down ? 0.96 : 1

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Metrics.radiusFull
        color: (root.hovered || root.down || root.visualFocus || SurfaceController.calendarOpen) ? Theme.scheme.surfaceContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.scheme.onSurface
            opacity: (root.down || SurfaceController.calendarOpen) ? 0.12 : root.hovered ? 0.08 : root.visualFocus ? 0.12 : 0

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
        M3Text {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM   •   h:mm AP")
            color: Theme.scheme.onSurface
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
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
