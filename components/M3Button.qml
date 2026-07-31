import QtQuick
import QtQuick.Controls
import qs.theme

AbstractButton {
    id: root

    property color backgroundColor: Theme.scheme.surfaceContainer
    property color contentColor: Theme.scheme.onSurface

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitHeight: 36
    implicitWidth: Math.max(80, contentItem ? contentItem.implicitWidth + 24 : 80)
    scale: root.down ? 0.96 : 1

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Metrics.radiusFull
        color: root.backgroundColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.contentColor
            opacity: root.down ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : root.visualFocus ? Theme.stateFocusOpacity : 0

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

    Behavior on scale {
        SpringAnimation {
            spring: Motion.fastSpatialSpring
            damping: Motion.fastSpatialDamping
            mass: Motion.fastSpatialMass
            epsilon: Motion.fastSpatialEpsilon
        }
    }
}
