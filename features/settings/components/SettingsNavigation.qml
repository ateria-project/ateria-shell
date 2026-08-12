pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.theme

ColumnLayout {
    id: root

    required property var settingsController

    readonly property int selectedIndex: root.settingsController.filteredCategories.findIndex(category =>
        category.namespaceName === root.settingsController.selectedNamespace)

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
        onTextChanged: root.settingsController.query = text
    }

    ListView {
        id: categoryList

        Layout.fillWidth: true
        Layout.fillHeight: true
        model: root.settingsController.filteredCategories
        currentIndex: root.selectedIndex
        spacing: Metrics.spacingXs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 240

        ExpressiveIndicator {
            parent: categoryList.contentItem
            visible: categoryList.currentItem !== null
            orientation: Qt.Vertical
            targetPosition: categoryList.currentItem?.y ?? 0
            targetExtent: categoryList.currentItem?.height ?? 0
            crossPosition: 0
            crossExtent: categoryList.width
            motionEnabled: categoryList.currentItem !== null
            z: 0

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusMd
                color: Theme.scheme.secondaryContainer
            }
        }

        delegate: SettingsNavigationItem {
            required property var modelData

            width: categoryList.width
            category: modelData
            selected: modelData.namespaceName === root.settingsController.selectedNamespace
            z: 1
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
