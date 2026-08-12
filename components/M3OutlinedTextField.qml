pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import qs.theme

TextField {
    id: root

    property color containerColor: "transparent"
    property color contentColor: Theme.scheme.onSurface
    property color outlineColor: Theme.scheme.outlineVariant
    property color focusedOutlineColor: Theme.scheme.primary
    property color placeholderColor: Theme.scheme.onSurfaceVariant

    implicitHeight: 40
    leftPadding: Metrics.spacingMd
    rightPadding: Metrics.spacingMd
    topPadding: 0
    bottomPadding: 0

    clip: true
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter
    color: root.contentColor
    placeholderTextColor: root.placeholderColor
    selectionColor: Theme.scheme.primary
    selectedTextColor: Theme.scheme.onPrimary
    font.family: Typography.family
    font.pixelSize: 14

    background: Rectangle {
        radius: Metrics.radiusSm
        color: root.containerColor
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.focusedOutlineColor : root.outlineColor

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.durationShort
            }
        }
    }

    onTextChanged: {
        if (!root.activeFocus)
            root.cursorPosition = 0;
    }

    onActiveFocusChanged: {
        if (!root.activeFocus)
            root.cursorPosition = 0;
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.IBeamCursor : Qt.ArrowCursor
    }
}
