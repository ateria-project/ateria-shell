import QtQuick
import qs.components
import qs.theme

Item {
    id: root

    required property string title
    property alias trailingItem: trailingSlot.data

    signal backRequested

    implicitHeight: 52

    M3Button {
        id: backButton

        anchors {
            left: parent.left
            leftMargin: 16
            verticalCenter: parent.verticalCenter
        }
        width: 36
        height: 36
        iconName: "chevron_backward"
        style: M3Button.Text
        contentColor: Theme.scheme.onSurface
        onClicked: root.backRequested()
    }

    M3Text {
        anchors {
            left: backButton.right
            leftMargin: Metrics.spacingMd
            right: trailingSlot.left
            rightMargin: Metrics.spacingSm
            verticalCenter: parent.verticalCenter
        }
        text: root.title
        font.pixelSize: 16
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    Item {
        id: trailingSlot

        anchors {
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: Theme.scheme.outlineVariant
        opacity: 0.55
    }
}
