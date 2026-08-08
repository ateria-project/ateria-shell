import QtQuick
import QtQuick.Controls
import qs.theme

ScrollBar {
    id: root

    padding: 0

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: width / 2
        color: Theme.scheme.onSurfaceVariant
        opacity: root.pressed ? 0.87 : root.hovered ? 0.72 : root.active ? 0.5 : 0.38

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.durationShort
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }
    }
}
