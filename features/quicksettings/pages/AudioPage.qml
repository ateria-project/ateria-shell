import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.features.quicksettings.components
import qs.platform.audio
import qs.theme

Rectangle {
    id: root

    property var controller: null

    implicitHeight: Math.min(450, header.implicitHeight + Metrics.spacingXs + deviceColumn.implicitHeight + Metrics.spacingSm + 8)

    color: Theme.scheme.surfaceContainer
    radius: 16

    component SelectableRow: AbstractButton {
        id: rowRoot

        property string label: ""
        property string iconName: ""
        property bool selected: false

        readonly property color contentColor: rowRoot.selected ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
        readonly property color containerColor: rowRoot.selected ? Theme.scheme.primaryContainer : "transparent"

        implicitHeight: 46
        leftPadding: 16
        rightPadding: 16

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        scale: down ? 0.98 : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: Motion.fastSpatialSpring
                damping: Motion.fastSpatialDamping
                mass: Motion.fastSpatialMass
                epsilon: Motion.fastSpatialEpsilon
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        background: Rectangle {
            radius: 14
            color: rowRoot.containerColor

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: rowRoot.contentColor
                opacity: {
                    if (rowRoot.down)
                        return 0.12;
                    if (rowRoot.hovered)
                        return 0.08;
                    if (rowRoot.visualFocus)
                        return 0.10;
                    return 0;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.durationShort
                        easing.type: Motion.easingStandard
                        easing.bezierCurve: Motion.standardCurve
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationMedium
                }
            }
        }

        contentItem: RowLayout {
            spacing: 12

            M3Icon {
                visible: rowRoot.iconName.length > 0
                name: rowRoot.iconName
                size: 20
                color: rowRoot.contentColor
            }

            M3Text {
                Layout.fillWidth: true
                text: rowRoot.label
                color: rowRoot.contentColor
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            M3Icon {
                visible: rowRoot.selected
                name: "check"
                size: 20
                color: rowRoot.contentColor
            }
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Sound"
        onBackRequested: {
            if (root.controller)
                root.controller.popPage();
        }
    }

    Flickable {
        id: deviceList

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
            leftMargin: 16
            rightMargin: 16
            topMargin: Metrics.spacingXs
            bottomMargin: Metrics.spacingSm
        }
        contentWidth: width
        contentHeight: deviceColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: deviceColumn

            width: deviceList.width - (deviceList.contentHeight > deviceList.height ? Metrics.spacingMd : 0)
            spacing: 2

            M3Text {
                width: parent.width
                height: 32
                text: "Output"
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: AudioService.outputDevices

                delegate: SelectableRow {
                    required property var modelData

                    width: deviceColumn.width
                    label: AudioService.nodeLabel(modelData)
                    iconName: "speaker"
                    selected: AudioService.outputNode === modelData || (AudioService.outputNode && modelData && AudioService.outputNode.id === modelData.id)
                    onClicked: AudioService.setOutputDevice(modelData)
                }
            }

            M3Text {
                visible: AudioService.outputDevices.length === 0
                width: parent.width
                height: 38
                text: "No output devices"
                color: Theme.scheme.onSurfaceVariant
                verticalAlignment: Text.AlignVCenter
            }

            M3Text {
                width: parent.width
                height: 32
                text: "Input"
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: AudioService.inputDevices

                delegate: SelectableRow {
                    required property var modelData

                    width: deviceColumn.width
                    label: AudioService.nodeLabel(modelData)
                    iconName: "mic"
                    selected: AudioService.inputNode === modelData || (AudioService.inputNode && modelData && AudioService.inputNode.id === modelData.id)
                    onClicked: AudioService.setInputDevice(modelData)
                }
            }

            M3Text {
                visible: AudioService.inputDevices.length === 0
                width: parent.width
                height: 38
                text: "No input devices"
                color: Theme.scheme.onSurfaceVariant
                verticalAlignment: Text.AlignVCenter
            }
        }

        ScrollBar.vertical: M3ScrollBar {
            policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }
    }
}
