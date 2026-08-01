import QtQuick
import qs.theme

Rectangle {
    id: root

    radius: 16
    color: Theme.scheme.surfaceContainer
    antialiasing: true

    Rectangle {
        id: outerKeyline

        anchors.fill: parent
        z: 1000

        color: "transparent"
        radius: root.radius
        antialiasing: true

        property color strokeColor: Theme.panelOuterKeyline

        border.width: Theme.panelBorderWidth
        border.color: strokeColor

        Behavior on strokeColor {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: innerHighlight

        anchors.fill: parent
        anchors.margins: Theme.panelInnerBorderInset
        z: 1001

        color: "transparent"
        radius: Math.max(0, root.radius - Theme.panelInnerBorderInset)
        antialiasing: true

        property color strokeColor: Theme.panelInnerHighlight

        border.width: Theme.panelBorderWidth
        border.color: strokeColor

        Behavior on strokeColor {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
