pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.platform.settings
import qs.theme

Rectangle {
    id: root

    required property string namespaceName
    required property string settingName
    required property var definition
    property bool firstInGroup: true
    property bool lastInGroup: true
    property string stringDraft: String(root.currentValue ?? "")

    signal editListRequested(string settingName, var definition)

    readonly property var currentValue: {
        const revision = SettingsService.revision;
        return SettingsService.value(root.namespaceName, root.settingName);
    }

    function setValue(value): bool {
        return SettingsService.setValue(root.namespaceName, root.settingName, value);
    }

    function commitStringEdit(): void {
        if (!root.setValue(root.stringDraft))
            root.stringDraft = String(root.currentValue ?? "");
    }

    implicitHeight: Math.max(64, content.implicitHeight + Metrics.spacingLg * 2)
    radius: Metrics.spacingXs
    topLeftRadius: root.firstInGroup ? Metrics.radiusLg : Metrics.spacingXs
    topRightRadius: root.firstInGroup ? Metrics.radiusLg : Metrics.spacingXs
    bottomLeftRadius: root.lastInGroup ? Metrics.radiusLg : Metrics.spacingXs
    bottomRightRadius: root.lastInGroup ? Metrics.radiusLg : Metrics.spacingXs
    color: Theme.scheme.surfaceContainer

    ColumnLayout {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: Metrics.spacingLg
            rightMargin: Metrics.spacingLg
            topMargin: Metrics.spacingLg
        }
        spacing: Metrics.spacingSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingMd

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                M3Text {
                    Layout.fillWidth: true
                    text: String(root.definition.label ?? root.settingName)
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    color: Theme.scheme.onSurface
                    textFormat: Text.PlainText
                }

                M3Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: String(root.definition.description ?? "")
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    color: Theme.scheme.onSurfaceVariant
                    opacity: 0.72
                    textFormat: Text.PlainText
                }

                M3OutlinedTextField {
                    id: stringInput

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.definition.type === "string" ? 40 : 0
                    Layout.topMargin: root.definition.type === "string" ? Metrics.spacingSm : 0
                    visible: root.definition.type === "string"

                    text: root.stringDraft
                    Accessible.name: String(root.definition.label ?? root.settingName)
                    onTextEdited: root.stringDraft = text
                    onEditingFinished: root.commitStringEdit()

                    Keys.onReturnPressed: event => {
                        root.commitStringEdit();
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: event => {
                        root.commitStringEdit();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: event => {
                        root.stringDraft = String(root.currentValue ?? "");
                        stringInput.focus = false;
                        event.accepted = true;
                    }
                }
            }

            M3Switch {
                visible: root.definition.type === "bool"
                checked: Boolean(root.currentValue)
                Accessible.name: String(root.definition.label ?? root.settingName)
                onToggled: {
                    if (checked !== Boolean(root.currentValue))
                        root.setValue(checked);
                }
            }

            AbstractButton {
                id: listSummary

                visible: root.definition.type === "list"
                implicitWidth: summaryContent.implicitWidth + Metrics.spacingMd * 2
                implicitHeight: 40
                leftPadding: Metrics.spacingMd
                rightPadding: Metrics.spacingMd
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Edit %1").arg(String(root.definition.label ?? root.settingName))
                onClicked: root.editListRequested(root.settingName, root.definition)

                background: Rectangle {
                    radius: Metrics.radiusSm
                    color: listSummary.hovered || listSummary.visualFocus
                        ? Theme.scheme.surfaceContainerHighest
                        : "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onSurface
                        opacity: listSummary.down ? Theme.statePressedOpacity : 0
                    }

                    Behavior on color {
                        ColorAnimation { duration: Motion.durationShort }
                    }
                }

                contentItem: RowLayout {
                    id: summaryContent

                    spacing: Metrics.spacingXs

                    M3Text {
                        text: qsTr("%1 entries").arg(Array.isArray(root.currentValue) ? root.currentValue.length : 0)
                        color: Theme.scheme.onSurfaceVariant
                        font.pixelSize: 14
                    }

                    M3Icon {
                        name: "chevron_right"
                        size: 20
                        color: Theme.scheme.onSurfaceVariant
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Loader {
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.maximumWidth: Math.max(160, content.width * 0.48)
                visible: ["enum", "int", "real", "map", "object"].indexOf(root.definition.type) !== -1
                sourceComponent: {
                    switch (root.definition.type) {
                    case "enum": return enumEditor;
                    case "int": return integerEditor;
                    case "real": return realEditor;
                    case "map":
                    case "object": return dataEditor;
                    default: return null;
                    }
                }
            }
        }
    }

    onCurrentValueChanged: {
        if (!stringInput.activeFocus)
            root.stringDraft = String(root.currentValue ?? "");
    }

    Component {
        id: enumEditor

        M3ComboBox {
            readonly property var options: root.definition.options ?? []

            implicitWidth: 180
            model: options
            textRole: "label"
            valueRole: "id"
            currentIndex: options.findIndex(option => option.id === root.currentValue)
            onActivated: index => {
                if (index >= 0 && index < options.length)
                    root.setValue(options[index].id);
            }
        }
    }

    Component {
        id: integerEditor

        M3NumberField {
            value: Number(root.currentValue ?? root.definition.defaultValue ?? 0)
            from: Number.isFinite(root.definition.minimum) ? root.definition.minimum : -Number.MAX_VALUE
            to: Number.isFinite(root.definition.maximum) ? root.definition.maximum : Number.MAX_VALUE
            stepSize: Number.isFinite(root.definition.stepSize) ? root.definition.stepSize : 1
            decimals: 0
            accessibleName: String(root.definition.label ?? root.settingName)
            onValueModified: value => root.setValue(value)
        }
    }

    Component {
        id: realEditor

        M3NumberField {
            value: Number(root.currentValue ?? root.definition.defaultValue ?? 0)
            from: Number.isFinite(root.definition.minimum) ? root.definition.minimum : -Number.MAX_VALUE
            to: Number.isFinite(root.definition.maximum) ? root.definition.maximum : Number.MAX_VALUE
            stepSize: Number.isFinite(root.definition.stepSize) ? root.definition.stepSize : 0.1
            decimals: Number.isFinite(root.definition.decimals) ? root.definition.decimals : 2
            accessibleName: String(root.definition.label ?? root.settingName)
            onValueModified: value => root.setValue(value)
        }
    }

    Component {
        id: dataEditor

        M3Button {
            text: qsTr("Clear data")
            style: M3Button.Tonal
            enabled: root.currentValue && Object.keys(root.currentValue).length > 0
            onClicked: SettingsService.reset(root.namespaceName, root.settingName)
        }
    }
}
