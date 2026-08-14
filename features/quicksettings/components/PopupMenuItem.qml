pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.theme

AbstractButton {
    id: root

    required property string label
    required property string menuIcon
    property color itemColor: Theme.scheme.onSurface

    signal activated

    implicitHeight: 42
    leftPadding: Metrics.spacingMd
    rightPadding: Metrics.spacingMd
    hoverEnabled: root.enabled
    focusPolicy: Qt.StrongFocus
    opacity: root.enabled ? 1 : 0.38
    Accessible.name: root.label
    onClicked: root.activated()

    background: Rectangle {
        radius: Metrics.radiusSm
        color: root.down || root.hovered
            ? Theme.stateLayer(root.itemColor,
                root.down ? Theme.statePressedOpacity : Theme.stateHoverOpacity)
            : "transparent"
    }

    contentItem: RowLayout {
        spacing: Metrics.spacingMd

        M3Icon {
            name: root.menuIcon
            size: 20
            color: root.itemColor
        }

        M3Text {
            Layout.fillWidth: true
            text: root.label
            color: root.itemColor
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
