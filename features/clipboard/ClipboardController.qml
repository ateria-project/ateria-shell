import QtQuick
import qs.platform.clipboard
import "ClipboardSearch.js" as ClipboardSearch

QtObject {
    id: root

    property string query: ""
    property int currentIndex: -1

    readonly property var entryIndex: ClipboardSearch.createEntryIndex(ClipboardService.entries)
    readonly property var results: ClipboardSearch.filterEntryIndex(root.entryIndex, root.query)
    readonly property var currentEntry: root.currentIndex >= 0 && root.currentIndex < root.results.length
        ? root.results[root.currentIndex] : null

    onResultsChanged: root.resetSelection()

    function moveSelection(offset: int) {
        const count = root.results.length;
        if (count === 0) {
            root.currentIndex = -1;
            return;
        }

        root.currentIndex = (root.currentIndex + offset + count) % count;
    }

    function resetSelection() {
        root.currentIndex = root.results.length > 0 ? 0 : -1;
    }
}
