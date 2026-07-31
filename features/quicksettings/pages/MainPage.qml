import QtQuick
import qs.components
import qs.features.quicksettings.components
import qs.features.quicksettings.tiles
import qs.theme

Rectangle {
    id: root

    property var controller: null

    color: Theme.scheme.surfaceContainer
    radius: Metrics.radiusLg

    Header {
        id: header

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }

    QuickSettingsTile {
        anchors.centerIn: parent
        text: "Hello World"
    }
}
