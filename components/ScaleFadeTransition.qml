pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Drives a centered surface without changing its layout geometry. Spatial and
// effects motion run independently: the surface settles with an expressive
// lift while opacity remains quick and smooth. Interrupted transitions resume
// from their current visual state.
QtObject {
    id: root

    required property PresentationLayer target
    property real hiddenScale: 0.9
    property real hiddenOffsetY: 32
    property int enterSpatialDuration: Motion.durationSpatialDefault
    property int exitSpatialDuration: Motion.durationMedium
    property int enterEffectsDuration: Motion.durationExpressiveDefaultEffects
    property int exitEffectsDuration: 160

    readonly property real progress: root._effectsProgress
    readonly property real spatialProgress: root._spatialProgress

    property real _spatialProgress: 0
    property real _effectsProgress: 0
    property bool _entering: false
    property bool _completionPending: false
    property bool _spatialSettled: true
    property bool _effectsSettled: true
    property int _generation: -1

    signal transitionFinished(int generation)

    function transition(entering: bool, generation: int) {
        spatialAnimation.stop();
        effectsAnimation.stop();

        root._entering = entering;
        root._completionPending = true;
        root._spatialSettled = false;
        root._effectsSettled = false;
        root._generation = generation;

        const targetProgress = entering ? 1 : 0;
        const spatialDistance = Math.abs(targetProgress - root._spatialProgress);
        const effectsDistance = Math.abs(targetProgress - root._effectsProgress);
        const spatialDuration = entering ? root.enterSpatialDuration : root.exitSpatialDuration;
        const effectsDuration = entering ? root.enterEffectsDuration : root.exitEffectsDuration;

        spatialAnimation.to = targetProgress;
        spatialAnimation.duration = Math.max(1, Math.round(spatialDuration * spatialDistance));
        effectsAnimation.to = targetProgress;
        effectsAnimation.duration = Math.max(1, Math.round(effectsDuration * effectsDistance));

        spatialAnimation.start();
        effectsAnimation.start();
    }

    function finishIfSettled() {
        if (root._completionPending && root._spatialSettled && root._effectsSettled) {
            root._completionPending = false;
            root.transitionFinished(root._generation);
        }
    }

    property Binding scaleBinding: Binding {
        target: root.target
        property: "visualScale"
        value: root.hiddenScale + (1 - root.hiddenScale) * root._spatialProgress
    }

    property Binding verticalOffsetBinding: Binding {
        target: root.target
        property: "offsetY"
        value: root.hiddenOffsetY * (1 - root._spatialProgress)
    }

    property Binding opacityBinding: Binding {
        target: root.target
        property: "visualOpacity"
        value: Math.max(0, Math.min(1, root._effectsProgress))
    }

    property NumberAnimation spatialAnimation: NumberAnimation {
        target: root
        property: "_spatialProgress"
        easing.type: root._entering ? Motion.easingExpressiveSpatial : Motion.easingEmphasizedAccelerate
        easing.bezierCurve: root._entering ? Motion.expressiveGentleSpatialCurve : Motion.emphasizedAccelerateCurve
        onFinished: {
            root._spatialSettled = true;
            root.finishIfSettled();
        }
    }

    property NumberAnimation effectsAnimation: NumberAnimation {
        target: root
        property: "_effectsProgress"
        easing.type: root._entering ? Motion.easingExpressiveDefaultEffects : Motion.easingEmphasizedAccelerate
        easing.bezierCurve: root._entering ? Motion.expressiveDefaultEffectsCurve : Motion.emphasizedAccelerateCurve
        onFinished: {
            root._effectsSettled = true;
            root.finishIfSettled();
        }
    }
}
