pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.components
import qs.theme

Item {
    id: root

    required property var settingsController
    required property string namespaceName

    readonly property var groups: root.settingsController.groups(root.namespaceName)
    readonly property var category: root.settingsController.category(root.namespaceName)
    readonly property bool listEditorOpen: contentStack.depth > 1

    function openListEditor(settingName: string, definition): void {
        if (root.listEditorOpen)
            contentStack.pop(StackView.Immediate);
        contentStack.push(listEditorComponent, {
            namespaceName: root.namespaceName,
            settingName,
            definition
        }, StackView.Immediate);
    }

    function closeListEditor(): void {
        if (root.listEditorOpen)
            contentStack.pop(StackView.Immediate);
    }

    StackView {
        id: contentStack

        anchors.fill: parent
        initialItem: overviewComponent
    }

    Component {
        id: overviewComponent

        Item {
            SettingsPageHeader {
                id: pageHeader

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                title: String(root.category.title ?? root.namespaceName)
            }

            ListView {
                id: settingsList

                anchors {
                    left: parent.left
                    right: parent.right
                    top: pageHeader.bottom
                    bottom: parent.bottom
                }
                model: root.groups
                spacing: Metrics.spacingLg
                leftMargin: Metrics.spacingLg
                rightMargin: Metrics.spacingLg
                topMargin: Metrics.spacingLg
                bottomMargin: Metrics.spacingLg
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 480

                delegate: SettingsGroup {
                    required property var modelData

                    width: settingsList.width - settingsList.leftMargin - settingsList.rightMargin
                    height: implicitHeight
                    namespaceName: root.namespaceName
                    group: modelData
                    onEditListRequested: (settingName, definition) => root.openListEditor(settingName, definition)
                }

                ScrollBar.vertical: M3ScrollBar {
                    policy: settingsList.contentHeight > settingsList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                M3Text {
                    anchors.centerIn: parent
                    visible: settingsList.count === 0
                    text: qsTr("No matching settings")
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 14
                }
            }
        }
    }

    Component {
        id: listEditorComponent

        SettingsListEditor {
            onCloseRequested: root.closeListEditor()
        }
    }
}
