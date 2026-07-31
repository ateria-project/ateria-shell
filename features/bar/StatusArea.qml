import QtQuick
import QtQuick.Controls
import qs.components
import qs.shell
import qs.theme

AbstractButton {
    id: root

    property var screen: null
    property bool hasBattery: false
    property bool recording: false
    readonly property color iconColor: Theme.scheme.onSurface

    onClicked: SurfaceController.toggleQuickSettings(root.screen)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    horizontalPadding: 10
    implicitHeight: 28
    scale: root.down ? 0.96 : 1

    Component.onCompleted: {
        SurfaceController.openQuickSettings(root.screen)
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Metrics.radiusFull
        color: Theme.scheme.surfaceContainer

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.iconColor
            opacity: root.down ? 0.12 : root.hovered ? 0.08 : root.visualFocus ? 0.12 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.durationShort
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }
    }

    contentItem: Row {
        spacing: Metrics.spacingSm

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "network_wifi"
            size: 18
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: root.iconColor
        }

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "volume_up"
            size: 18
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: root.iconColor
        }

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasBattery
            name: "battery_android_full"
            size: 20
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: root.iconColor
        }

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.recording
            name: "screen_record"
            size: 18
            opticalSize: 20
            weight: 500
            grade: 0
            filled: true
            color: Theme.scheme.error
        }
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.fastSpatialSpring
            damping: Motion.fastSpatialDamping
            mass: Motion.fastSpatialMass
            epsilon: Motion.fastSpatialEpsilon
        }
    }
}
