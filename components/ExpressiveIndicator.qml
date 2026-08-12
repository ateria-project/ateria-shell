pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// A layout-independent selection trail. Its leading edge reaches the target
// before its trailing edge, stretching the indicator briefly before it settles.
Item {
    id: root

    required property real targetPosition
    required property real targetExtent
    required property real crossPosition
    required property real crossExtent
    property int orientation: Qt.Horizontal
    property bool motionEnabled: true
    property real leadingStart: root.targetPosition
    property real trailingStart: root.targetPosition
    property real leadingEnd: root.targetPosition + root.targetExtent
    property real trailingEnd: root.targetPosition + root.targetExtent

    readonly property real animatedPosition: Math.min(root.leadingStart, root.trailingStart)
    readonly property real animatedExtent: Math.max(root.leadingEnd, root.trailingEnd) - root.animatedPosition

    x: root.orientation === Qt.Horizontal ? root.animatedPosition : root.crossPosition
    y: root.orientation === Qt.Vertical ? root.animatedPosition : root.crossPosition
    width: root.orientation === Qt.Horizontal ? root.animatedExtent : root.crossExtent
    height: root.orientation === Qt.Vertical ? root.animatedExtent : root.crossExtent

    Behavior on leadingStart {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 120
            easing.type: Motion.easingEmphasizedDecelerate
            easing.bezierCurve: Motion.emphasizedDecelerateCurve
        }
    }

    Behavior on leadingEnd {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 120
            easing.type: Motion.easingEmphasizedDecelerate
            easing.bezierCurve: Motion.emphasizedDecelerateCurve
        }
    }

    Behavior on trailingStart {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 280
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    Behavior on trailingEnd {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: 280
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }
}
