import QtQuick
import qs.components
import qs.platform.notifications
import qs.theme

M3Text {
    id: root

    required property var action

    readonly property bool hasAction: root.action !== null && root.action !== undefined
    readonly property bool pressed: actionTapHandler.pressed

    text: root.hasAction ? String(root.action.text || qsTr("Open")) : ""
    visible: root.hasAction
    color: Theme.scheme.primary
    opacity: root.pressed ? 0.7 : 1
    font.pixelSize: 14
    font.weight: Font.Medium
    font.underline: actionHoverHandler.hovered || root.activeFocus
    activeFocusOnTab: root.hasAction

    Accessible.role: Accessible.Link
    Accessible.name: root.text
    Accessible.onPressAction: root.activate()

    function activate() {
        if (root.hasAction)
            NotificationService.invokeAction(root.action);
    }

    HoverHandler {
        id: actionHoverHandler

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: actionTapHandler

        acceptedButtons: Qt.LeftButton
        onTapped: root.activate()
    }

    Keys.onReturnPressed: event => {
        root.activate();
        event.accepted = true;
    }
    Keys.onEnterPressed: event => {
        root.activate();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.activate();
        event.accepted = true;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.durationShort
            easing.type: Motion.easingStandard
            easing.bezierCurve: Motion.standardCurve
        }
    }
}
