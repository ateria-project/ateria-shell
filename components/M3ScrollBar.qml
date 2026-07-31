import QtQuick
import QtQuick.Controls
import qs.theme

ScrollBar {
    id: root

    padding: 0

    background: Rectangle {
        color: Theme.scheme.outlineVariant
    }

    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: width / 2
        color: Theme.scheme.outline
        opacity: root.active || root.pressed ? 0.72 : 0.38

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.durationShort
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }
    }
}
