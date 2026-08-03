pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import qs.theme

TextField {
    id: root

    property string leadingIconName: ""
    property bool clearButtonEnabled: false
    property color containerColor: Theme.scheme.surfaceContainerHighest
    property color contentColor: Theme.scheme.onSurface
    property color placeholderColor: Theme.scheme.onSurfaceVariant

    readonly property bool hasLeadingIcon: root.leadingIconName.length > 0
    readonly property bool showClearButton: root.clearButtonEnabled && root.text.length > 0

    implicitHeight: 46
    leftPadding: root.hasLeadingIcon ? 56 : Metrics.spacingLg
    rightPadding: root.clearButtonEnabled ? 56 : Metrics.spacingLg
    topPadding: 0
    bottomPadding: 0

    color: root.contentColor
    placeholderTextColor: root.placeholderColor
    selectionColor: Theme.scheme.primary
    selectedTextColor: Theme.scheme.onPrimary
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    font.family: Typography.family
    font.pixelSize: 16

    background: Rectangle {
        radius: Metrics.radiusFull
        color: root.containerColor
    }

    M3Icon {
        anchors {
            left: parent.left
            leftMargin: Metrics.spacingLg
            verticalCenter: parent.verticalCenter
        }
        z: 1

        visible: root.hasLeadingIcon
        name: root.leadingIconName
        size: 24
        color: root.contentColor
    }

    M3Button {
        anchors {
            right: parent.right
            rightMargin: Metrics.spacingSm
            verticalCenter: parent.verticalCenter
        }
        z: 1

        visible: root.showClearButton
        style: M3Button.Text
        iconName: "close"
        iconSize: 20
        implicitWidth: 40
        implicitHeight: 40
        containerColor: "transparent"
        contentColor: Theme.scheme.onSurfaceVariant
        Accessible.name: qsTr("Clear search")
        onClicked: {
            root.clear();
            root.forceActiveFocus();
        }
    }
}
