pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.theme

AbstractButton {
    id: root

    required property var category
    property bool selected: false

    signal activated()

    implicitHeight: 56
    leftPadding: Metrics.spacingMd
    rightPadding: Metrics.spacingMd
    topPadding: Metrics.spacingSm
    bottomPadding: Metrics.spacingSm
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.category.title
    onClicked: root.activated()

    background: Rectangle {
        radius: Metrics.radiusMd
        color: root.selected ? Theme.scheme.secondaryContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.scheme.onSurface
            opacity: root.down ? 0.12 : root.hovered && !root.selected ? 0.08 : root.visualFocus ? 0.12 : 0

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
    }

    contentItem: RowLayout {
        spacing: Metrics.spacingMd

        M3Icon {
            Layout.alignment: Qt.AlignVCenter
            name: root.category.icon
            size: 22
            color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationMedium
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            M3Text {
                Layout.fillWidth: true
                text: root.category.title
                font.pixelSize: 14
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.durationMedium
                    }
                }
            }

            M3Text {
                Layout.fillWidth: true
                text: root.category.description
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
                opacity: root.selected ? 0.8 : 0.7

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.durationMedium
                    }
                }
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
