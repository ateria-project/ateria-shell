pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Stable layout geometry with a separate visual presentation layer.
// Layouts size this item; motion belongs on presentationItem.
Item {
    id: root

    default property alias contentData: content.data
    readonly property alias contentItem: content
    readonly property alias presentationItem: presentation

    property alias radius: background.radius
    property alias color: background.color
    property bool contentClipped: false

    clip: root.contentClipped

    PresentationLayer {
        id: presentation

        anchors.fill: parent

        M3Panel {
            id: background

            anchors.fill: parent
            radius: Metrics.radiusLg
            color: Theme.scheme.surfaceContainer
        }

        Item {
            id: content

            anchors.fill: parent
        }
    }
}
