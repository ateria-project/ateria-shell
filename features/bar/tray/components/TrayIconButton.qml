pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.theme

Item {
    id: root

    required property var item

    readonly property bool needsAttention: root.item.status === Status.NeedsAttention
    readonly property string accessibleName: {
        const tooltipTitle = String(root.item.tooltipTitle || "").trim();
        if (tooltipTitle.length > 0)
            return tooltipTitle;

        const title = String(root.item.title || "").trim();
        if (title.length > 0)
            return title;

        return String(root.item.id || qsTr("System tray item"));
    }

    signal menuRequested(var trayItem)

    function openMenu(): void {
        if (!root.item.hasMenu)
            return;

        root.menuRequested(root.item);
    }

    function activatePrimary(): void {
        if (root.item.hasMenu)
            root.openMenu();
        else
            root.item.activate();
    }

    function handleClick(button: int): void {
        switch (button) {
        case Qt.RightButton:
            root.openMenu();
            break;
        case Qt.MiddleButton:
            root.item.secondaryActivate();
            break;
        default:
            root.activatePrimary();
            break;
        }
    }

    implicitWidth: 26
    implicitHeight: 28
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.onPressAction: root.activatePrimary()

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSm
        color: root.needsAttention ? Theme.scheme.errorContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.needsAttention ? Theme.scheme.onErrorContainer : Theme.scheme.onSurface
            opacity: pointerArea.pressed ? Theme.statePressedOpacity : pointerArea.containsMouse ? Theme.stateHoverOpacity : root.activeFocus ? Theme.stateFocusOpacity : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.durationShort
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }
        }
    }

    IconImage {
        id: trayImage

        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.item.icon
        asynchronous: true
        visible: source.toString().length > 0 && status !== Image.Error
    }

    M3Icon {
        anchors.centerIn: parent
        visible: !trayImage.visible
        name: root.needsAttention ? "error" : "more_horiz"
        size: 18
        color: root.needsAttention ? Theme.scheme.onErrorContainer : Theme.scheme.onSurfaceVariant
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.handleClick(mouse.button)
        onWheel: wheel => {
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            const delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
            if (delta !== 0)
                root.item.scroll(delta, horizontal);
            wheel.accepted = true;
        }
    }

    Keys.onReturnPressed: event => {
        root.activatePrimary();
        event.accepted = true;
    }
    Keys.onEnterPressed: event => {
        root.activatePrimary();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.activatePrimary();
        event.accepted = true;
    }
    Keys.onMenuPressed: event => {
        root.openMenu();
        event.accepted = true;
    }
}
