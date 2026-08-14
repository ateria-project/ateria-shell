import QtQuick
import QtQuick.Controls
import qs.components
import qs.features.quicksettings.components
import qs.platform.display
import qs.theme

M3Panel {
    id: root

    property var controller: null

    // This page is loaded lazily, so opening it is a useful and infrequent
    // point at which to synchronize both backends with the hardware.
    Component.onCompleted: BrightnessService.refresh()

    implicitHeight: Math.min(450, header.implicitHeight + Metrics.spacingXs + monitorColumn.implicitHeight + 16)

    component BrightnessMonitorRow: Rectangle {
        id: rowRoot

        required property var monitor

        signal valueRequested(string displayId, real value)

        implicitHeight: 92
        radius: 14
        color: Theme.scheme.surfaceContainerHighest

        Item {
            id: rowHeader

            height: 34

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Metrics.listItemInset
                rightMargin: Metrics.listItemInset
                topMargin: Metrics.spacingSm
            }

            M3Icon {
                id: displayIcon

                name: rowRoot.monitor.type === "internal" ? "laptop_chromebook" : "desktop_windows"
                size: Metrics.listLeadingIconSize
                width: Metrics.listLeadingIconSize
                color: rowRoot.monitor.available ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors {
                    left: displayIcon.right
                    leftMargin: Metrics.listItemContentGap
                    right: valueLabel.left
                    rightMargin: Metrics.listItemInset
                    verticalCenter: parent.verticalCenter
                }

                M3Text {
                    width: parent.width
                    text: rowRoot.monitor.name || "Display"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                M3Text {
                    width: parent.width
                    text: {
                        const subtext = rowRoot.monitor.type === "internal" ? "Built-in display" : "External";
                        return subtext;
                    }
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            M3Text {
                id: valueLabel

                text: rowRoot.monitor.available ? Math.round(rowRoot.monitor.brightness * 100) + "%" : "Unavailable"
                color: rowRoot.monitor.available ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
                font.weight: Font.Medium

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
            }
        }

        M3Slider {
            enabled: rowRoot.monitor.available
            iconName: "brightness_7"
            iconSize: 20

            value: rowRoot.monitor.brightness
            from: 0
            to: 1

            live: true

            onValueChangeRequested: requestedValue => {
                rowRoot.valueRequested(rowRoot.monitor.id, requestedValue);
            }

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: Metrics.spacingMd
                rightMargin: Metrics.spacingMd
                bottomMargin: Metrics.spacingSm
            }
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Brightness"
        onBackRequested: {
            if (root.controller)
                root.controller.popPage();
        }
    }

    Flickable {
        id: monitorList

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
            leftMargin: Metrics.listOuterInset
            rightMargin: Metrics.listOuterInset
            topMargin: Metrics.spacingXs
            bottomMargin: Metrics.spacingSm
        }
        contentWidth: width
        contentHeight: monitorColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: monitorColumn

            width: monitorList.width - ((monitorList.contentHeight > monitorList.height) ? Metrics.spacingMd : 0)
            spacing: 2

            M3Text {
                width: parent.width
                leftPadding: Metrics.listSectionHeaderInset
                height: 32
                text: "Displays"
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: BrightnessService.displays

                delegate: BrightnessMonitorRow {
                    required property var modelData

                    width: monitorColumn.width
                    monitor: modelData

                    onValueRequested: (displayId, value) => BrightnessService.setBrightness(displayId, value)
                }
            }

            M3Text {
                visible: BrightnessService.displays.length === 0
                width: parent.width
                height: 42
                text: "No displays"
                color: Theme.scheme.onSurfaceVariant
                verticalAlignment: Text.AlignVCenter
            }
        }

        ScrollBar.vertical: M3ScrollBar {
            policy: monitorList.contentHeight > monitorList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }
    }

    Rectangle {
        id: outerKeyline

        anchors.fill: parent
        z: 1000

        color: "transparent"
        radius: root.radius
        antialiasing: true

        property color strokeColor: Theme.panelOuterKeyline

        border.width: Theme.panelBorderWidth
        border.color: strokeColor

        Behavior on strokeColor {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: innerHighlight

        anchors.fill: parent
        anchors.margins: Theme.panelInnerBorderInset
        z: 1001

        color: "transparent"
        radius: Math.max(0, root.radius - Theme.panelInnerBorderInset)
        antialiasing: true

        property color strokeColor: Theme.panelInnerHighlight

        border.width: Theme.panelBorderWidth
        border.color: strokeColor

        Behavior on strokeColor {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
