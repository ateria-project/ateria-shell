import QtQuick
import qs.components
import qs.theme

Item {
    id: root

    property string text: ""

    implicitWidth: 100
    implicitHeight: 40

    M3Text {
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 16
    }
}
