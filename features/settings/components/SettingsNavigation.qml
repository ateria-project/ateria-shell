pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.theme

ColumnLayout {
    id: root

    required property var settingsController

    spacing: Metrics.spacingMd

    function focusSearch() {
        searchField.forceActiveFocus();
    }

    M3TextField {
        id: searchField

        Layout.fillWidth: true
        placeholderText: qsTr("Search settings")
        leadingIconName: "search"
        clearButtonEnabled: true
        text: root.settingsController.query
        Accessible.name: qsTr("Search settings")
        onTextEdited: root.settingsController.query = text
    }

    ListView {
        id: categoryList

        Layout.fillWidth: true
        Layout.fillHeight: true
        model: root.settingsController.filteredCategories
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 240

        delegate: SettingsNavigationItem {
            required property var modelData

            width: categoryList.width
            category: modelData
            selected: modelData.namespaceName === root.settingsController.selectedNamespace
            onActivated: root.settingsController.selectNamespace(modelData.namespaceName)
        }

        ScrollBar.vertical: M3ScrollBar {
            policy: categoryList.contentHeight > categoryList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        M3Text {
            anchors.centerIn: parent
            visible: categoryList.count === 0
            text: qsTr("No matching settings")
            color: Theme.scheme.onSurfaceVariant
            font.pixelSize: 14
        }
    }
}
