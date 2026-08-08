import QtQuick
import QtQuick.Controls.Basic
import qs.components
import qs.shell
import qs.theme

AbstractButton {
    id: root

    property var screen: null

    Accessible.name: qsTr("Toggle wallpaper switcher")
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitWidth: 30
    implicitHeight: 28
    onClicked: SurfaceController.toggleWallpaperSwitcher(root.screen)

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: Metrics.radiusSm
        color: SurfaceController.wallpaperSwitcherOpen ? Theme.scheme.secondaryContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: SurfaceController.wallpaperSwitcherOpen ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            opacity: root.down ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : root.visualFocus ? Theme.stateFocusOpacity : 0
        }

    }

    contentItem: M3Icon {
        name: "wallpaper"
        size: 20
        color: SurfaceController.wallpaperSwitcherOpen ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
        opacity: 0.95
    }

}
