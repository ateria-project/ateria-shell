pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

Rectangle {
    id: root

    property string title: ""
    property bool backVisible: false
    property bool saveVisible: false
    property bool saveEnabled: false

    signal backRequested
    signal saveRequested

    implicitHeight: 80
    color: Theme.scheme.surfaceContainer

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Metrics.spacingSm
            rightMargin: Metrics.spacingLg
        }
        spacing: Metrics.spacingSm

        M3Button {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Metrics.spacingSm
            visible: root.backVisible
            style: M3Button.Text
            iconName: "arrow_back"
            iconSize: 22
            implicitWidth: 40
            implicitHeight: 40
            contentColor: Theme.scheme.onSurface
            Accessible.name: qsTr("Go back")
            onClicked: root.backRequested()
        }

        M3Text {
            Layout.fillWidth: true
            Layout.leftMargin: root.backVisible ? 0 : Metrics.spacingMd
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Metrics.spacingLg
            text: root.title
            color: Theme.scheme.onSurface
            font.pixelSize: 18
            font.weight: Font.Medium
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        M3Button {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Metrics.spacingSm
            visible: root.saveVisible
            text: qsTr("Save")
            style: M3Button.Tonal
            implicitHeight: 40
            enabled: root.saveEnabled
            onClicked: root.saveRequested()
        }
    }
}
