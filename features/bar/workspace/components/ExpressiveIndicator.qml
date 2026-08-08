pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// A layout-independent selection trail. Two copies of each bound move at
// different speeds; their union becomes a pill that stretches toward the new
// target and then settles without replacing the animated object.
Item {
    id: root

    required property real targetX
    required property real targetWidth
    property bool motionEnabled: true
    property real leadingLeft: root.targetX
    property real trailingLeft: root.targetX
    property real leadingRight: root.targetX + root.targetWidth
    property real trailingRight: root.targetX + root.targetWidth

    x: Math.min(root.leadingLeft, root.trailingLeft)
    width: Math.max(root.leadingRight, root.trailingRight) - root.x

    Behavior on leadingLeft {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 120
            easing.type: Motion.easingEmphasizedDecelerate
            easing.bezierCurve: Motion.emphasizedDecelerateCurve
        }
    }

    Behavior on leadingRight {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 120
            easing.type: Motion.easingEmphasizedDecelerate
            easing.bezierCurve: Motion.emphasizedDecelerateCurve
        }
    }

    Behavior on trailingLeft {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 280
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    Behavior on trailingRight {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 280
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }
}
