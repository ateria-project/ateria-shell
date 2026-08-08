pragma ComponentBehavior: Bound

import QtQuick

// One passive background hit target for a full-window overlay. Place this
// before the excluded surface so interactive content remains above it.
MouseArea {
    id: root

    required property Item excludedItem

    signal dismissed

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton

    onClicked: mouse => {
        const point = root.excludedItem.mapFromItem(root, mouse.x, mouse.y);
        const outside = point.x < 0
            || point.y < 0
            || point.x >= root.excludedItem.width
            || point.y >= root.excludedItem.height;
        if (outside)
            root.dismissed();
    }
}
