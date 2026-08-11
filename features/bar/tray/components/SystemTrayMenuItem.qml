pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.theme

Item {
    id: root

    required property var entry

    readonly property bool hasEntry: root.entry !== null && root.entry !== undefined
    readonly property bool separator: !root.hasEntry || root.entry.isSeparator
    readonly property bool entryEnabled: root.hasEntry && root.entry.enabled
    readonly property bool hasChildren: root.hasEntry && root.entry.hasChildren
    readonly property string entryText: root.hasEntry ? String(root.entry.text || "") : ""
    readonly property string iconSource: root.hasEntry ? String(root.entry.icon || "") : ""
    readonly property bool checked: root.hasEntry && root.entry.checkState === Qt.Checked
    readonly property bool partiallyChecked: root.hasEntry && root.entry.checkState === Qt.PartiallyChecked
    readonly property bool checkBox: root.hasEntry && root.entry.buttonType === QsMenuButtonType.CheckBox
    readonly property bool radioButton: root.hasEntry && root.entry.buttonType === QsMenuButtonType.RadioButton
    readonly property bool hasButtonIndicator: root.checkBox || root.radioButton
    readonly property bool hasIcon: root.iconSource.length > 0
    readonly property color contentColor: root.entryEnabled ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant

    signal activated

    implicitWidth: 200
    implicitHeight: root.separator ? 7 : 32

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 1
        visible: root.separator
        color: Theme.scheme.outlineVariant
        opacity: 0.6
    }

    AbstractButton {
        id: button

        anchors.fill: parent
        visible: !root.separator
        enabled: root.entryEnabled
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        leftPadding: 10
        rightPadding: 10
        onClicked: root.activated()

        Accessible.name: root.entryText || qsTr("Menu item")

        background: Rectangle {
            radius: 6
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.scheme.onSurface
                opacity: button.down
                    ? Theme.statePressedOpacity
                    : button.hovered
                        ? Theme.stateHoverOpacity
                        : button.visualFocus
                            ? Theme.stateFocusOpacity
                            : 0

                Behavior on opacity {
                    OpacityAnimator {
                        duration: Motion.durationShort
                        easing.type: Motion.easingStandard
                        easing.bezierCurve: Motion.standardCurve
                    }
                }
            }
        }

        contentItem: RowLayout {
            spacing: 10

            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                IconImage {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: root.hasIcon && !root.hasButtonIndicator ? root.iconSource : ""
                    asynchronous: true
                    visible: source.toString().length > 0 && status !== Image.Error
                }

                M3Icon {
                    anchors.centerIn: parent
                    visible: root.hasButtonIndicator
                    name: {
                        if (root.radioButton)
                            return root.checked ? "radio_button_checked" : "radio_button_unchecked";
                        if (root.partiallyChecked)
                            return "indeterminate_check_box";
                        return root.checked ? "check_box" : "check_box_outline_blank";
                    }
                    size: 16
                    filled: root.checked
                    color: root.entryEnabled ? Theme.scheme.primary : Theme.scheme.onSurfaceVariant
                    opacity: root.entryEnabled ? 1 : Theme.disabledContentOpacity
                }
            }

            M3Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.entryText
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.contentColor
                opacity: root.entryEnabled ? 1 : Theme.disabledContentOpacity
                font.pixelSize: 14
                font.weight: Font.Normal
            }

            M3Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasChildren
                name: "chevron_right"
                size: 16
                color: root.contentColor
                opacity: root.entryEnabled ? 1 : Theme.disabledContentOpacity
            }
        }

        HoverHandler {
            cursorShape: root.entryEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
