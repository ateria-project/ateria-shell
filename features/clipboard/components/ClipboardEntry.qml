pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.theme

AbstractButton {
    id: root

    required property var entry
    property bool selected: false

    implicitHeight: 56
    leftPadding: Metrics.spacingMd
    rightPadding: Metrics.spacingMd
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    Accessible.name: root.entry ? root.entry.preview : qsTr("Clipboard entry")

    background: Rectangle {
        radius: Metrics.radiusMd
        color: root.selected ? Theme.scheme.secondaryContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            opacity: root.down ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : 0
        }
    }

    contentItem: RowLayout {
        spacing: Metrics.spacingMd

        M3Icon {
            name: "content_paste"
            size: 22
            color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
        }

        M3Text {
            Layout.fillWidth: true
            text: root.entry ? root.entry.preview : ""
            color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            font.pixelSize: 15
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
