pragma Singleton

import QtQuick
import qs.platform.settings
import "LauncherSearch.js" as LauncherSearch

QtObject {
    id: root

    readonly property int maximumHistoryEntries: 200
    readonly property var schema: ({
            "launcher.usageHistory": {
                type: "string",
                defaultValue: "{}",
                label: qsTr("Application usage history"),
                description: qsTr("Ranks frequently and recently launched applications higher in launcher search."),
                group: "search",
                order: 10
            }
        })
    readonly property string usageHistoryJson: SettingsService.ready ? SettingsService.value("launcher.usageHistory") || "{}" : "{}"
    readonly property var usageHistory: root.parseUsageHistory(root.usageHistoryJson)

    function hasOwn(object, key): bool {
        return object !== null && object !== undefined && Object.prototype.hasOwnProperty.call(object, key);
    }

    function parseUsageHistory(serialized): var {
        try {
            const parsed = JSON.parse(String(serialized || "{}"));
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
                return {};

            const sanitized = {};
            const keys = Object.keys(parsed);
            for (let index = 0; index < keys.length; ++index) {
                const key = keys[index];
                const record = parsed[key];
                if (!record || typeof record !== "object")
                    continue;

                const count = Math.max(0, Math.round(Number(record.count)));
                const lastLaunched = Math.max(0, Math.round(Number(record.lastLaunched)));
                if (!Number.isFinite(count) || count === 0 || !Number.isFinite(lastLaunched))
                    continue;

                sanitized[key] = {
                    "count": count,
                    "lastLaunched": lastLaunched
                };
            }

            return sanitized;
        } catch (error) {
            console.warn("LauncherSettings: failed to parse application usage history: " + error);
            return {};
        }
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

        return SettingsService.setValue("launcher.usageHistory", JSON.stringify(root.prunedHistory(history)));
    }
}
