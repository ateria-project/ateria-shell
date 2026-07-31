import QtQuick
import QtQuick.Controls
import qs.components
import qs.platform.audio
import qs.platform.network
import qs.platform.power
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
        SurfaceController.openQuickSettings(root.screen);
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
            name: NetworkService.wiredConnected ? "settings_ethernet" : NetworkService.wifiIconName
            size: NetworkService.wiredConnected ? 20 : 18
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: root.iconColor
        }

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: AudioService.outputIconName
            size: 20
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: root.iconColor
        }

        M3Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasBattery && PowerService.hasBattery
            name: PowerService.batteryIconName
            size: 20
            opticalSize: 20
            weight: 500
            grade: 0
            filled: false
            color: PowerService.critical ? Theme.scheme.error : root.iconColor
        }

        M3Icon {
            id: recordIcon

            anchors.verticalCenter: parent.verticalCenter
            visible: root.recording
            name: "screen_record"
            size: 18
            opticalSize: 20
            weight: 500
            grade: 0
            filled: true
            color: Theme.scheme.error

            SequentialAnimation on opacity {
                running: root.recording && recordIcon.visible
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1.0
                    to: 0.4
                    duration: 1000
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 0.4
                    to: 1.0
                    duration: 1000
                    easing.type: Easing.InOutSine
                }
            }
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
