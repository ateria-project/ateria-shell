pragma Singleton

import QtQuick
import Ateria.Search
import qs.platform.settings

QtObject {
    id: root

    readonly property int maximumHistoryEntries: 200
    readonly property var schema: ({
            "usageHistory": {
                type: "map",
                values: {
                    type: "object",
                    properties: {
                        count: { type: "int", minimum: 1 },
                        lastLaunched: { type: "real", minimum: 0 }
                    },
                    required: ["count", "lastLaunched"]
                },
                defaultValue: ({}),
                label: qsTr("Application usage history"),
                description: qsTr("Ranks frequently and recently launched applications higher in launcher search."),
                group: "search",
                order: 10
            }
        })
    readonly property var usageHistory: SettingsService.ready ? SettingsService.value("launcher", "usageHistory") : ({})

    function hasOwn(object, key): bool {
        return object !== null && object !== undefined && Object.prototype.hasOwnProperty.call(object, key);
    }

    function applicationKey(desktopEntry): string {
        return LauncherSearch.applicationKey(desktopEntry);
    }

    function prunedHistory(history): var {
        const keys = Object.keys(history);
        keys.sort((left, right) => {
            const leftRecord = history[left];
            const rightRecord = history[right];
            if (leftRecord.lastLaunched !== rightRecord.lastLaunched)
                return rightRecord.lastLaunched - leftRecord.lastLaunched;
            return rightRecord.count - leftRecord.count;
        });

        const pruned = {};
        const retainedKeys = keys.slice(0, root.maximumHistoryEntries);
        for (let index = 0; index < retainedKeys.length; ++index) {
            const key = retainedKeys[index];
            pruned[key] = history[key];
        }

        return pruned;
    }

    function recordLaunch(desktopEntry): bool {
        if (!desktopEntry || !SettingsService.ready)
            return false;

        const key = root.applicationKey(desktopEntry);
        const history = Object.assign({}, root.usageHistory);
        const previous = root.hasOwn(history, key) ? history[key] : null;
        history[key] = {
            "count": previous ? Math.min(1000000, previous.count + 1) : 1,
            "lastLaunched": Date.now()
        };

        return SettingsService.setValue("launcher", "usageHistory", root.prunedHistory(history));
    }
}
