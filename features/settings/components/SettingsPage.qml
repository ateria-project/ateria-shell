pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.theme

Item {
    id: root

    required property var settingsController
    required property string namespaceName
    required property string title
    required property string description

    readonly property var groups: root.settingsController.groups(root.namespaceName)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Page header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: headerContent.implicitHeight + Metrics.spacingXl * 2

            ColumnLayout {
                id: headerContent

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Metrics.spacingXl
                    rightMargin: Metrics.spacingXl
                    topMargin: Metrics.spacingXl
                }
                spacing: Metrics.spacingXs

                M3Text {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    color: Theme.scheme.onSurface
                    textFormat: Text.PlainText
                }

                M3Text {
                    Layout.fillWidth: true
                    text: root.description
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    color: Theme.scheme.onSurfaceVariant
                    textFormat: Text.PlainText
                }
            }
        }

        // Header divider
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Metrics.spacingXl
            Layout.rightMargin: Metrics.spacingXl
            height: 1
            color: Theme.scheme.outlineVariant
            opacity: 0.5
        }

        // Settings groups list
        ListView {
            id: settingsList

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.groups
            spacing: Metrics.spacingLg
            leftMargin: Metrics.spacingXl
            rightMargin: Metrics.spacingXl
            topMargin: Metrics.spacingLg
            bottomMargin: Metrics.spacingXl
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
