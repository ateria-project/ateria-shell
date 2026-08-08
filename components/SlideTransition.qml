pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Drives a PresentationLayer without changing the geometry owned by layouts.
// The travel vector is captured at a stable endpoint so dynamic content cannot
// retarget motion that is already running.
QtObject {
    id: root

    required property PresentationLayer target
    property real hiddenOffsetX: 0
    property real hiddenOffsetY: 0
    property int duration: Motion.durationSpatialDefault
    property int easingType: Motion.easingExpressiveSpatial
    property var easingCurve: Motion.expressiveDefaultSpatialCurve

    property real _progress: 0
    property real _travelX: 0
    property real _travelY: 0
    property int _generation: -1

    signal transitionFinished(int generation)

    function transition(entering: bool, generation: int) {
        const interrupted = slideAnimation.running;
        slideAnimation.stop();

        // A reversal keeps the current travel vector. A new transition from
        // either endpoint picks up the latest panel dimensions.
        if (!interrupted) {
            root._travelX = root.hiddenOffsetX;
            root._travelY = root.hiddenOffsetY;
        }

        root._generation = generation;

        const targetProgress = entering ? 1 : 0;
        const remainingDistance = Math.abs(targetProgress - root._progress);
        slideAnimation.to = targetProgress;
        slideAnimation.duration = Math.max(1, Math.round(root.duration * remainingDistance));
        slideAnimation.start();
    }

    property Binding horizontalOffsetBinding: Binding {
        target: root.target
        property: "offsetX"
        value: root._travelX * (1 - root._progress)
    }

    property Binding verticalOffsetBinding: Binding {
        target: root.target
        property: "offsetY"
        value: root._travelY * (1 - root._progress)
    }

    property NumberAnimation slideAnimation: NumberAnimation {
        target: root
        property: "_progress"
        easing.type: root.easingType
        easing.bezierCurve: root.easingCurve
        onFinished: root.transitionFinished(root._generation)
    }
}
