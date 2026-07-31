pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.components
import qs.theme

AbstractButton {
    id: root

    required property bool active
    required property string iconName
    required property string title
    required property string subtitle

    property bool showDetails: false

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    padding: 0
    implicitHeight: 62
    implicitWidth: 200
    scale: down ? 0.98 : 1.0

    background: Rectangle {
        radius: 16
        color: root.active ? Theme.scheme.primaryContainer : Theme.scheme.surfaceContainerHighest

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
            opacity: root.down ? 0.12 : root.hovered ? 0.08 : root.visualFocus ? 0.1 : 0

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

    contentItem: Item {
        M3Icon {
            id: titleIcon

            anchors {
                left: parent.left
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }

            name: root.iconName
            size: 24
            color: root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
        }

        Column {
            anchors {
                left: titleIcon.right
                leftMargin: 14
                right: root.showDetails ? detailsIcon.left : parent.right
                rightMargin: root.showDetails ? Metrics.spacingXs : 14
                verticalCenter: parent.verticalCenter
            }

            spacing: 1

            M3Text {
                width: parent.width
                text: root.title
                color: root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            M3Text {
                width: parent.width
                text: root.subtitle
                color: root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurfaceVariant
                opacity: root.active ? 0.82 : 1
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        M3Icon {
            id: detailsIcon

            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }

            visible: root.showDetails
            name: "chevron_right"
            size: 20
            weight: 500
            color: root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurfaceVariant
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

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
