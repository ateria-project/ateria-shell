import QtQuick
import QtQuick.Controls
import qs.theme

Slider {
    id: root

    implicitWidth: 160
    implicitHeight: 24

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.availableWidth
        height: 6
        radius: Metrics.radiusFull
        color: Theme.scheme.surfaceVariant

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            color: Theme.scheme.primary
            radius: Metrics.radiusFull
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        width: 18
        height: 18
        radius: Metrics.radiusFull
        color: Theme.scheme.primary

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.scheme.onPrimary
            opacity: root.pressed ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : 0
        }
    }
}
