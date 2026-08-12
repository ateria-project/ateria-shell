pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property real fastSpatialSpring: 4.0
    readonly property real fastSpatialDamping: 0.2
    readonly property real fastSpatialMass: 1.0
    readonly property real fastSpatialEpsilon: 0.01

    readonly property int durationShort: 100
    readonly property int durationMedium: 200
    readonly property int durationNotification: 240
    readonly property int durationLong: 300
    readonly property int durationSpatialDefault: 380
    readonly property int durationPageTransition: 320
    readonly property int durationExpressiveFastSpatial: 350
    readonly property int durationExpressiveDefaultEffects: 200
    readonly property int durationExpressiveSlowEffects: 300

    readonly property int easingStandard: Easing.BezierSpline
    readonly property list<real> standardCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property int easingStandardDecelerate: Easing.BezierSpline
    readonly property var standardDecelerateCurve: [0, 0, 0, 1, 1, 1]
    readonly property int easingStandardAccelerate: Easing.BezierSpline
    readonly property list<real> standardAccelerateCurve: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]

    readonly property int easingEmphasized: Easing.BezierSpline
    readonly property list<real> emphasizedCurve: [0.05, 0.0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
    readonly property int easingEmphasizedDecelerate: Easing.BezierSpline
    readonly property list<real> emphasizedDecelerateCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property int easingEmphasizedAccelerate: Easing.BezierSpline
    readonly property list<real> emphasizedAccelerateCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property int easingExpressiveSpatial: Easing.BezierSpline
    readonly property list<real> expressiveDefaultSpatialCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
    readonly property list<real> expressiveGentleSpatialCurve: [0.38, 1.14, 0.22, 1.0, 1.0, 1.0]
    readonly property int easingExpressiveFastSpatial: Easing.BezierSpline
    readonly property list<real> expressiveFastSpatialCurve: [0.42, 1.67, 0.21, 0.9, 1.0, 1.0]
    readonly property int easingExpressiveDefaultEffects: Easing.BezierSpline
    readonly property list<real> expressiveDefaultEffectsCurve: [0.34, 0.8, 0.34, 1.0, 1.0, 1.0]
    readonly property int easingExpressiveSlowEffects: Easing.BezierSpline
    readonly property list<real> expressiveSlowEffectsCurve: [0.34, 0.88, 0.34, 1.0, 1.0, 1.0]
}
