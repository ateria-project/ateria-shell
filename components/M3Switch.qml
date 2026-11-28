pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import qs.theme

T.Switch {
    id: root

    implicitWidth: implicitIndicatorWidth
    implicitHeight: implicitIndicatorHeight
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    indicator: Rectangle {
        id: track

        implicitWidth: implicitHeight * 1.7
        implicitHeight: 30
        radius: height / 2
        color: {
            if (!root.enabled) {
                return root.checked
                    ? Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainerOpacity)
                    : Theme.stateLayer(Theme.scheme.surfaceContainerHighest, Theme.disabledContentOpacity);
            }

            return root.checked ? Theme.scheme.primary : Theme.scheme.surfaceContainerHighest;
        }

        Rectangle {
            id: thumb

            readonly property real restingSize: track.height - Metrics.spacingXs
            readonly property real targetWidth: root.pressed ? restingSize * 1.2 : restingSize

            anchors.verticalCenter: parent.verticalCenter
            x: root.checked
                ? track.width - thumb.targetWidth - Metrics.spacingXs / 2
                : Metrics.spacingXs / 2
            width: thumb.targetWidth
            height: thumb.restingSize
            radius: height / 2
            color: {
                if (!root.enabled) {
                    return root.checked
                        ? Theme.scheme.surface
                        : Theme.stateLayer(Theme.scheme.onSurface, Theme.disabledContainerOpacity);
                }

                return root.checked ? Theme.scheme.onPrimary : Theme.scheme.outline;
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.checked ? Theme.scheme.primary : Theme.scheme.onSurface
                opacity: {
                    if (!root.enabled)
                        return 0;
                    if (root.pressed)
                        return Theme.statePressedOpacity;
                    if (root.hovered)
                        return Theme.stateHoverOpacity;
                    if (root.visualFocus)
                        return Theme.stateFocusOpacity;
                    return 0;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.durationExpressiveDefaultEffects
                        easing.type: Motion.easingExpressiveDefaultEffects
                        easing.bezierCurve: Motion.expressiveDefaultEffectsCurve
                    }
                }
            }

            Shape {
                id: stateIcon

                property point start1: {
                    if (root.pressed)
                        return Qt.point(width * 0.2, height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.15, height / 2);
                    return Qt.point(width * 0.15, height * 0.15);
                }
                property point end1: {
                    if (root.pressed)
                        return Qt.point(width * (root.checked ? 0.4 : 0.8), height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.4, height * 0.7);
                    return Qt.point(width * 0.85, height * 0.85);
                }
                property point start2: {
                    if (root.pressed)
                        return Qt.point(width * (root.checked ? 0.4 : 0.2), height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.4, height * 0.7);
                    return Qt.point(width * 0.15, height * 0.85);
                }
                property point end2: {
                    if (root.pressed)
                        return Qt.point(width * 0.8, height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.85, height * 0.2);
                    return Qt.point(width * 0.85, height * 0.15);
                }

                anchors.centerIn: parent
                width: height
                height: thumb.height - Metrics.spacingMd
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2.4
                    strokeColor: {
                        if (!root.enabled)
                            return root.checked ? Theme.scheme.outline : Theme.scheme.surfaceContainer;
                        return root.checked ? Theme.scheme.primary : Theme.scheme.surfaceContainerHighest;
                    }
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: stateIcon.start1.x
                    startY: stateIcon.start1.y

                    PathLine {
                        x: stateIcon.end1.x
                        y: stateIcon.end1.y
                    }

                    PathMove {
                        x: stateIcon.start2.x
                        y: stateIcon.start2.y
                    }

                    PathLine {
                        x: stateIcon.end2.x
                        y: stateIcon.end2.y
                    }

                    Behavior on strokeColor {
                        ColorAnimation {
                            duration: Motion.durationShort
                            easing.type: Motion.easingExpressiveSlowEffects
                            easing.bezierCurve: Motion.expressiveSlowEffectsCurve
                        }
                    }
                }

                Behavior on start1 { M3SwitchGeometryAnimation {} }
                Behavior on end1 { M3SwitchGeometryAnimation {} }
                Behavior on start2 { M3SwitchGeometryAnimation {} }
                Behavior on end2 { M3SwitchGeometryAnimation {} }
            }

            Behavior on x {
                SpringAnimation {
                    spring: 6.0
                    damping: 0.35
                    mass: 1.0
                    epsilon: 0.25
                }
            }

            Behavior on width {
                SpringAnimation {
                    spring: 6.0
                    damping: 0.35
                    mass: 1.0
                    epsilon: 0.25
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationShort
                    easing.type: Motion.easingExpressiveSlowEffects
                    easing.bezierCurve: Motion.expressiveSlowEffectsCurve
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationShort
                easing.type: Motion.easingExpressiveSlowEffects
                easing.bezierCurve: Motion.expressiveSlowEffectsCurve
            }
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    component M3SwitchGeometryAnimation: PropertyAnimation {
        duration: 260
        easing.type: Motion.easingExpressiveFastSpatial
        easing.bezierCurve: Motion.expressiveFastSpatialCurve
    }
}
