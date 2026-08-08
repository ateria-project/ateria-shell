pragma ComponentBehavior: Bound

import QtQuick

// Visual-only presentation boundary. The parent owns layout geometry; future
// motion may retarget these properties without moving or resizing siblings.
Item {
    id: root

    default property alias contentData: content.data
    readonly property alias contentItem: content

    property real offsetX: 0
    property real offsetY: 0
    property real visualScale: 1
    property real visualOpacity: 1

    opacity: root.visualOpacity
    scale: root.visualScale
    transformOrigin: Item.Center

    transform: Translate {
        x: root.offsetX
        y: root.offsetY
    }

    Item {
        id: content

        anchors.fill: parent
    }
}
