pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import qs.theme

AbstractButton {
    id: root

    enum Style {
        Filled,
        Tonal,
        Outlined,
        Text
    }

    property int style: M3Button.Filled

    property string iconName: ""

    property int iconSize: 24
    property bool iconFilled: false
    property real iconWeight: 500
    property real iconGrade: 0
    property real iconOpticalSize: Math.max(20, root.iconSize)

    property color containerColor: {
        switch (root.style) {
        case M3Button.Tonal:
            return Theme.scheme.secondaryContainer;
        case M3Button.Outlined:
        case M3Button.Text:
            return "transparent";
        default:
            return Theme.scheme.primary;
        }
    }

    property color contentColor: {
        switch (root.style) {
        case M3Button.Tonal:
            return Theme.scheme.onSecondaryContainer;
        case M3Button.Outlined:
        case M3Button.Text:
            return Theme.scheme.primary;
        default:
            return Theme.scheme.onPrimary;
        }
    }

    property color outlineColor: Theme.scheme.outline
    property real disabledOpacity: 0.38

    readonly property bool hasText: root.text.length > 0
    readonly property bool hasIcon: root.iconName.length > 0
    readonly property bool iconOnly: root.hasIcon && !root.hasText
    readonly property bool textOnly: root.hasText && !root.hasIcon

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    leftPadding: root.iconOnly ? 6 : 12
    rightPadding: root.iconOnly ? 6 : 12
    topPadding: 4
    bottomPadding: 4

    spacing: 8

    scale: root.down ? 0.96 : 1
    opacity: root.enabled ? 1 : root.disabledOpacity

    Accessible.name: root.hasText ? root.text : root.iconName

    background: Rectangle {
        radius: height / 2
        color: root.containerColor

        border.width: root.style === M3Button.Outlined ? 1 : 0

        border.color: root.outlineColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius

            color: root.contentColor

            opacity: {
                if (root.down)
                    return 0.12;

                if (root.hovered)
                    return 0.08;

                if (root.visualFocus)
                    return 0.10;

                return 0;
            }

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
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.durationMedium
            }
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        Row {
            id: row
            anchors.centerIn: parent
            spacing: root.spacing

            M3Icon {
                anchors.verticalCenter: parent.verticalCenter

                visible: root.hasIcon

                name: root.iconName
                size: root.iconSize
                filled: root.iconFilled
                weight: root.iconWeight
                grade: root.iconGrade
                opticalSize: root.iconOpticalSize
                color: root.contentColor
            }

            M3Text {
                anchors.verticalCenter: parent.verticalCenter

                visible: root.hasText

                text: root.text
                color: root.contentColor

                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.fastSpatialSpring
            damping: Motion.fastSpatialDamping
            mass: Motion.fastSpatialMass
            epsilon: Motion.fastSpatialEpsilon
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.durationShort
        }
    }
}
