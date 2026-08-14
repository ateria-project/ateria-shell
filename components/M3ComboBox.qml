pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.theme

ComboBox {
    id: root

    property color contentColor: Theme.scheme.onSurface
    property color containerColor: Theme.scheme.surfaceContainerHighest
    property color menuColor: Theme.scheme.surfaceContainerHigh
    property color selectedColor: Theme.scheme.secondaryContainer
    property color selectedContentColor: Theme.scheme.onSecondaryContainer
    property bool alwaysShowContainer: false
    property int textAlignment: Text.AlignRight

    implicitWidth: Math.max(120, contentRow.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 40
    leftPadding: Metrics.spacingMd
    rightPadding: 36
    topPadding: 0
    bottomPadding: 0
    spacing: Metrics.spacingSm
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    contentItem: RowLayout {
        id: contentRow

        spacing: Metrics.spacingSm

        M3Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.displayText
            color: root.contentColor
            font.pixelSize: 14
            elide: Text.ElideRight
            horizontalAlignment: root.textAlignment
            textFormat: Text.PlainText
        }
    }

    indicator: M3Icon {
        x: root.width - width - Metrics.spacingSm
        y: (root.height - height) / 2
        name: "expand_more"
        size: 20
        color: Theme.scheme.onSurfaceVariant
        rotation: root.popup.visible ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }
    }

    background: Rectangle {
        radius: Metrics.radiusSm
        color: root.alwaysShowContainer
            || root.hovered || root.activeFocus || root.visualFocus || root.popup.visible
            ? root.containerColor
            : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationShort
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.contentColor
            opacity: root.down
                ? Theme.statePressedOpacity
                : root.hovered
                    ? Theme.stateHoverOpacity
                    : root.visualFocus
                        ? Theme.stateFocusOpacity
                        : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.durationShort
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }
        }
    }

    delegate: ItemDelegate {
        id: optionDelegate

        required property int index

        width: ListView.view ? ListView.view.width : root.popup.width - root.popup.padding * 2
        implicitHeight: 40
        leftPadding: Metrics.spacingMd
        rightPadding: Metrics.spacingMd
        topPadding: 0
        bottomPadding: 0
        highlighted: root.highlightedIndex === optionDelegate.index
        hoverEnabled: true

        background: Rectangle {
            readonly property bool selected: optionDelegate.index === root.currentIndex

            radius: Metrics.radiusSm
            color: selected ? root.selectedColor : "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: parent.selected ? root.selectedContentColor : Theme.scheme.onSurface
                opacity: optionDelegate.down
                    ? Theme.statePressedOpacity
                    : optionDelegate.hovered || optionDelegate.highlighted
                        ? Theme.stateHoverOpacity
                        : 0
            }
        }

        contentItem: RowLayout {
            spacing: Metrics.spacingSm

            M3Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.textAt(optionDelegate.index)
                color: optionDelegate.index === root.currentIndex ? root.selectedContentColor : Theme.scheme.onSurface
                font.pixelSize: 14
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            M3Icon {
                Layout.alignment: Qt.AlignVCenter
                visible: optionDelegate.index === root.currentIndex
                name: "check"
                size: 20
                color: root.selectedContentColor
            }
        }
    }

    popup: Popup {
        id: popup

        parent: root
        x: 0
        y: root.height + Metrics.spacingXs
        width: root.width
        height: Math.min(contentList.contentHeight + padding * 2, 300)
        padding: Metrics.spacingXs
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ListView {
            id: contentList

            implicitHeight: contentHeight
            clip: true
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            spacing: Metrics.spacingXs
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Motion.durationShort

            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: Metrics.radiusSm
            color: root.menuColor
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
