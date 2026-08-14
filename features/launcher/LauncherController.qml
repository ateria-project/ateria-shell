import QtQuick
import Quickshell
import Ateria.Search

QtObject {
    id: root

    property string query: ""
    property int currentIndex: -1
    property int desktopEntriesRevision: 0
    property double rankingTime: Date.now()

    readonly property var applications: {
        root.desktopEntriesRevision;

        return DesktopEntries.applications.values.filter(entry => {
            return entry && !entry.noDisplay && String(entry.name || "").trim().length > 0;
        });
    }
    readonly property alias results: applicationSearchModel.results

    readonly property var currentApplication: root.currentIndex >= 0 && root.currentIndex < root.results.length ? root.results[root.currentIndex] : null

    onResultsChanged: root.currentIndex = root.results.length > 0 ? 0 : -1

    property Connections desktopEntriesConnection: Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntriesRevision += 1;
        }
    }

    property LauncherSearchModel searchModel: LauncherSearchModel {
        id: applicationSearchModel

        applications: root.applications
        query: root.query
        usageHistory: LauncherSettings.usageHistory
        rankingTime: root.rankingTime
    }

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

    function refreshUsageRanking() {
        root.rankingTime = Date.now();
    }
}
