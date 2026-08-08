import QtQuick
import qs.theme

NumberAnimation {
    duration: Motion.durationPageTransition
    easing.type: Motion.easingExpressiveSpatial
    easing.bezierCurve: Motion.expressiveGentleSpatialCurve
}
