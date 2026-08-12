pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.platform.settings
import qs.theme

Item {
    id: root

    required property string namespaceName
    required property string settingName
    required property var definition

    property string savedSignature: "[]"
    property string draftSignature: "[]"
    property int matchingCount: 0
    property int firstMatchingIndex: -1
    property int lastMatchingIndex: -1
    property string validationMessage: ""

    readonly property bool hasChanges: root.draftSignature !== root.savedSignature
    readonly property string normalizedQuery: searchInput.text.trim().toLocaleLowerCase()
    readonly property int entryHeight: 48
    readonly property int entrySpacing: Metrics.spacingXs

    signal closeRequested

    function refreshMatchingCount(): void {
        let count = 0;
        let firstIndex = -1;
        let lastIndex = -1;
        for (let index = 0; index < draftModel.count; ++index) {
            if (!root.entryMatches(draftModel.get(index).entryValue))
                continue;
            if (firstIndex < 0)
                firstIndex = index;
            lastIndex = index;
            ++count;
        }
        root.matchingCount = count;
        root.firstMatchingIndex = firstIndex;
        root.lastMatchingIndex = lastIndex;
    }

    function refreshDraftState(): void {
        root.draftSignature = JSON.stringify(root.entries());
        root.refreshMatchingCount();
    }

    function entries(): var {
        const values = [];
        for (let index = 0; index < draftModel.count; ++index)
            values.push(draftModel.get(index).entryValue);
        return values;
    }

    function beginEdit(): void {
        const storedValue = SettingsService.value(root.namespaceName, root.settingName);
        const storedEntries = Array.isArray(storedValue) ? storedValue : [];
        draftModel.clear();
        for (const entry of storedEntries)
            draftModel.append({ entryValue: String(entry) });
        searchInput.clear();
        addInput.clear();
        root.validationMessage = "";
        root.savedSignature = JSON.stringify(root.entries());
        root.refreshDraftState();
    }

    function entryMatches(entry: string): bool {
        return root.normalizedQuery.length === 0 || entry.toLocaleLowerCase().includes(root.normalizedQuery);
    }

    function addEntry(): void {
        const candidate = addInput.text.trim();
        if (candidate.length === 0) {
            root.validationMessage = qsTr("Enter a value first.");
            addInput.forceActiveFocus();
            return;
        }

        for (let index = 0; index < draftModel.count; ++index) {
            if (draftModel.get(index).entryValue === candidate) {
                root.validationMessage = qsTr("That entry is already in the list.");
                addInput.selectAll();
                addInput.forceActiveFocus();
                return;
            }
        }

        draftModel.append({ entryValue: candidate });
        addInput.clear();
        searchInput.clear();
        root.validationMessage = "";
        root.refreshDraftState();
        entriesList.positionViewAtEnd();
        addInput.forceActiveFocus();
    }

    function removeEntry(index: int): void {
        if (index < 0 || index >= draftModel.count)
            return;
        draftModel.remove(index, 1);
        root.validationMessage = "";
        root.refreshDraftState();
    }

    function moveEntry(fromIndex: int, toIndex: int): void {
        const boundedIndex = Math.max(0, Math.min(draftModel.count - 1, toIndex));
        if (fromIndex < 0 || fromIndex >= draftModel.count || fromIndex === boundedIndex)
            return;
        draftModel.move(fromIndex, boundedIndex, 1);
        root.refreshDraftState();
    }

    function save(): void {
        if (SettingsService.setValue(root.namespaceName, root.settingName, root.entries())) {
            root.closeRequested();
            return;
        }
        root.validationMessage = qsTr("Could not save this list.");
    }

    ListModel {
        id: draftModel
    }

    SettingsPageHeader {
        id: pageHeader

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        title: String(root.definition.label ?? root.settingName)
        backVisible: true
        saveVisible: true
        saveEnabled: root.hasChanges
        onBackRequested: root.closeRequested()
        onSaveRequested: root.save()
    }

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: pageHeader.bottom
            bottom: parent.bottom
            leftMargin: Metrics.spacingLg
            rightMargin: Metrics.spacingLg
            topMargin: Metrics.spacingLg + Metrics.spacingXs
            bottomMargin: Metrics.spacingLg
        }
        spacing: Metrics.spacingMd

        M3TextField {
            id: searchInput

            Layout.fillWidth: true
            visible: draftModel.count >= 12 || text.length > 0
            leadingIconName: "search"
            clearButtonEnabled: true
            placeholderText: qsTr("Search entries")
            Accessible.name: qsTr("Search entries")
            onTextChanged: root.refreshMatchingCount()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            M3OutlinedTextField {
                id: addInput

                Layout.fillWidth: true
                placeholderText: qsTr("Add an app name or desktop entry ID")
                Accessible.name: qsTr("New list entry")
                onTextEdited: root.validationMessage = ""

                Keys.onReturnPressed: event => {
                    root.addEntry();
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    root.addEntry();
                    event.accepted = true;
                }
            }

            M3Button {
                style: M3Button.Tonal
                iconName: "add"
                iconSize: 22
                implicitWidth: 40
                implicitHeight: 40
                Accessible.name: qsTr("Add entry")
                onClicked: root.addEntry()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20

            M3Text {
                Layout.fillWidth: true
                text: searchInput.text.length > 0
                    ? qsTr("%1 of %2 entries").arg(root.matchingCount).arg(draftModel.count)
                    : qsTr("%1 entries").arg(draftModel.count)
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 13
            }

            M3Text {
                visible: searchInput.text.length === 0 && draftModel.count > 1
                text: qsTr("Drag to reorder")
                color: Theme.scheme.onSurfaceVariant
                opacity: 0.72
                font.pixelSize: 12
            }
        }

        M3Text {
            Layout.fillWidth: true
            visible: root.validationMessage.length > 0
            text: root.validationMessage
            color: Theme.scheme.error
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ListView {
            id: entriesList

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: draftModel
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 480

            delegate: Item {
                id: entryDelegate

                required property int index
                required property string entryValue

                property int dragOriginIndex: -1
                property int dragTargetIndex: -1
                readonly property bool matches: root.entryMatches(entryDelegate.entryValue)
                readonly property bool firstVisible: entryDelegate.index === root.firstMatchingIndex
                readonly property bool lastVisible: entryDelegate.index === root.lastMatchingIndex

                width: entriesList.width
                height: matches ? root.entryHeight + (lastVisible ? 0 : root.entrySpacing) : 0
                visible: height > 0
                clip: true

                Rectangle {
                    id: entrySurface

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: root.entryHeight
                    topLeftRadius: entryDelegate.firstVisible ? Metrics.radiusLg : Metrics.spacingXs
                    topRightRadius: entryDelegate.firstVisible ? Metrics.radiusLg : Metrics.spacingXs
                    bottomLeftRadius: entryDelegate.lastVisible ? Metrics.radiusLg : Metrics.spacingXs
                    bottomRightRadius: entryDelegate.lastVisible ? Metrics.radiusLg : Metrics.spacingXs
                    color: reorderHandler.active
                        ? Theme.scheme.surfaceContainerHighest
                        : Theme.scheme.surfaceContainer

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Metrics.spacingSm
                            rightMargin: Metrics.spacingSm
                        }
                        spacing: Metrics.spacingSm

                        Item {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36

                            M3Icon {
                                anchors.centerIn: parent
                                name: "drag_indicator"
                                size: 20
                                color: Theme.scheme.onSurfaceVariant
                            }

                            DragHandler {
                                id: reorderHandler

                                target: null
                                enabled: searchInput.text.length === 0 && draftModel.count > 1
                                xAxis.enabled: false
                                grabPermissions: PointerHandler.CanTakeOverFromAnything

                                onActiveChanged: {
                                    if (active) {
                                        entryDelegate.dragOriginIndex = entryDelegate.index;
                                        entryDelegate.dragTargetIndex = entryDelegate.index;
                                    } else {
                                        entryDelegate.dragOriginIndex = -1;
                                        entryDelegate.dragTargetIndex = -1;
                                    }
                                }

                                onActiveTranslationChanged: {
                                    if (!active || entryDelegate.dragOriginIndex < 0)
                                        return;
                                    const targetIndex = Math.max(0, Math.min(draftModel.count - 1,
                                        entryDelegate.dragOriginIndex
                                        + Math.round(activeTranslation.y / (root.entryHeight + root.entrySpacing))));
                                    if (targetIndex === entryDelegate.dragTargetIndex)
                                        return;
                                    root.moveEntry(entryDelegate.index, targetIndex);
                                    entryDelegate.dragTargetIndex = targetIndex;
                                }
                            }

                            HoverHandler {
                                enabled: reorderHandler.enabled
                                cursorShape: Qt.SizeVerCursor
                            }
                        }

                        M3Text {
                            Layout.fillWidth: true
                            text: entryDelegate.entryValue
                            color: Theme.scheme.onSurface
                            font.pixelSize: 14
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                        }

                        M3Button {
                            style: M3Button.Text
                            iconName: "delete"
                            iconSize: 20
                            implicitWidth: 36
                            implicitHeight: 36
                            contentColor: Theme.scheme.onSurfaceVariant
                            Accessible.name: qsTr("Remove %1").arg(entryDelegate.entryValue)
                            onClicked: root.removeEntry(entryDelegate.index)
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Motion.durationShort }
                    }
                }
            }

            ScrollBar.vertical: M3ScrollBar {
                policy: entriesList.contentHeight > entriesList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            M3Text {
                anchors.centerIn: parent
                visible: root.matchingCount === 0
                text: searchInput.text.length > 0 ? qsTr("No matching entries") : qsTr("No entries yet")
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 14
            }
        }
    }

    Component.onCompleted: root.beginEdit()
}
