import QtQuick
import QtQuick.Controls.Basic
import qs.components
import qs.shell
import qs.theme

AbstractButton {
    id: root

    property var screen: null

    Accessible.name: qsTr("Open application launcher")
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitWidth: 30
    implicitHeight: 28
    onClicked: SurfaceController.toggleLauncher(root.screen)

    background: Rectangle {
        radius: Metrics.radiusSm
        color: SurfaceController.launcherOpen ? Theme.scheme.primaryContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: SurfaceController.launcherOpen ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
            opacity: root.down ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : root.visualFocus ? Theme.stateFocusOpacity : 0
        }
    }

    contentItem: M3Icon {
        name: "apps"
        size: 20
        color: SurfaceController.launcherOpen ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
        opacity: 0.95
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
