pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.platform.settings
import qs.theme

Item {
    id: root

    required property string namespaceName
    required property string settingName
    required property var definition
    property bool showSeparator: false

    readonly property var currentValue: {
        const revision = SettingsService.revision;
        return SettingsService.value(root.namespaceName, root.settingName);
    }

    function setValue(value): bool {
        return SettingsService.setValue(root.namespaceName, root.settingName, value);
    }

    function listText(value): string {
        return Array.isArray(value) ? value.join("\n") : "";
    }

    function parsedList(text: string): var {
        return text.split(/\r?\n|,/).map(value => value.trim()).filter(value => value.length > 0);
    }

    implicitHeight: content.implicitHeight + Metrics.spacingLg * 2

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
            spacing: Metrics.spacingLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                M3Text {
                    Layout.fillWidth: true
                    text: String(root.definition.label ?? root.settingName)
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    color: Theme.scheme.onSurface
                    textFormat: Text.PlainText
                }

                M3Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: String(root.definition.description ?? "")
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    color: Theme.scheme.onSurfaceVariant
                    textFormat: Text.PlainText
                }
            }

            Switch {
                visible: root.definition.type === "bool"
                checked: Boolean(root.currentValue)
                Accessible.name: String(root.definition.label ?? root.settingName)
                onToggled: {
                    if (checked !== Boolean(root.currentValue))
                        root.setValue(checked);
                }
            }

            Loader {
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.maximumWidth: Math.max(160, content.width * 0.48)
                visible: ["enum", "int", "real", "string", "map", "object"].indexOf(root.definition.type) !== -1
                sourceComponent: {
                    switch (root.definition.type) {
                    case "enum": return enumEditor;
                    case "int": return integerEditor;
                    case "real": return realEditor;
                    case "string": return stringEditor;
                    case "map":
                    case "object": return dataEditor;
                    default: return null;
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            visible: root.definition.type === "list"
            sourceComponent: listEditor
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Metrics.spacingLg
            rightMargin: Metrics.spacingLg
        }
        visible: root.showSeparator
        height: 1
        color: Theme.scheme.outlineVariant
        opacity: 0.5
    }

    Component {
        id: enumEditor

        ComboBox {
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

        SpinBox {
            implicitWidth: 130
            editable: true
            from: Number.isFinite(root.definition.minimum) ? root.definition.minimum : -999999
            to: Number.isFinite(root.definition.maximum) ? root.definition.maximum : 999999
            value: Number(root.currentValue ?? root.definition.defaultValue ?? 0)
            onValueModified: root.setValue(value)
        }
    }

    Component {
        id: realEditor

        TextField {
            implicitWidth: 130
            text: String(root.currentValue ?? root.definition.defaultValue ?? 0)
            horizontalAlignment: TextInput.AlignRight
            selectByMouse: true
            validator: DoubleValidator {
                bottom: Number.isFinite(root.definition.minimum) ? root.definition.minimum : -Infinity
                top: Number.isFinite(root.definition.maximum) ? root.definition.maximum : Infinity
            }
            onEditingFinished: {
                const candidate = Number.parseFloat(text);
                if (!Number.isFinite(candidate) || !root.setValue(candidate))
                    text = String(root.currentValue);
            }
        }
    }

    Component {
        id: stringEditor

        TextField {
            implicitWidth: 210
            text: String(root.currentValue ?? "")
            selectByMouse: true
            Accessible.name: String(root.definition.label ?? root.settingName)
            onEditingFinished: root.setValue(text)
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

    Component {
        id: listEditor

        ColumnLayout {
            spacing: Metrics.spacingSm

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 110

                TextArea {
                    id: listTextArea

                    text: root.listText(root.currentValue)
                    placeholderText: qsTr("One value per line")
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                M3Text {
                    Layout.fillWidth: true
                    text: qsTr("%1 entries").arg(Array.isArray(root.currentValue) ? root.currentValue.length : 0)
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 12
                }

                M3Button {
                    text: qsTr("Apply")
                    style: M3Button.Tonal
                    enabled: listTextArea.text !== root.listText(root.currentValue)
                    onClicked: root.setValue(root.parsedList(listTextArea.text))
                }
            }

            Connections {
                target: SettingsService

                function onRevisionChanged() {
                    if (!listTextArea.activeFocus)
                        listTextArea.text = root.listText(root.currentValue);
                }
            }
        }
    }
}
